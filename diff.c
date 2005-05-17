/*
 * Copyright (C) 2005 Junio C Hamano
 */
#include <sys/types.h>
#include <sys/wait.h>
#include <signal.h>
#include <limits.h>
#include "cache.h"
#include "diff.h"

static const char *diff_opts = "-pu";

static const char *external_diff(void)
{
	static const char *external_diff_cmd = NULL;
	static int done_preparing = 0;

	if (done_preparing)
		return external_diff_cmd;

	/*
	 * Default values above are meant to match the
	 * Linux kernel development style.  Examples of
	 * alternative styles you can specify via environment
	 * variables are:
	 *
	 * GIT_DIFF_OPTS="-c";
	 */
	if (gitenv("GIT_EXTERNAL_DIFF"))
		external_diff_cmd = gitenv("GIT_EXTERNAL_DIFF");

	/* In case external diff fails... */
	diff_opts = gitenv("GIT_DIFF_OPTS") ? : diff_opts;

	done_preparing = 1;
	return external_diff_cmd;
}

/* Help to copy the thing properly quoted for the shell safety.
 * any single quote is replaced with '\'', and the caller is
 * expected to enclose the result within a single quote pair.
 *
 * E.g.
 *  original     sq_expand     result
 *  name     ==> name      ==> 'name'
 *  a b      ==> a b       ==> 'a b'
 *  a'b      ==> a'\''b    ==> 'a'\''b'
 */
static char *sq_expand(const char *src)
{
	static char *buf = NULL;
	int cnt, c;
	const char *cp;
	char *bp;

	/* count bytes needed to store the quoted string. */ 
	for (cnt = 1, cp = src; *cp; cnt++, cp++)
		if (*cp == '\'')
			cnt += 3;

	buf = xmalloc(cnt);
	bp = buf;
	while ((c = *src++)) {
		if (c != '\'')
			*bp++ = c;
		else {
			bp = strcpy(bp, "'\\''");
			bp += 4;
		}
	}
	*bp = 0;
	return buf;
}

static struct diff_tempfile {
	const char *name;
	char hex[41];
	char mode[10];
	char tmp_path[50];
} diff_temp[2];

static void builtin_diff(const char *name,
			 struct diff_tempfile *temp)
{
	int i, next_at;
	const char *diff_cmd = "diff -L'%s%s' -L'%s%s'";
	const char *diff_arg  = "'%s' '%s'||:"; /* "||:" is to return 0 */
	const char *input_name_sq[2];
	const char *path0[2];
	const char *path1[2];
	const char *name_sq = sq_expand(name);
	char *cmd;
	
	/* diff_cmd and diff_arg have 6 %s in total which makes
	 * the sum of these strings 12 bytes larger than required.
	 * we use 2 spaces around diff-opts, and we need to count
	 * terminating NUL, so we subtract 9 here.
	 */
	int cmd_size = (strlen(diff_cmd) + strlen(diff_opts) +
			strlen(diff_arg) - 9);
	for (i = 0; i < 2; i++) {
		input_name_sq[i] = sq_expand(temp[i].name);
		if (!strcmp(temp[i].name, "/dev/null")) {
			path0[i] = "/dev/null";
			path1[i] = "";
		} else {
			path0[i] = i ? "b/" : "a/";
			path1[i] = name_sq;
		}
		cmd_size += (strlen(path0[i]) + strlen(path1[i]) +
			     strlen(input_name_sq[i]));
	}

	cmd = xmalloc(cmd_size);

	next_at = 0;
	next_at += snprintf(cmd+next_at, cmd_size-next_at,
			    diff_cmd,
			    path0[0], path1[0], path0[1], path1[1]);
	next_at += snprintf(cmd+next_at, cmd_size-next_at,
			    " %s ", diff_opts);
	next_at += snprintf(cmd+next_at, cmd_size-next_at,
			    diff_arg, input_name_sq[0], input_name_sq[1]);

	printf("diff -git a/%s b/%s\n", name, name);
	if (!path1[0][0])
		printf("new file mode %s\n", temp[1].mode);
	else if (!path1[1][0])
		printf("deleted file mode %s\n", temp[0].mode);
	else {
		if (strcmp(temp[0].mode, temp[1].mode)) {
			printf("old mode %s\n", temp[0].mode);
			printf("new mode %s\n", temp[1].mode);
		}
		if (strncmp(temp[0].mode, temp[1].mode, 3))
			/* we do not run diff between different kind
			 * of objects.
			 */
			exit(0);
	}
	fflush(NULL);
	execlp("/bin/sh","sh", "-c", cmd, NULL);
}

