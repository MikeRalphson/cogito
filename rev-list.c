#include "cache.h"
#include "tag.h"
#include "commit.h"
#include "tree.h"
#include "blob.h"
#include "epoch.h"

#define SEEN		(1u << 0)
#define INTERESTING	(1u << 1)
#define COUNTED		(1u << 2)
#define SHOWN		(LAST_EPOCH_FLAG << 2)

static const char rev_list_usage[] =
	"usage: git-rev-list [OPTION] commit-id <commit-id>\n"
		      "  --max-count=nr\n"
		      "  --max-age=epoch\n"
		      "  --min-age=epoch\n"
		      "  --bisect\n"
		      "  --objects\n"
		      "  --unpacked\n"
		      "  --header\n"
		      "  --pretty\n"
		      "  --merge-order [ --show-breaks ]";

static int unpacked = 0;
static int bisect_list = 0;
static int tag_objects = 0;
static int tree_objects = 0;
static int blob_objects = 0;
static int verbose_header = 0;
static int show_parents = 0;
static int hdr_termination = 0;
static const char *prefix = "";
static unsigned long max_age = -1;
static unsigned long min_age = -1;
static int max_count = -1;
static enum cmit_fmt commit_format = CMIT_FMT_RAW;
static int merge_order = 0;
static int show_breaks = 0;
static int stop_traversal = 0;

static void show_commit(struct commit *commit)
{
	commit->object.flags |= SHOWN;
	if (show_breaks) {
		prefix = "| ";
		if (commit->object.flags & DISCONTINUITY) {
			prefix = "^ ";     
		} else if (commit->object.flags & BOUNDARY) {
			prefix = "= ";
		} 
        }        		
	printf("%s%s", prefix, sha1_to_hex(commit->object.sha1));
	if (show_parents) {
		struct commit_list *parents = commit->parents;
		while (parents) {
			printf(" %s", sha1_to_hex(parents->item->object.sha1));
			parents = parents->next;
		}
	}
	putchar('\n');
	if (verbose_header) {
		static char pretty_header[16384];
		pretty_print_commit(commit_format, commit->buffer, ~0, pretty_header, sizeof(pretty_header));
		printf("%s%c", pretty_header, hdr_termination);
	}
	fflush(stdout);
}

static int filter_commit(struct commit * commit)
{
	if (merge_order && stop_traversal && commit->object.flags & BOUNDARY)
		return STOP;
	if (commit->object.flags & (UNINTERESTING|SHOWN))
		return CONTINUE;
	if (min_age != -1 && (commit->date > min_age))
		return CONTINUE;
	if (max_age != -1 && (commit->date < max_age)) {
		if (!merge_order)
			return STOP;
		else {
			stop_traversal = 1;
			return CONTINUE;
		}
	}
	if (max_count != -1 && !max_count--)
		return STOP;
	return DO;
}

static int process_commit(struct commit * commit)
{
	int action=filter_commit(commit);

	if (action == STOP) {
		return STOP;
	}

	if (action == CONTINUE) {
		return CONTINUE;
	}

	show_commit(commit);

	return CONTINUE;
}

static struct object_list **add_object(struct object *obj, struct object_list **p, const char *name)
{
	struct object_list *entry = xmalloc(sizeof(*entry));
	entry->item = obj;
	entry->next = *p;
	entry->name = name;
	*p = entry;
	return &entry->next;
}

static struct object_list **process_blob(struct blob *blob, struct object_list **p, const char *name)
{
	struct object *obj = &blob->object;

	if (!blob_objects)
		return p;
	if (obj->flags & (UNINTERESTING | SEEN))
		return p;
	obj->flags |= SEEN;
	return add_object(obj, p, name);
}

static struct object_list **process_tree(struct tree *tree, struct object_list **p, const char *name)
{
	struct object *obj = &tree->object;
	struct tree_entry_list *entry;

	if (!tree_objects)
		return p;
	if (obj->flags & (UNINTERESTING | SEEN))
		return p;
	if (parse_tree(tree) < 0)
		die("bad tree object %s", sha1_to_hex(obj->sha1));
	obj->flags |= SEEN;
	p = add_object(obj, p, name);
	for (entry = tree->entries ; entry ; entry = entry->next) {
		if (entry->directory)
			p = process_tree(entry->item.tree, p, entry->name);
		else
			p = process_blob(entry->item.blob, p, entry->name);
	}
	return p;
}

