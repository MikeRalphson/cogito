#include "cache.h"
#include "refs.h"
#include "pkt-line.h"
#include <sys/wait.h>

static const char peek_remote_usage[] =
"git-peek-remote [--exec=upload-pack] [host:]directory";
static const char *exec = "git-upload-pack";

static int peek_remote(int fd[2])
{
	struct ref *ref;

	get_remote_heads(fd[0], &ref, 0, NULL);
	packet_flush(fd[1]);

	while (ref) {
		printf("%s	%s\n", sha1_to_hex(ref->old_sha1), ref->name);
		ref = ref->next;
	}
	return 0;
}

int main(int argc, char **argv)
{
	int i, ret;
	char *dest = NULL;
	int fd[2];
	pid_t pid;

	for (i = 1; i < argc; i++) {
		char *arg = argv[i];

		if (*arg == '-') {
			if (!strncmp("--exec=", arg, 7))
				exec = arg + 7;
			else
				usage(peek_remote_usage);
			continue;
		}
		dest = arg;
		break;
	}
	if (!dest || i != argc - 1)
		usage(peek_remote_usage);

	pid = git_connect(fd, dest, exec);
	if (pid < 0)
		return 1;
	ret = peek_remote(fd);
	close(fd[0]);
	close(fd[1]);
	finish_connect(pid);
	return ret;
}