/*
 * Given a name and sha1 pair, if the dircache tells us the file in
 * the work tree has that object contents, return true, so that
 * prepare_temp_file() does not have to inflate and extract.
 */
static int work_tree_matches(const char *name, const unsigned char *sha1)
{
	struct cache_entry *ce;
	struct stat st;
	int pos, len;
	
	/* We do not read the cache ourselves here, because the
	 * benchmark with my previous version that always reads cache
	 * shows that it makes things worse for diff-tree comparing
	 * two linux-2.6 kernel trees in an already checked out work
	 * tree.  This is because most diff-tree comparison deals with
	 * only a small number of files, while reading the cache is
	 * expensive for a large project, and its cost outweighs the
	 * savings we get by not inflating the object to a temporary
	 * file.  Practically, this code only helps when we are used
	 * by diff-cache --cached, which does read the cache before
	 * calling us.
	 */ 
	if (!active_cache)
		return 0;

	len = strlen(name);
	pos = cache_name_pos(name, len);
	if (pos < 0)
		return 0;
	ce = active_cache[pos];
	if ((lstat(name, &st) < 0) ||
	    !S_ISREG(st.st_mode) ||
	    ce_match_stat(ce, &st) ||
	    memcmp(sha1, ce->sha1, 20))
		return 0;
	return 1;
}

static void prep_temp_blob(struct diff_tempfile *temp,
			   void *blob,
			   unsigned long size,
			   unsigned char *sha1,
			   int mode)
{
	int fd;

	strcpy(temp->tmp_path, ".diff_XXXXXX");
	fd = mkstemp(temp->tmp_path);
	if (fd < 0)
		die("unable to create temp-file");
	if (write(fd, blob, size) != size)
		die("unable to write temp-file");
	close(fd);
	temp->name = temp->tmp_path;
	strcpy(temp->hex, sha1_to_hex(sha1));
	temp->hex[40] = 0;
	sprintf(temp->mode, "%06o", mode);
}

static void prepare_temp_file(const char *name,
			      struct diff_tempfile *temp,
			      struct diff_spec *one)
{
	static unsigned char null_sha1[20] = { 0, };
	int use_work_tree = 0;

	if (!one->file_valid) {
	not_a_valid_file:
		/* A '-' entry produces this for file-2, and
		 * a '+' entry produces this for file-1.
		 */
		temp->name = "/dev/null";
		strcpy(temp->hex, ".");
		strcpy(temp->mode, ".");
		return;
	}

	if (one->sha1_valid &&
	    (!memcmp(one->blob_sha1, null_sha1, sizeof(null_sha1)) ||
	     work_tree_matches(name, one->blob_sha1)))
		use_work_tree = 1;

	if (!one->sha1_valid || use_work_tree) {
		struct stat st;
		temp->name = name;
		if (lstat(temp->name, &st) < 0) {
			if (errno == ENOENT)
				goto not_a_valid_file;
			die("stat(%s): %s", temp->name, strerror(errno));
		}
		if (S_ISLNK(st.st_mode)) {
			int ret;
			char *buf, buf_[1024];
			buf = ((sizeof(buf_) < st.st_size) ?
			       xmalloc(st.st_size) : buf_);
			ret = readlink(name, buf, st.st_size);
			if (ret < 0)
				die("readlink(%s)", name);
			prep_temp_blob(temp, buf, st.st_size,
				       (one->sha1_valid ?
					one->blob_sha1 : null_sha1),
				       (one->sha1_valid ?
					one->mode : S_IFLNK));
		}
		else {
			if (!one->sha1_valid)
				strcpy(temp->hex, sha1_to_hex(null_sha1));
			else
				strcpy(temp->hex, sha1_to_hex(one->blob_sha1));
			sprintf(temp->mode, "%06o",
				S_IFREG |ce_permissions(st.st_mode));
		}
		return;
	}
	else {
		void *blob;
		char type[20];
		unsigned long size;

		blob = read_sha1_file(one->blob_sha1, type, &size);
		if (!blob || strcmp(type, "blob"))
			die("unable to read blob object for %s (%s)",
			    name, sha1_to_hex(one->blob_sha1));
		prep_temp_blob(temp, blob, size, one->blob_sha1, one->mode);
		free(blob);
	}
}

