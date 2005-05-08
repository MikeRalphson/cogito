#include <sys/types.h>
#include <sys/wait.h>

#include "cache.h"

static const char *pgm = NULL;
static const char *arguments[8];
static int err;

static void run_program(void)
{
	int pid = fork(), status;

	if (pid < 0)
		die("unable to fork");
	if (!pid) {
		execlp(pgm, arguments[0],
			    arguments[1],
			    arguments[2],
			    arguments[3],
			    arguments[4],
			    arguments[5],
			    arguments[6],
			    arguments[7],
			    NULL);
		die("unable to execute '%s'", pgm);
	}
	if (waitpid(pid, &status, 0) < 0 || !WIFEXITED(status) || WEXITSTATUS(status))
		err++;
}

static int merge_entry(int pos, const char *path)
{
	int found;
	
	if (pos >= active_nr)
		die("merge-cache: %s not in the cache", path);
	arguments[0] = pgm;
	arguments[1] = "";
	arguments[2] = "";
	arguments[3] = "";
	arguments[4] = path;
	arguments[5] = "";
	arguments[6] = "";
	arguments[7] = "";
	found = 0;
	do {
		static char hexbuf[4][60];
		static char ownbuf[4][60];
		struct cache_entry *ce = active_cache[pos];
		int stage = ce_stage(ce);

		if (strcmp(ce->name, path))
			break;
		found++;
		strcpy(hexbuf[stage], sha1_to_hex(ce->sha1));
		sprintf(ownbuf[stage], "%o", ntohl(ce->ce_mode) & (~S_IFMT));
		arguments[stage] = hexbuf[stage];
		arguments[stage + 4] = ownbuf[stage];
	} while (++pos < active_nr);
	if (!found)
		die("merge-cache: %s not in the cache", path);
	run_program();
	return found;
}

static void merge_file(const char *path)
{
	int pos = cache_name_pos(path, strlen(path));

	/*
	 * If it already exists in the cache as stage0, it's
	 * already merged and there is nothing to do.
	 */
	if (pos < 0)
		merge_entry(-pos-1, path);
}

static void merge_all(void)
{
	int i;
	for (i = 0; i < active_nr; i++) {
		struct cache_entry *ce = active_cache[i];
		if (!ce_stage(ce))
			continue;
		i += merge_entry(i, ce->name)-1;
	}
}

int main(int argc, char **argv)
{
	int i, force_file = 0;

	if (argc < 3)
		usage("merge-cache <merge-program> (-a | <filename>*)");

	read_cache();

	pgm = argv[1];
	for (i = 2; i < argc; i++) {
		char *arg = argv[i];
		if (!force_file && *arg == '-') {
			if (!strcmp(arg, "--")) {
				force_file = 1;
				continue;
			}
			if (!strcmp(arg, "-a")) {
				merge_all();
				continue;
			}
			die("merge-cache: unknown option %s", arg);
		}
		merge_file(arg);
	}
	if (err)
		die("merge program failed");
	return 0;
}
