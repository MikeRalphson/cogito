#include <ctype.h>
#include "cache.h"

static void flush_current_id(int patchlen, unsigned char *id, SHA_CTX *c)
{
	unsigned char result[20];
	char name[50];

	if (!patchlen)
		return;

	SHA1_Final(result, c);
	memcpy(name, sha1_to_hex(id), 41);
	printf("%s %s\n", sha1_to_hex(result), name);
	SHA1_Init(c);
}

static int remove_space(char *line)
{
	char *src = line;
	char *dst = line;
	unsigned char c;

	while ((c = *src++) != '\0') {
		if (!isspace(c))
			*dst++ = c;
	}
	return dst - line;
}

static void generate_id_list(void)
{
	static unsigned char sha1[20];
	static char line[1000];
	SHA_CTX ctx;
	int patchlen = 0;

	SHA1_Init(&ctx);
	while (fgets(line, sizeof(line), stdin) != NULL) {
		unsigned char n[20];
		char *p = line;
		int len;

		if (!memcmp(line, "diff-tree ", 10))
			p += 10;

		if (!get_sha1_hex(p, n)) {
			flush_current_id(patchlen, sha1, &ctx);
			memcpy(sha1, n, 20);
			patchlen = 0;
			continue;
		}

		/* Ignore commit comments */
		if (!patchlen && memcmp(line, "diff ", 5))
			continue;

		/* Ignore line numbers when computing the SHA1 of the patch */
		if (!memcmp(line, "@@ -", 4))
			continue;

		/* Compute the sha without whitespace */
		len = remove_space(line);
		patchlen += len;
		SHA1_Update(&ctx, line, len);
	}
	flush_current_id(patchlen, sha1, &ctx);
}

static const char patch_id_usage[] = "usage: git-patch-id < patch";

int main(int argc, char **argv)
{
	if (argc != 1)
		usage(patch_id_usage);

	generate_id_list();
	return 0;
}	
