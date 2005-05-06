/*
 * GIT - The information manager from hell
 *
 * Copyright (C) Linus Torvalds, 2005
 */
#include <signal.h>
#include "cache.h"

/*
 * Default to not allowing changes to the list of files. The
 * tool doesn't actually care, but this makes it harder to add
 * files to the revision control by mistake by doing something
 * like "update-cache *" and suddenly having all the object
 * files be revision controlled.
 */
static int allow_add = 0, allow_remove = 0, not_new = 0;

/*
 * update-cache --refresh may not touch anything at all, in which case
 * writing 1.6MB of the same thing is a waste.
 */
static int cache_changed = 0;

/* Three functions to allow overloaded pointer return; see linux/err.h */
static inline void *ERR_PTR(long error)
{
	return (void *) error;
}

static inline long PTR_ERR(const void *ptr)
{
	return (long) ptr;
}

static inline long IS_ERR(const void *ptr)
{
	return (unsigned long)ptr > (unsigned long)-1000L;
}

/*
 * This only updates the "non-critical" parts of the directory
 * cache, ie the parts that aren't tracked by GIT, and only used
 * to validate the cache.
 */
static void fill_stat_cache_info(struct cache_entry *ce, struct stat *st)
{
	ce->ce_ctime.sec = htonl(st->st_ctime);
	ce->ce_mtime.sec = htonl(st->st_mtime);
#ifdef NSEC
	ce->ce_ctime.nsec = htonl(st->st_ctim.tv_nsec);
	ce->ce_mtime.nsec = htonl(st->st_mtim.tv_nsec);
#endif
	ce->ce_dev = htonl(st->st_dev);
	ce->ce_ino = htonl(st->st_ino);
	ce->ce_uid = htonl(st->st_uid);
	ce->ce_gid = htonl(st->st_gid);
	ce->ce_size = htonl(st->st_size);
}

static int add_file_to_cache_1(char *path)
{
	int size, namelen;
	struct cache_entry *ce;
	struct stat st;
	int fd;
	char *target;

	if (lstat(path, &st) < 0) {
		if (errno == ENOENT || errno == ENOTDIR) {
			if (allow_remove)
				return remove_file_from_cache(path);
		}
		return error("open(\"%s\"): %s", path, strerror(errno));
	}
	namelen = strlen(path);
	size = cache_entry_size(namelen);
	ce = xmalloc(size);
	memset(ce, 0, size);
	memcpy(ce->name, path, namelen);
	fill_stat_cache_info(ce, &st);
	ce->ce_mode = create_ce_mode(st.st_mode);
	ce->ce_flags = htons(namelen);
	switch (st.st_mode & S_IFMT) {
	case S_IFREG:
		fd = open(path, O_RDONLY);
		if (fd < 0)
			return -1;
		if (index_fd(ce->sha1, fd, &st) < 0)
			return -1;
		break;
	case S_IFLNK:
		target = xmalloc(st.st_size+1);
		if (readlink(path, target, st.st_size+1) != st.st_size) {
			free(target);
			return -1;
		}
		if (write_sha1_file(target, st.st_size, "blob", ce->sha1))
			return -1;
		free(target);
		break;
	default:
		return -1;
	}
	if (!cache_changed) {
		/* If we have not smudged the cache, be careful
		 * to keep it clean.  Find out if we have a matching
		 * cache entry that add_cache_entry would replace with,
		 * and if it matches then do not bother calling it.
		 */
		int pos = cache_name_pos(ce->name, namelen);
		if ((0 <= pos) &&
		    !memcmp(active_cache[pos], ce, sizeof(*ce))) {
			free(ce);
			/* magic to tell add_file_to_cache that
			 * we have not updated anything.
			 */
			return 999;
		}
	}
	return add_cache_entry(ce, allow_add);
}

static int add_file_to_cache(char *path)
{
	int ret = add_file_to_cache_1(path);
	if (ret == 0)
		cache_changed = 1;
	else if (ret == 999)
		ret = 0;
	return ret;
}