static struct object_list *pending_objects = NULL;

static void show_commit_list(struct commit_list *list)
{
	struct object_list *objects = NULL, **p = &objects, *pending;
	while (list) {
		struct commit *commit = pop_most_recent_commit(&list, SEEN);

		p = process_tree(commit->tree, p, "");
		if (process_commit(commit) == STOP)
			break;
	}
	for (pending = pending_objects; pending; pending = pending->next) {
		struct object *obj = pending->item;
		const char *name = pending->name;
		if (obj->flags & (UNINTERESTING | SEEN))
			continue;
		if (obj->type == tag_type) {
			obj->flags |= SEEN;
			p = add_object(obj, p, name);
			continue;
		}
		if (obj->type == tree_type) {
			p = process_tree((struct tree *)obj, p, name);
			continue;
		}
		if (obj->type == blob_type) {
			p = process_blob((struct blob *)obj, p, name);
			continue;
		}
		die("unknown pending object %s (%s)", sha1_to_hex(obj->sha1), name);
	}
	while (objects) {
		printf("%s %s\n", sha1_to_hex(objects->item->sha1), objects->name);
		objects = objects->next;
	}
}

static void mark_blob_uninteresting(struct blob *blob)
{
	if (!blob_objects)
		return;
	if (blob->object.flags & UNINTERESTING)
		return;
	blob->object.flags |= UNINTERESTING;
}

static void mark_tree_uninteresting(struct tree *tree)
{
	struct object *obj = &tree->object;
	struct tree_entry_list *entry;

	if (!tree_objects)
		return;
	if (obj->flags & UNINTERESTING)
		return;
	obj->flags |= UNINTERESTING;
	if (parse_tree(tree) < 0)
		die("bad tree %s", sha1_to_hex(obj->sha1));
	entry = tree->entries;
	while (entry) {
		if (entry->directory)
			mark_tree_uninteresting(entry->item.tree);
		else
			mark_blob_uninteresting(entry->item.blob);
		entry = entry->next;
	}
}

static void mark_parents_uninteresting(struct commit *commit)
{
	struct commit_list *parents = commit->parents;

	if (tree_objects)
		mark_tree_uninteresting(commit->tree);
	while (parents) {
		struct commit *commit = parents->item;
		commit->object.flags |= UNINTERESTING;
		parents = parents->next;
	}
}

static int everybody_uninteresting(struct commit_list *list)
{
	while (list) {
		struct commit *commit = list->item;
		list = list->next;
		if (commit->object.flags & UNINTERESTING)
			continue;
		return 0;
	}
	return 1;
}

/*
 * This is a truly stupid algorithm, but it's only
 * used for bisection, and we just don't care enough.
 *
 * We care just barely enough to avoid recursing for
 * non-merge entries.
 */
static int count_distance(struct commit_list *entry)
{
	int nr = 0;

	while (entry) {
		struct commit *commit = entry->item;
		struct commit_list *p;

		if (commit->object.flags & (UNINTERESTING | COUNTED))
			break;
		nr++;
		commit->object.flags |= COUNTED;
		p = commit->parents;
		entry = p;
		if (p) {
			p = p->next;
			while (p) {
				nr += count_distance(p);
				p = p->next;
			}
		}
	}
	return nr;
}

static void clear_distance(struct commit_list *list)
{
	while (list) {
		struct commit *commit = list->item;
		commit->object.flags &= ~COUNTED;
		list = list->next;
	}
}

static struct commit_list *find_bisection(struct commit_list *list)
{
	int nr, closest;
	struct commit_list *p, *best;

	nr = 0;
	p = list;
	while (p) {
		nr++;
		p = p->next;
	}
	closest = 0;
	best = list;

	p = list;
	while (p) {
		int distance = count_distance(p);
		clear_distance(list);
		if (nr - distance < distance)
			distance = nr - distance;
		if (distance > closest) {
			best = p;
			closest = distance;
		}
		p = p->next;
	}
	if (best)
		best->next = NULL;
	return best;
}

