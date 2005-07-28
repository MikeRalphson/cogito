#include "cache.h"

static const char prune_packed_usage[] = "git-prune-packed (no arguments)";

static void prune_dir(int i, DIR *dir, char *pathname, int len)
{
	struct dirent *de;
	char hex[40];

	sprintf(hex, "%02x", i);
	while ((de = readdir(dir)) != NULL) {
		unsigned char sha1[20];
		if (strlen(de->d_name) != 38)
			continue;
		memcpy(hex+2, de->d_name, 38);
		if (get_sha1_hex(hex, sha1))
			continue;
		if (!has_sha1_pack(sha1))
			continue;
		memcpy(pathname + len, de->d_name, 38);
		if (unlink(pathname) < 0)
			error("unable to unlink %s", pathname);
	}
}

static void prune_packed_objects(void)
{
	int i;
	static char pathname[PATH_MAX];
	const char *dir = get_object_directory();
	int len = strlen(dir);

	if (len > PATH_MAX - 42)
		die("impossible object directory");
	memcpy(pathname, dir, len);
	if (len && pathname[len-1] != '/')
		pathname[len++] = '/';
	for (i = 0; i < 256; i++) {
		DIR *d;

		sprintf(pathname + len, "%02x/", i);
		d = opendir(pathname);
		if (!d)
			die("unable to open %s", pathname);
		prune_dir(i, d, pathname, len + 3);
		closedir(d);
	}
}

int main(int argc, char **argv)
{
	int i;

	for (i = 1; i < argc; i++) {
		const char *arg = argv[i];

		if (*arg == '-') {
			/* Handle flags here .. */
			usage(prune_packed_usage);
		}
		/* Handle arguments here .. */
		usage(prune_packed_usage);
	}
	prune_packed_objects();
	return 0;
}
