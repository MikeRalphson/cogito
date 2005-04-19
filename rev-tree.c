#define _XOPEN_SOURCE /* glibc2 needs this */
#define _BSD_SOURCE /* for tm.tm_gmtoff */
#include <time.h>
#include <ctype.h>

#include "cache.h"
#include "commit.h"

/*
 * revision.h leaves the low 16 bits of the "flags" field of the
 * revision data structure unused. We use it for a "reachable from
 * this commit <N>" bitmask.
 */
#define MAX_COMMITS 16

static int show_edges = 0;
static int basemask = 0;

static void read_cache_file(const char *path)
{
	die("no revtree cache file yet");
}

/*
 * Some revisions are less interesting than others.
 *
 * For example, if we use a cache-file, that one may contain
 * revisions that were never used. They are never interesting.
 *
 * And sometimes we're only interested in "edge" commits, ie
 * places where the marking changes between parent and child.
 */
static int interesting(struct commit *rev)
{
	unsigned mask = rev->object.flags;

	if (!mask)
		return 0;
	if (show_edges) {
		struct commit_list *p = rev->parents;
		while (p) {
			if (mask != p->item->object.flags)
				return 1;
			p = p->next;
		}
		return 0;
	}
	if (mask & basemask)
		return 0;

	return 1;
}

void process_commit(unsigned char *sha1)
{
	struct commit_list *parents;
	struct commit *obj = lookup_commit(sha1);

	if (obj && obj->object.parsed)
		return;
	if (!obj || parse_commit(obj))
		die("unable to parse commit (%s)", sha1_to_hex(sha1));
	
	parents = obj->parents;
	while (parents) {
		process_commit(parents->item->object.sha1);
		parents = parents->next;
	}
}

/*
 * Usage: rev-tree [--edges] [--cache <cache-file>] <commit-id> [<commit-id2>]
 *
 * The cache-file can be quite important for big trees. This is an
 * expensive operation if you have to walk the whole chain of
 * parents in a tree with a long revision history.
 */
int main(int argc, char **argv)
{
	int i;
	int nr = 0;
	unsigned char sha1[MAX_COMMITS][20];

	/*
	 * First - pick up all the revisions we can (both from
	 * caches and from commit file chains).
	 */
	for (i = 1; i < argc ; i++) {
		char *arg = argv[i];

		if (!strcmp(arg, "--cache")) {
			read_cache_file(argv[++i]);
			continue;
		}

		if (!strcmp(arg, "--edges")) {
			show_edges = 1;
			continue;
		}

		if (arg[0] == '^') {
			arg++;
			basemask |= 1<<nr;
		}
		if (nr >= MAX_COMMITS || get_sha1_hex(arg, sha1[nr]))
			usage("rev-tree [--edges] [--cache <cache-file>] <commit-id> [<commit-id>]");
		process_commit(sha1[nr]);
		nr++;
	}

	/*
	 * Now we have the maximal tree. Walk the different sha files back to the root.
	 */
	for (i = 0; i < nr; i++)
		mark_reachable(&lookup_commit(sha1[i])->object, 1 << i);

	/*
	 * Now print out the results..
	 */
	for (i = 0; i < nr_objs; i++) {
		struct object *obj = objs[i];
		struct commit *commit;
		struct commit_list *p;

		if (obj->type != commit_type)
			continue;

		commit = (struct commit *) obj;

		if (!interesting(commit))
			continue;

		printf("%lu %s:%d", commit->date, sha1_to_hex(obj->sha1), 
		       obj->flags);
		p = commit->parents;
		while (p) {
			printf(" %s:%d", sha1_to_hex(p->item->object.sha1), 
			       p->item->object.flags);
			p = p->next;
		}
		printf("\n");
	}
	return 0;
}
