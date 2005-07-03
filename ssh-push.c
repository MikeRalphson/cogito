#include "cache.h"
#include "rsh.h"
#include "refs.h"

#include <string.h>

static unsigned char local_version = 1;
static unsigned char remote_version = 0;

static int serve_object(int fd_in, int fd_out) {
	ssize_t size;
	int posn = 0;
	unsigned char sha1[20];
	unsigned long objsize;
	void *buf;
	signed char remote;
	do {
		size = read(fd_in, sha1 + posn, 20 - posn);
		if (size < 0) {
			perror("git-ssh-push: read ");
			return -1;
		}
		if (!size)
			return -1;
		posn += size;
	} while (posn < 20);
	
	/* fprintf(stderr, "Serving %s\n", sha1_to_hex(sha1)); */
	remote = 0;
	
	buf = map_sha1_file(sha1, &objsize);
	
	if (!buf) {
		fprintf(stderr, "git-ssh-push: could not find %s\n", 
			sha1_to_hex(sha1));
		remote = -1;
	}
	
	write(fd_out, &remote, 1);
	
	if (remote < 0)
		return 0;
	
	posn = 0;
	do {
		size = write(fd_out, buf + posn, objsize - posn);
		if (size <= 0) {
			if (!size) {
				fprintf(stderr, "git-ssh-push: write closed");
			} else {
				perror("git-ssh-push: write ");
			}
			return -1;
		}
		posn += size;
	} while (posn < objsize);
	return 0;
}

static int serve_version(int fd_in, int fd_out)
{
	if (read(fd_in, &remote_version, 1) < 1)
		return -1;
	write(fd_out, &local_version, 1);
	return 0;
}

static int serve_ref(int fd_in, int fd_out)
{
	char ref[PATH_MAX];
	unsigned char sha1[20];
	int posn = 0;
	signed char remote = 0;
	do {
		if (read(fd_in, ref + posn, 1) < 1)
			return -1;
		posn++;
	} while (ref[posn - 1]);
	if (get_ref_sha1(ref, sha1))
		remote = -1;
	write(fd_out, &remote, 1);
	if (remote)
		return 0;
	write(fd_out, sha1, 20);
        return 0;
}


static void service(int fd_in, int fd_out) {
	char type;
	int retval;
	do {
		retval = read(fd_in, &type, 1);
		if (retval < 1) {
			if (retval < 0)
				perror("git-ssh-push: read ");
			return;
		}
		if (type == 'v' && serve_version(fd_in, fd_out))
			return;
		if (type == 'o' && serve_object(fd_in, fd_out))
			return;
		if (type == 'r' && serve_ref(fd_in, fd_out))
			return;
	} while (1);
}

static const char *ssh_push_usage =
	"git-ssh-push [-c] [-t] [-a] [-w ref] commit-id url";

int main(int argc, char **argv)
{
	int arg = 1;
        char *commit_id;
        char *url;
	int fd_in, fd_out;
	const char *prog = getenv("GIT_SSH_PULL") ? : "git-ssh-pull";
	unsigned char sha1[20];
	char hex[41];

	while (arg < argc && argv[arg][0] == '-') {
		if (argv[arg][1] == 'w')
			arg++;
                arg++;
        }
	if (argc < arg + 2)
		usage(ssh_push_usage);
	commit_id = argv[arg];
	url = argv[arg + 1];
	if (get_sha1(commit_id, sha1))
		usage(ssh_push_usage);
	memcpy(hex, sha1_to_hex(sha1), sizeof(hex));
	argv[arg] = hex;

	if (setup_connection(&fd_in, &fd_out, prog, url, arg, argv + 1))
		return 1;

	service(fd_in, fd_out);
	return 0;
}
