#include <ctype.h>
#include "cache.h"
#include "diff.h"

static int silent = 0;
static int verbose_header = 0;
static int ignore_merges = 1;
static int recursive = 0;
static int read_stdin = 0;
static int line_termination = '\n';
static int generate_patch = 0;
static const char *header = NULL;
static const char *header_prefix = "";

// What paths are we interested in?
static int nr_paths = 0;
static char **paths = NULL;
static int *pathlens = NULL;

static int diff_tree_sha1(const unsigned char *old, const unsigned char *new, const char *base);

static void update_tree_entry(void **bufp, unsigned long *sizep)
{
	void *buf = *bufp;
	unsigned long size = *sizep;
	int len = strlen(buf) + 1 + 20;

	if (size < len)
		die("corrupt tree file");
	*bufp = buf + len;
	*sizep = size - len;
}

static const unsigned char *extract(void *tree, unsigned long size, const char **pathp, unsigned int *modep)
{
	int len = strlen(tree)+1;
	const unsigned char *sha1 = tree + len;
	const char *path = strchr(tree, ' ');

	if (!path || size < len + 20 || sscanf(tree, "%o", modep) != 1)
		die("corrupt tree file");
	*pathp = path+1;
	return sha1;
}

static char *malloc_base(const char *base, const char *path, int pathlen)
{
	int baselen = strlen(base);
	char *newbase = xmalloc(baselen + pathlen + 2);
	memcpy(newbase, base, baselen);
	memcpy(newbase + baselen, path, pathlen);
	memcpy(newbase + baselen + pathlen, "/", 2);
	return newbase;
}

static void show_file(const char *prefix, void *tree, unsigned long size, const char *base);

/* A whole sub-tree went away or appeared */
static void show_tree(const char *prefix, void *tree, unsigned long size, const char *base)
{
	while (size) {
		show_file(prefix, tree, size, base);
		update_tree_entry(&tree, &size);
	}
}

/* A file entry went away or appeared */
static void show_file(const char *prefix, void *tree, unsigned long size, const char *base)
{
	unsigned mode;
	const char *path;
	const unsigned char *sha1 = extract(tree, size, &path, &mode);

	if (header) {
		printf("%s", header);
		header = NULL;
	}

	if (silent)
		return;

	if (recursive && S_ISDIR(mode)) {
		char type[20];
		unsigned long size;
		char *newbase = malloc_base(base, path, strlen(path));
		void *tree;

		tree = read_sha1_file(sha1, type, &size);
		if (!tree || strcmp(type, "tree"))
			die("corrupt tree sha %s", sha1_to_hex(sha1));

		show_tree(prefix, tree, size, newbase);
		
		free(tree);
		free(newbase);
		return;
	}

	if (generate_patch) {
		if (!S_ISDIR(mode))
			diff_addremove(prefix[0], mode, sha1, base, path);
	}
	else
		printf("%s%06o\t%s\t%s\t%s%s%c", prefix, mode,
		       S_ISDIR(mode) ? "tree" : "blob",
		       sha1_to_hex(sha1), base, path,
		       line_termination);
}

static int compare_tree_entry(void *tree1, unsigned long size1, void *tree2, unsigned long size2, const char *base)
{
	unsigned mode1, mode2;
	const char *path1, *path2;
	const unsigned char *sha1, *sha2;
	int cmp, pathlen1, pathlen2;
	char old_sha1_hex[50];

	sha1 = extract(tree1, size1, &path1, &mode1);
	sha2 = extract(tree2, size2, &path2, &mode2);

	pathlen1 = strlen(path1);
	pathlen2 = strlen(path2);
	cmp = cache_name_compare(path1, pathlen1, path2, pathlen2);
	if (cmp < 0) {
		show_file("-", tree1, size1, base);
		return -1;
	}
	if (cmp > 0) {
		show_file("+", tree2, size2, base);
		return 1;
	}
	if (!memcmp(sha1, sha2, 20) && mode1 == mode2)
		return 0;

	/*
	 * If the filemode has changed to/from a directory from/to a regular
	 * file, we need to consider it a remove and an add.
	 */
	if (S_ISDIR(mode1) != S_ISDIR(mode2)) {
		show_file("-", tree1, size1, base);
		show_file("+", tree2, size2, base);
		return 0;
	}

	if (recursive && S_ISDIR(mode1)) {
		int retval;
		char *newbase = malloc_base(base, path1, pathlen1);
		retval = diff_tree_sha1(sha1, sha2, newbase);
		free(newbase);
		return retval;
	}

	if (header) {
		printf("%s", header);
		header = NULL;
	}
	if (silent)
		return 0;

	if (generate_patch) {
		if (!S_ISDIR(mode1))
			diff_change(mode1, mode2, sha1, sha2, base, path1);
	}
	else {
		strcpy(old_sha1_hex, sha1_to_hex(sha1));
		printf("*%06o->%06o\t%s\t%s->%s\t%s%s%c", mode1, mode2,
		       S_ISDIR(mode1) ? "tree" : "blob",
		       old_sha1_hex, sha1_to_hex(sha2), base, path1,
		       line_termination);
	}
	return 0;
}