static void remove_tempfile(void)
{
	int i;

	for (i = 0; i < 2; i++)
		if (diff_temp[i].name == diff_temp[i].tmp_path) {
			unlink(diff_temp[i].name);
			diff_temp[i].name = NULL;
		}
}

static void remove_tempfile_on_signal(int signo)
{
	remove_tempfile();
}

/* An external diff command takes:
 *
 * diff-cmd name infile1 infile1-sha1 infile1-mode \
 *               infile2 infile2-sha1 infile2-mode.
 *
 */
void run_external_diff(const char *name,
		       struct diff_spec *one,
		       struct diff_spec *two)
{
	struct diff_tempfile *temp = diff_temp;
	pid_t pid;
	int status;
	static int atexit_asked = 0;

	if (one && two) {
		prepare_temp_file(name, &temp[0], one);
		prepare_temp_file(name, &temp[1], two);
		if (! atexit_asked &&
		    (temp[0].name == temp[0].tmp_path ||
		     temp[1].name == temp[1].tmp_path)) {
			atexit_asked = 1;
			atexit(remove_tempfile);
		}
		signal(SIGINT, remove_tempfile_on_signal);
	}

	fflush(NULL);
	pid = fork();
	if (pid < 0)
		die("unable to fork");
	if (!pid) {
		const char *pgm = external_diff();
		if (pgm) {
			if (one && two)
				execlp(pgm, pgm,
				       name,
				       temp[0].name, temp[0].hex, temp[0].mode,
				       temp[1].name, temp[1].hex, temp[1].mode,
				       NULL);
			else
				execlp(pgm, pgm, name, NULL);
		}
		/*
		 * otherwise we use the built-in one.
		 */
		if (one && two)
			builtin_diff(name, temp);
		else
			printf("* Unmerged path %s\n", name);
		exit(0);
	}
	if (waitpid(pid, &status, 0) < 0 ||
	    !WIFEXITED(status) || WEXITSTATUS(status)) {
		/* Earlier we did not check the exit status because
		 * diff exits non-zero if files are different, and
		 * we are not interested in knowing that.  It was a
		 * mistake which made it harder to quit a diff-*
		 * session that uses the git-apply-patch-script as
		 * the GIT_EXTERNAL_DIFF.  A custom GIT_EXTERNAL_DIFF
		 * should also exit non-zero only when it wants to
		 * abort the entire diff-* session.
		 */
		remove_tempfile();
		fprintf(stderr, "external diff died, stopping at %s.\n", name);
		exit(1);
	}
	remove_tempfile();
}

void diff_addremove(int addremove, unsigned mode,
		    const unsigned char *sha1,
		    const char *base, const char *path)
{
	char concatpath[PATH_MAX];
	struct diff_spec spec[2], *one, *two;

	memcpy(spec[0].blob_sha1, sha1, 20);
	spec[0].mode = mode;
	spec[0].sha1_valid = spec[0].file_valid = 1;
	spec[1].file_valid = 0;

	if (addremove == '+') {
		one = spec + 1; two = spec;
	} else {
		one = spec; two = one + 1;
	}
	
	if (path) {
		strcpy(concatpath, base);
		strcat(concatpath, path);
	}
	run_external_diff(path ? concatpath : base, one, two);
}

void diff_change(unsigned old_mode, unsigned new_mode,
		 const unsigned char *old_sha1,
		 const unsigned char *new_sha1,
		 const char *base, const char *path) {
	char concatpath[PATH_MAX];
	struct diff_spec spec[2];

	memcpy(spec[0].blob_sha1, old_sha1, 20);
	spec[0].mode = old_mode;
	memcpy(spec[1].blob_sha1, new_sha1, 20);
	spec[1].mode = new_mode;
	spec[0].sha1_valid = spec[0].file_valid = 1;
	spec[1].sha1_valid = spec[1].file_valid = 1;

	if (path) {
		strcpy(concatpath, base);
		strcat(concatpath, path);
	}
	run_external_diff(path ? concatpath : base, &spec[0], &spec[1]);
}

void diff_unmerge(const char *path)
{
	run_external_diff(path, NULL, NULL);
}
