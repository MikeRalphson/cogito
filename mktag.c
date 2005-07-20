#include "cache.h"

/*
 * A signature file has a very simple fixed format: three lines
 * of "object <sha1>" + "type <typename>" + "tag <tagname>",
 * followed by some free-form signature that git itself doesn't
 * care about, but that can be verified with gpg or similar.
 *
 * The first three lines are guaranteed to be at least 63 bytes:
 * "object <sha1>\n" is 48 bytes, "type tag\n" at 9 bytes is the
 * shortest possible type-line, and "tag .\n" at 6 bytes is the
 * shortest single-character-tag line. 
 *
 * We also artificially limit the size of the full object to 8kB.
 * Just because I'm a lazy bastard, and if you can't fit a signature
 * in that size, you're doing something wrong.
 */

// Some random size
#define MAXSIZE (8192)

/*
 * We refuse to tag something we can't verify. Just because.
 */
static int verify_object(unsigned char *sha1, const char *expected_type)
{
	int ret = -1;
	char type[100];
	unsigned long size;
	void *buffer = read_sha1_file(sha1, type, &size);

	if (buffer) {
		if (!strcmp(type, expected_type))
			ret = check_sha1_signature(sha1, buffer, size, type);
		free(buffer);
	}
	return ret;
}

static int verify_tag(char *buffer, unsigned long size)
{
	int typelen;
	char type[20];
	unsigned char sha1[20];
	const char *object, *type_line, *tag_line, *tagger_line;

	if (size < 64 || size > MAXSIZE-1)
		return -1;
	buffer[size] = 0;

	/* Verify object line */
	object = buffer;
	if (memcmp(object, "object ", 7))
		return -1;
	if (get_sha1_hex(object + 7, sha1))
		return -1;

	/* Verify type line */
	type_line = object + 48;
	if (memcmp(type_line - 1, "\ntype ", 6))
		return -1;

	/* Verify tag-line */
	tag_line = strchr(type_line, '\n');
	if (!tag_line)
		return -1;
	tag_line++;
	if (memcmp(tag_line, "tag ", 4) || tag_line[4] == '\n')
		return -1;

	/* Get the actual type */
	typelen = tag_line - type_line - strlen("type \n");
	if (typelen >= sizeof(type))
		return -1;
	memcpy(type, type_line+5, typelen);
	type[typelen] = 0;

	/* Verify that the object matches */
	if (get_sha1_hex(object + 7, sha1))
		return -1;
	if (verify_object(sha1, type))
		return -1;

	/* Verify the tag-name: we don't allow control characters or spaces in it */
	tag_line += 4;
	for (;;) {
		unsigned char c = *tag_line++;
		if (c == '\n')
			break;
		if (c > ' ')
			continue;
		return -1;
	}

	/* Verify the tagger line */
	tagger_line = tag_line;

	if (memcmp(tagger_line, "tagger", 6) || (tagger_line[6] == '\n'))
		return -1;

	/* The actual stuff afterwards we don't care about.. */
	return 0;
}

int main(int argc, char **argv)
{
	unsigned long size;
	char buffer[MAXSIZE];
	unsigned char result_sha1[20];

	if (argc != 1)
		usage("cat <signaturefile> | git-mktag");

	// Read the signature
	size = 0;
	for (;;) {
		int ret = read(0, buffer + size, MAXSIZE - size);
		if (!ret)
			break;
		if (ret < 0) {
			if (errno == EAGAIN)
				continue;
			break;
		}
		size += ret;
	}

	// Verify it for some basic sanity: it needs to start with "object <sha1>\ntype\ntagger "
	if (verify_tag(buffer, size) < 0)
		die("invalid tag signature file");

	if (write_sha1_file(buffer, size, "tag", result_sha1) < 0)
		die("unable to write tag file");
	printf("%s\n", sha1_to_hex(result_sha1));
	return 0;
}
