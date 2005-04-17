#include <stdlib.h>
#include "cache.h"
#include "revision.h"

static struct revision *process_list(struct parent **list_p, int this_mark,
				     int other_mark)
{
	struct parent *parent, *temp;
	struct parent *posn = *list_p;
	*list_p = NULL;
	while (posn) {
		parse_commit_object(posn->parent);
		if (posn->parent->flags & this_mark) {
			/*
			  printf("%d already seen %s %x\n",
			  this_mark
			  sha1_to_hex(posn->parent->sha1),
			  posn->parent->flags);
			*/
			/* do nothing; this indicates that this side
			 * split and reformed, and we only need to
			 * mark it once.
			 */
		} else if (posn->parent->flags & other_mark) {
			return posn->parent;
		} else {
			/*
			  printf("%d based on %s\n",
			  this_mark,
			  sha1_to_hex(posn->parent->sha1));
			*/
			posn->parent->flags |= this_mark;
			
			parent = posn->parent->parent;
			while (parent) {
				temp = malloc(sizeof(struct parent));
				temp->next = *list_p;
				temp->parent = parent->parent;
				*list_p = temp;
				parent = parent->next;
			}
		}
		posn = posn->next;
	}
	return NULL;
}

struct revision *common_ancestor(struct revision *rev1, struct revision *rev2)
{
	struct parent *rev1list = malloc(sizeof(struct parent));
	struct parent *rev2list = malloc(sizeof(struct parent));

	rev1list->parent = rev1;
	rev1list->next = NULL;

	rev2list->parent = rev2;
	rev2list->next = NULL;

	while (rev1list || rev2list) {
		struct revision *ret;
		ret = process_list(&rev1list, 0x1, 0x2);
		if (ret) {
			/* XXXX free lists */
			return ret;
		}
		ret = process_list(&rev2list, 0x2, 0x1);
		if (ret) {
			/* XXXX free lists */
			return ret;
		}
	}
	return NULL;
}

int main(int argc, char **argv)
{
	struct revision *rev1, *rev2, *ret;
	unsigned char rev1key[20], rev2key[20];

	if (argc != 3 ||
	    get_sha1_hex(argv[1], rev1key) ||
	    get_sha1_hex(argv[2], rev2key)) {
		usage("merge-base <commit-id> <commit-id>");
	}
	rev1 = lookup_rev(rev1key);
	rev2 = lookup_rev(rev2key);
	ret = common_ancestor(rev1, rev2);
	if (ret) {
		printf("%s\n", sha1_to_hex(ret->sha1));
		return 0;
	} else {
		return 1;
	}
	
}