static struct commit_list *limit_list(struct commit_list *list)
{
	struct commit_list *newlist = NULL;
	struct commit_list **p = &newlist;
	while (list) {
		struct commit *commit = pop_most_recent_commit(&list, SEEN);
		struct object *obj = &commit->object;

		if (unpacked && has_sha1_pack(obj->sha1))
			obj->flags |= UNINTERESTING;
		if (obj->flags & UNINTERESTING) {
			mark_parents_uninteresting(commit);
			if (everybody_uninteresting(list))
				break;
			continue;
		}
		p = &commit_list_insert(commit, p)->next;
	}
	if (bisect_list)
		newlist = find_bisection(newlist);
	return newlist;
}

static void add_pending_object(struct object *obj, const char *name)
{
	add_object(obj, &pending_objects, name);
}

static struct commit *get_commit_reference(const char *name, unsigned int flags)
{
	unsigned char sha1[20];
	struct object *object;

	if (get_sha1(name, sha1))
		usage(rev_list_usage);
	object = parse_object(sha1);
	if (!object)
		die("bad object %s", name);

	/*
	 * Tag object? Look what it points to..
	 */
	if (object->type == tag_type) {
		struct tag *tag = (struct tag *) object;
		object->flags |= flags;
		if (tag_objects && !(object->flags & UNINTERESTING))
			add_pending_object(object, tag->tag);
		object = tag->tagged;
	}

	/*
	 * Commit object? Just return it, we'll do all the complex
	 * reachability crud.
	 */
	if (object->type == commit_type) {
		struct commit *commit = (struct commit *)object;
		object->flags |= flags;
		if (parse_commit(commit) < 0)
			die("unable to parse commit %s", name);
		return commit;
	}

	/*
	 * Tree object? Either mark it uniniteresting, or add it
	 * to the list of objects to look at later..
	 */
	if (object->type == tree_type) {
		struct tree *tree = (struct tree *)object;
		if (!tree_objects)
			return NULL;
		if (flags & UNINTERESTING) {
			mark_tree_uninteresting(tree);
			return NULL;
		}
		add_pending_object(object, "");
		return NULL;
	}

	/*
	 * Blob object? You know the drill by now..
	 */
	if (object->type == blob_type) {
		struct blob *blob = (struct blob *)object;
		if (!blob_objects)
			return NULL;
		if (flags & UNINTERESTING) {
			mark_blob_uninteresting(blob);
			return NULL;
		}
		add_pending_object(object, "");
		return NULL;
	}
	die("%s is unknown object", name);
}

int main(int argc, char **argv)
{
	struct commit_list *list = NULL;
	int i, limited = 0;

	for (i = 1 ; i < argc; i++) {
		int flags;
		char *arg = argv[i];
		struct commit *commit;

		if (!strncmp(arg, "--max-count=", 12)) {
			max_count = atoi(arg + 12);
			continue;
		}
		if (!strncmp(arg, "--max-age=", 10)) {
			max_age = atoi(arg + 10);
			continue;
		}
		if (!strncmp(arg, "--min-age=", 10)) {
			min_age = atoi(arg + 10);
			continue;
		}
		if (!strcmp(arg, "--header")) {
			verbose_header = 1;
			continue;
		}
		if (!strncmp(arg, "--pretty", 8)) {
			commit_format = get_commit_format(arg+8);
			verbose_header = 1;
			hdr_termination = '\n';
			prefix = "commit ";
			continue;
		}
		if (!strcmp(arg, "--parents")) {
			show_parents = 1;
			continue;
		}
		if (!strcmp(arg, "--bisect")) {
			bisect_list = 1;
			continue;
		}
		if (!strcmp(arg, "--objects")) {
			tag_objects = 1;
			tree_objects = 1;
			blob_objects = 1;
			continue;
		}
		if (!strcmp(arg, "--unpacked")) {
			unpacked = 1;
			limited = 1;
			continue;
		}
		if (!strncmp(arg, "--merge-order", 13)) {
		        merge_order = 1;
			continue;
		}
		if (!strncmp(arg, "--show-breaks", 13)) {
			show_breaks = 1;
			continue;
		}

		flags = 0;
		if (*arg == '^') {
			flags = UNINTERESTING;
			arg++;
			limited = 1;
		}
		if (show_breaks && !merge_order)
			usage(rev_list_usage);
		commit = get_commit_reference(arg, flags);
		if (!commit)
			continue;
		insert_by_date(&list, commit);
	}

	if (!merge_order) {		
	        if (limited)
			list = limit_list(list);
		show_commit_list(list);
	} else {
		if (sort_list_in_merge_order(list, &process_commit)) {
			  die("merge order sort failed\n");
		}
	}

	return 0;
}