static int interesting(void *tree, unsigned long size, const char *base)
{
	const char *path;
	unsigned mode;
	int i;
	int baselen, pathlen;

	if (!nr_paths)
		return 1;

	(void)extract(tree, size, &path, &mode);

	pathlen = strlen(path);
	baselen = strlen(base);

	for (i=0; i < nr_paths; i++) {
		const char *match = paths[i];
		int matchlen = pathlens[i];

		if (baselen >= matchlen) {
			/* If it doesn't match, move along... */
			if (strncmp(base, match, matchlen))
				continue;

			/* The base is a subdirectory of a path which was specified. */
			return 1;
		}

		/* Does the base match? */
		if (strncmp(base, match, baselen))
			continue;

		match += baselen;
		matchlen -= baselen;

		if (pathlen > matchlen)
			continue;

		if (strncmp(path, match, pathlen))
			continue;

		return 1;
	}
	return 0; /* No matches */
}

static int diff_tree(void *tree1, unsigned long size1, void *tree2, unsigned long size2, const char *base)
{
	while (size1 | size2) {
		if (nr_paths && size1 && !interesting(tree1, size1, base)) {
			update_tree_entry(&tree1, &size1);
			continue;
		}
		if (nr_paths && size2 && !interesting(tree2, size2, base)) {
			update_tree_entry(&tree2, &size2);
			continue;
		}
		if (!size1) {
			show_file("+", tree2, size2, base);
			update_tree_entry(&tree2, &size2);
			continue;
		}
		if (!size2) {
			show_file("-", tree1, size1, base);
			update_tree_entry(&tree1, &size1);
			continue;
		}
		switch (compare_tree_entry(tree1, size1, tree2, size2, base)) {
		case -1:
			update_tree_entry(&tree1, &size1);
			continue;
		case 0:
			update_tree_entry(&tree1, &size1);
			/* Fallthrough */
		case 1:
			update_tree_entry(&tree2, &size2);
			continue;
		}
		die("diff-tree: internal error");
	}
	return 0;
}

static int diff_tree_sha1(const unsigned char *old, const unsigned char *new, const char *base)
{
	void *tree1, *tree2;
	unsigned long size1, size2;
	int retval;

	tree1 = read_object_with_reference(old, "tree", &size1, 0);
	if (!tree1)
		die("unable to read source tree (%s)", sha1_to_hex(old));
	tree2 = read_object_with_reference(new, "tree", &size2, 0);
	if (!tree2)
		die("unable to read destination tree (%s)", sha1_to_hex(new));
	retval = diff_tree(tree1, size1, tree2, size2, base);
	free(tree1);
	free(tree2);
	return retval;
}

static int get_one_line(const char *msg, unsigned long len)
{
	int ret = 0;

	while (len--) {
		ret++;
		if (*msg++ == '\n')
			break;
	}
	return ret;
}

static int add_author_info(char *buf, const char *line, int len)
{
	char *date;
	unsigned int namelen;
	unsigned long time;
	int tz;

	line += strlen("author ");
	date = strchr(line, '>');
	if (!date)
		return 0;
	namelen = ++date - line;
	time = strtoul(date, &date, 10);
	tz = strtol(date, NULL, 10);

	return sprintf(buf, "Author: %.*s\nDate:   %s\n",
		namelen, line,
		show_date(time, tz));
}