static int match_data(int fd, void *buffer, unsigned long size)
{
	while (size) {
		char compare[1024];
		int ret = read(fd, compare, sizeof(compare));

		if (ret <= 0 || ret > size || memcmp(buffer, compare, ret))
			return -1;
		size -= ret;
		buffer += ret;
	}
	return 0;
}

static int compare_data(struct cache_entry *ce, unsigned long expected_size)
{
	int match = -1;
	int fd = open(ce->name, O_RDONLY);

	if (fd >= 0) {
		void *buffer;
		unsigned long size;
		char type[20];

		buffer = read_sha1_file(ce->sha1, type, &size);
		if (buffer) {
			if (size == expected_size && !strcmp(type, "blob"))
				match = match_data(fd, buffer, size);
			free(buffer);
		}
		close(fd);
	}
	return match;
}

static int compare_link(struct cache_entry *ce, unsigned long expected_size)
{
	int match = -1;
	char *target;
	void *buffer;
	unsigned long size;
	char type[10];
	int len;

	target = xmalloc(expected_size);
	len = readlink(ce->name, target, expected_size);
	if (len != expected_size) {
		free(target);
		return -1;
	}
	buffer = read_sha1_file(ce->sha1, type, &size);
	if (!buffer) {
		free(target);
		return -1;
	}
	if (size == expected_size)
		match = memcmp(buffer, target, size);
	free(buffer);
	free(target);
	return match;
}

/*
 * "refresh" does not calculate a new sha1 file or bring the
 * cache up-to-date for mode/content changes. But what it
 * _does_ do is to "re-match" the stat information of a file
 * with the cache, so that you can refresh the cache for a
 * file that hasn't been changed but where the stat entry is
 * out of date.
 *
 * For example, you'd want to do this after doing a "read-tree",
 * to link up the stat cache details with the proper files.
 */
static struct cache_entry *refresh_entry(struct cache_entry *ce)
{
	struct stat st;
	struct cache_entry *updated;
	int changed, size;

	if (lstat(ce->name, &st) < 0)
		return ERR_PTR(-errno);

	changed = cache_match_stat(ce, &st);
	if (!changed)
		return ce;

	/*
	 * If the mode or type has changed, there's no point in trying
	 * to refresh the entry - it's not going to match
	 */
	if (changed & (MODE_CHANGED | TYPE_CHANGED))
		return ERR_PTR(-EINVAL);

	switch (st.st_mode & S_IFMT) {
	case S_IFREG:
		if (compare_data(ce, st.st_size))
			return ERR_PTR(-EINVAL);
		break;
	case S_IFLNK:
		if (compare_link(ce, st.st_size))
			return ERR_PTR(-EINVAL);
		break;
	default:
		return ERR_PTR(-EINVAL);
	}

	cache_changed = 1;
	size = ce_size(ce);
	updated = xmalloc(size);
	memcpy(updated, ce, size);
	fill_stat_cache_info(updated, &st);
	return updated;
}

static int refresh_cache(void)
{
	int i;
	int has_errors = 0;

	for (i = 0; i < active_nr; i++) {
		struct cache_entry *ce, *new;
		ce = active_cache[i];
		if (ce_stage(ce)) {
			printf("%s: needs merge\n", ce->name);
			has_errors = 1;
			while ((i < active_nr) &&
			       ! strcmp(active_cache[i]->name, ce->name))
				i++;
			i--;
			continue;
		}

		new = refresh_entry(ce);
		if (IS_ERR(new)) {
			if (!(not_new && PTR_ERR(new) == -ENOENT)) {
				printf("%s: needs update\n", ce->name);
				has_errors = 1;
			}
			continue;
		}
		/* You can NOT just free active_cache[i] here, since it
		 * might not be necessarily malloc()ed but can also come
		 * from mmap(). */
		active_cache[i] = new;
	}
	return has_errors;
}

