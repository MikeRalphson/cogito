#include "cache.h"
#include "commit.h"

static const char rev_list_usage[] =
	"usage: git-rev-list [OPTION] commit-id <commit-id>\n"
		      "  --max-count=nr\n"
		      "  --max-age=epoch\n"
		      "  --min-age=epoch\n"
		      "  --header";

int main(int argc, char **argv)
{
	int nr_sha;
	unsigned char sha1[2][20];
	struct commit_list *list = NULL;
	struct commit *commit, *end;
	int i, verbose_header = 0;
	unsigned long max_age = -1;
	unsigned long min_age = -1;
	int max_count = -1;

	nr_sha = 0;
	for (i = 1 ; i < argc; i++) {
		char *arg = argv[i];

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

		if (nr_sha > 2 || get_sha1(arg, sha1[nr_sha]))
			usage(rev_list_usage);
		nr_sha++;
	}

	if (!nr_sha)
		usage(rev_list_usage);

	commit = lookup_commit_reference(sha1[0]);
	if (!commit || parse_commit(commit) < 0)
		die("bad starting commit object");

	end = NULL;
	if (nr_sha > 1) {
		end = lookup_commit_reference(sha1[1]);
		if (!end || parse_commit(end) < 0)
			die("bad ending commit object");
	}

	commit_list_insert(commit, &list);
	do {
		struct commit *commit = pop_most_recent_commit(&list, 0x1);

		if (commit == end)
			break;
		if (min_age != -1 && (commit->date > min_age))
			continue;
		if (max_age != -1 && (commit->date < max_age))
			break;
		if (max_count != -1 && !max_count--)
			break;
		printf("%s\n", sha1_to_hex(commit->object.sha1));
		if (verbose_header)
			printf("%s%c", commit->buffer, 0);
	} while (list);
	return 0;
}