static char *generate_header(const char *commit, const char *parent, const char *msg, unsigned long len)
{
	static char this_header[1000];
	int offset;

	offset = sprintf(this_header, "%s%s (from %s)\n", header_prefix, commit, parent);
	if (verbose_header) {
		int hdr = 1;

		for (;;) {
			const char *line = msg;
			int linelen = get_one_line(msg, len);

			if (!linelen)
				break;
			if (offset + linelen + 10 > sizeof(this_header))
				break;

			msg += linelen;
			len -= linelen;
			if (linelen == 1)
				hdr = 0;
			if (hdr) {
				if (!memcmp(line, "author ", 7))
					offset += add_author_info(this_header + offset, line, linelen);
				continue;
			}
			memset(this_header + offset, ' ', 4);
			memcpy(this_header + offset + 4, line, linelen);
			offset += linelen + 4;
		}
		this_header[offset++] = '\n';
		this_header[offset] = 0;
	}

	return this_header;
}

static int diff_tree_stdin(char *line)
{
	int len = strlen(line);
	unsigned char commit[20], parent[20];
	unsigned long size, offset;
	static char this_header[1000];
	char *buf;

	if (!len || line[len-1] != '\n')
		return -1;
	line[len-1] = 0;
	if (get_sha1_hex(line, commit))
		return -1;
	if (isspace(line[40]) && !get_sha1_hex(line+41, parent)) {
		line[40] = 0;
		line[81] = 0;
		sprintf(this_header, "%s (from %s)\n", line, line+41);
		header = this_header;
		return diff_tree_sha1(parent, commit, "");
	}
	buf = read_object_with_reference(commit, "commit", &size, NULL);
	if (!buf)
		return -1;

	/* More than one parent? */
	if (ignore_merges) {
		if (!memcmp(buf + 46 + 48, "parent ", 7))
			return 0;
	}

	line[40] = 0;
	offset = 46;
	while (offset + 48 < size && !memcmp(buf + offset, "parent ", 7)) {
		if (get_sha1_hex(buf + offset + 7, parent))
			return -1;
		header = generate_header(line, sha1_to_hex(parent), buf, size);
		diff_tree_sha1(parent, commit, "");
		if (!header && verbose_header)
			header_prefix = "\ndiff-tree ";
		offset += 48;
	}
	return -1;
}

static char *diff_tree_usage =
"diff-tree [-p] [-r] [-z] [--stdin] [-m] [-s] [-v] <tree sha1> <tree sha1>";

int main(int argc, char **argv)
{
	char line[1000];
	unsigned char old[20], new[20];

	for (;;) {
		char *arg;

		argv++;
		argc--;
		arg = *argv;
		if (!arg || *arg != '-')
			break;

		if (!strcmp(arg, "-")) {
			argv++;
			argc--;
			break;
		}
		if (!strcmp(arg, "-r")) {
			recursive = 1;
			continue;
		}
		if (!strcmp(arg, "-p")) {
			recursive = generate_patch = 1;
			continue;
		}
		if (!strcmp(arg, "-z")) {
			line_termination = '\0';
			continue;
		}
		if (!strcmp(arg, "-m")) {
			ignore_merges = 0;
			continue;
		}
		if (!strcmp(arg, "-s")) {
			silent = 1;
			continue;
		}
		if (!strcmp(arg, "-v")) {
			verbose_header = 1;
			header_prefix = "diff-tree ";
			continue;
		}
		if (!strcmp(arg, "--stdin")) {
			read_stdin = 1;
			continue;
		}
		usage(diff_tree_usage);
	}

	if (!read_stdin) {
		if (argc < 2 || get_sha1(argv[0], old) || get_sha1(argv[1], new))
			usage(diff_tree_usage);
		argv += 2;
		argc -= 2;
	}

	if (argc > 0) {
		int i;

		paths = argv;
		nr_paths = argc;
		pathlens = xmalloc(nr_paths * sizeof(int));
		for (i=0; i<nr_paths; i++)
			pathlens[i] = strlen(paths[i]);
	}

	if (!read_stdin)
		return diff_tree_sha1(old, new, "");

	while (fgets(line, sizeof(line), stdin))
		diff_tree_stdin(line);

	return 0;
}