/*
 * We fundamentally don't like some paths: we don't want
 * dot or dot-dot anywhere, and in fact, we don't even want
 * any other dot-files (.git or anything else). They
 * are hidden, for chist sake.
 *
 * Also, we don't want double slashes or slashes at the
 * end that can make pathnames ambiguous.
 */
static int verify_path(char *path)
{
	char c;

	goto inside;
	for (;;) {
		if (!c)
			return 1;
		if (c == '/') {
inside:
			c = *path++;
			if (c != '/' && c != '.' && c != '\0')
				continue;
			return 0;
		}
		c = *path++;
	}
}

static int add_cacheinfo(char *arg1, char *arg2, char *arg3)
{
	int size, len;
	unsigned int mode;
	unsigned char sha1[20];
	struct cache_entry *ce;

	if (sscanf(arg1, "%o", &mode) != 1)
		return -1;
	if (get_sha1_hex(arg2, sha1))
		return -1;
	if (!verify_path(arg3))
		return -1;

	cache_changed = 1;
	len = strlen(arg3);
	size = cache_entry_size(len);
	ce = xmalloc(size);
	memset(ce, 0, size);

	memcpy(ce->sha1, sha1, 20);
	memcpy(ce->name, arg3, len);
	ce->ce_flags = htons(len);
	ce->ce_mode = create_ce_mode(mode);
	return add_cache_entry(ce, allow_add);
}

static const char *lockfile_name = NULL;

static void remove_lock_file(void)
{
	if (lockfile_name)
		unlink(lockfile_name);
}

static void remove_lock_file_on_signal(int signo)
{
	remove_lock_file();
}

int main(int argc, char **argv)
{
	int i, newfd, entries, has_errors = 0;
	int allow_options = 1;
	static char lockfile[MAXPATHLEN+1];
	const char *indexfile = get_index_file();

	snprintf(lockfile, sizeof(lockfile), "%s.lock", indexfile);

	newfd = open(lockfile, O_RDWR | O_CREAT | O_EXCL, 0600);
	if (newfd < 0)
		die("unable to create new cachefile");

	signal(SIGINT, remove_lock_file_on_signal);
	atexit(remove_lock_file);
	lockfile_name = lockfile;

	entries = read_cache();
	if (entries < 0)
		die("cache corrupted");

	for (i = 1 ; i < argc; i++) {
		char *path = argv[i];

		if (allow_options && *path == '-') {
			if (!strcmp(path, "--")) {
				allow_options = 0;
				continue;
			}
			if (!strcmp(path, "--add")) {
				allow_add = 1;
				continue;
			}
			if (!strcmp(path, "--remove")) {
				allow_remove = 1;
				continue;
			}
			if (!strcmp(path, "--refresh")) {
				has_errors |= refresh_cache();
				continue;
			}
			if (!strcmp(path, "--cacheinfo")) {
				if (i+3 >= argc || add_cacheinfo(argv[i+1], argv[i+2], argv[i+3]))
					die("update-cache: --cacheinfo <mode> <sha1> <path>");
				i += 3;
				continue;
			}
			if (!strcmp(path, "--force-remove")) {
				if (argc <= i + 1)
					die("update-cache: --force-remove <path>");
				if (remove_file_from_cache(argv[i+1]))
					die("update-cache: --force-remove cannot remove %s", argv[i+1]);
				i++;
				continue;
			}

			if (!strcmp(path, "--ignore-missing")) {
				not_new = 1;
				continue;
			}
			die("unknown option %s", path);
		}
		if (!verify_path(path)) {
			fprintf(stderr, "Ignoring path %s\n", argv[i]);
			continue;
		}
		if (add_file_to_cache(path))
			die("Unable to add %s to database", path);
	}

	if (!cache_changed)
		unlink(lockfile);
	else if (write_cache(newfd, active_cache, active_nr) ||
		 rename(lockfile, indexfile))
		die("Unable to write new cachefile");

	lockfile_name = NULL;
	return has_errors ? 1 : 0;
}
