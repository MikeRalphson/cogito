/*
 * GIT - The information manager from hell
 *
 * Copyright (C) Linus Torvalds, 2005
 */
#include "cache.h"

static int stage = 0;

static int unpack_tree(unsigned char *sha1)
{
	void *buffer;
	unsigned long size;
	int ret;

	buffer = read_object_with_reference(sha1, "tree", &size, 0);
	if (!buffer)
		return -1;
	ret = read_tree(buffer, size, stage);
	free(buffer);
	return ret;
}

static char *lockfile_name;

static void remove_lock_file(void)
{
	if (lockfile_name)
		unlink(lockfile_name);
}

static int path_matches(struct cache_entry *a, struct cache_entry *b)
{
	int len = ce_namelen(a);
	return ce_namelen(b) == len &&
		!memcmp(a->name, b->name, len);
}

static int same(struct cache_entry *a, struct cache_entry *b)
{
	return a->ce_mode == b->ce_mode && 
		!memcmp(a->sha1, b->sha1, 20);
}


/*
 * This removes all trivial merges that don't change the tree
 * and collapses them to state 0.
 *
 * _Any_ other merge is left to user policy.  That includes "both
 * created the same file", and "both removed the same file" - which are
 * trivial, but the user might still want to _note_ it. 
 */
static struct cache_entry *merge_entries(struct cache_entry *a,
					 struct cache_entry *b,
					 struct cache_entry *c)
{
	int len = ce_namelen(a);

	/*
	 * Are they all the same filename? We won't do
	 * any name merging
	 */
	if (ce_namelen(b) != len ||
	    ce_namelen(c) != len ||
	    memcmp(a->name, b->name, len) ||
	    memcmp(a->name, c->name, len))
		return NULL;

	/*
	 * Ok, all three entries describe the same
	 * filename, but maybe the contents or file
	 * mode have changed?
	 *
	 * The trivial cases end up being the ones where two
	 * out of three files are the same:
	 *  - both destinations the same, trivially take either
	 *  - one of the destination versions hasn't changed,
	 *    take the other.
	 *
	 * The "all entries exactly the same" case falls out as
	 * a special case of any of the "two same" cases.
	 *
	 * Here "a" is "original", and "b" and "c" are the two
	 * trees we are merging.
	 */
	if (same(b,c))
		return c;
	if (same(a,b))
		return c;
	if (same(a,c))
		return b;
	return NULL;
}

static void trivially_merge_cache(struct cache_entry **src, int nr)
{
	static struct cache_entry null_entry;
	struct cache_entry **dst = src;
	struct cache_entry *old = &null_entry;

	while (nr) {
		struct cache_entry *ce, *result;

		ce = src[0];

		/* We throw away original cache entries except for the stat information */
		if (!ce_stage(ce)) {
			old = ce;
			src++;
			nr--;
			active_nr--;
			continue;
		}
		if (nr > 2 && (result = merge_entries(ce, src[1], src[2])) != NULL) {
			/*
			 * See if we can re-use the old CE directly?
			 * That way we get the uptodate stat info.
			 */
			if (path_matches(result, old) && same(result, old))
				*result = *old;
			ce = result;
			ce->ce_flags &= ~htons(CE_STAGEMASK);
			src += 2;
			nr -= 2;
			active_nr -= 2;
		}
		*dst++ = ce;
		src++;
		nr--;
	}
}

static void merge_stat_info(struct cache_entry **src, int nr)
{
	static struct cache_entry null_entry;
	struct cache_entry **dst = src;
	struct cache_entry *old = &null_entry;

	while (nr) {
		struct cache_entry *ce;

		ce = src[0];

		/* We throw away original cache entries except for the stat information */
		if (!ce_stage(ce)) {
			old = ce;
			src++;
			nr--;
			active_nr--;
			continue;
		}
		if (path_matches(ce, old) && same(ce, old))
			*ce = *old;
		ce->ce_flags &= ~htons(CE_STAGEMASK);
		*dst++ = ce;
		src++;
		nr--;
	}
}

static const char *read_tree_usage = "read-tree (<sha> | -m <sha1> [<sha2> <sha3>])";

int main(int argc, char **argv)
{
	int i, newfd, merge;
	unsigned char sha1[20];
	static char lockfile[MAXPATHLEN+1];
	const char *indexfile = get_index_file();

	snprintf(lockfile, sizeof(lockfile), "%s.lock", indexfile);

	newfd = open(lockfile, O_RDWR | O_CREAT | O_EXCL, 0600);
	if (newfd < 0)
		die("unable to create new cachefile");
	atexit(remove_lock_file);
	lockfile_name = lockfile;

	merge = 0;
	for (i = 1; i < argc; i++) {
		const char *arg = argv[i];

		/* "-m" stands for "merge", meaning we start in stage 1 */
		if (!strcmp(arg, "-m")) {
			int i;
			if (stage)
				die("-m needs to come first");
			read_cache();
			for (i = 0; i < active_nr; i++) {
				if (ce_stage(active_cache[i]))
					die("you need to resolve your current index first");
			}
			stage = 1;
			merge = 1;
			continue;
		}
		if (get_sha1(arg, sha1) < 0)
			usage(read_tree_usage);
		if (stage > 3)
			usage(read_tree_usage);
		if (unpack_tree(sha1) < 0)
			die("failed to unpack tree object %s", arg);
		stage++;
	}
	if (merge) {
		switch (stage) {
		case 4:	/* Three-way merge */
			trivially_merge_cache(active_cache, active_nr);
			break;
		case 2:	/* Just read a tree, merge with old cache contents */
			merge_stat_info(active_cache, active_nr);
			break;
		default:
			die("just how do you expect me to merge %d trees?", stage-1);
		}
	}
	if (write_cache(newfd, active_cache, active_nr) || rename(lockfile, indexfile))
		die("unable to write new index file");
	lockfile_name = NULL;
	return 0;
}
