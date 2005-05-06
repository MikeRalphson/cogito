#define _XOPEN_SOURCE /* glibc2 needs this */
#include <time.h>
#include <ctype.h>
#include "cache.h"

struct entry {
	unsigned char old_sha1[20];
	unsigned char new_sha1[20];
	int converted;
};

#define MAXOBJECTS (1000000)

static struct entry *convert[MAXOBJECTS];
static int nr_convert;

static struct entry * convert_entry(unsigned char *sha1);

static struct entry *insert_new(unsigned char *sha1, int pos)
{
	struct entry *new = xmalloc(sizeof(struct entry));
	memset(new, 0, sizeof(*new));
	memcpy(new->old_sha1, sha1, 20);
	memmove(convert + pos + 1, convert + pos, (nr_convert - pos) * sizeof(struct entry *));
	convert[pos] = new;
	nr_convert++;
	if (nr_convert == MAXOBJECTS)
		die("you're kidding me - hit maximum object limit");
	return new;
}

static struct entry *lookup_entry(unsigned char *sha1)
{
	int low = 0, high = nr_convert;

	while (low < high) {
		int next = (low + high) / 2;
		struct entry *n = convert[next];
		int cmp = memcmp(sha1, n->old_sha1, 20);
		if (!cmp)
			return n;
		if (cmp < 0) {
			high = next;
			continue;
		}
		low = next+1;
	}
	return insert_new(sha1, low);
}

static void convert_binary_sha1(void *buffer)
{
	struct entry *entry = convert_entry(buffer);
	memcpy(buffer, entry->new_sha1, 20);
}

static void convert_ascii_sha1(void *buffer)
{
	unsigned char sha1[20];
	struct entry *entry;

	if (get_sha1_hex(buffer, sha1))
		die("bad sha1");
	entry = convert_entry(sha1);
	memcpy(buffer, sha1_to_hex(entry->new_sha1), 40);
}

static int write_subdirectory(void *buffer, unsigned long size, const char *base, int baselen, unsigned char *result_sha1)
{
	char *new = xmalloc(size);
	unsigned long newlen = 0;
	unsigned long used;

	used = 0;
	while (size) {
		int len = 21 + strlen(buffer);
		char *path = strchr(buffer, ' ');
		unsigned char *sha1;
		unsigned int mode;
		char *slash, *origpath;

		if (!path || sscanf(buffer, "%o", &mode) != 1)
			die("bad tree conversion");
		path++;
		if (memcmp(path, base, baselen))
			break;
		origpath = path;
		path += baselen;
		slash = strchr(path, '/');
		if (!slash) {
			newlen += sprintf(new + newlen, "%o %s", mode, path);
			new[newlen++] = '\0';
			memcpy(new + newlen, buffer + len - 20, 20);
			newlen += 20;

			used += len;
			size -= len;
			buffer += len;
			continue;
		}

		newlen += sprintf(new + newlen, "%o %.*s", S_IFDIR, (int)(slash - path), path);
		new[newlen++] = 0;
		sha1 = (unsigned char *)(new + newlen);
		newlen += 20;

		len = write_subdirectory(buffer, size, origpath, slash-origpath+1, sha1);

		used += len;
		size -= len;
		buffer += len;
	}

	write_sha1_file(new, newlen, "tree", result_sha1);
	free(new);
	return used;
}

static void convert_tree(void *buffer, unsigned long size, unsigned char *result_sha1)
{
	void *orig_buffer = buffer;
	unsigned long orig_size = size;

	while (size) {
		int len = 1+strlen(buffer);

		convert_binary_sha1(buffer + len);

		len += 20;
		if (len > size)
			die("corrupt tree object");
		size -= len;
		buffer += len;
	}

	write_subdirectory(orig_buffer, orig_size, "", 0, result_sha1);
}

static unsigned long parse_oldstyle_date(const char *buf)
{
	char c, *p;
	char buffer[100];
	struct tm tm;
	const char *formats[] = {
		"%c",
		"%a %b %d %T",
		"%Z",
		"%Y",
		" %Y",
		NULL
	};
	/* We only ever did two timezones in the bad old format .. */
	const char *timezones[] = {
		"PDT", "PST", "CEST", NULL
	};
	const char **fmt = formats;

	p = buffer;
	while (isspace(c = *buf))
		buf++;
	while ((c = *buf++) != '\n')
		*p++ = c;
	*p++ = 0;
	buf = buffer;
	memset(&tm, 0, sizeof(tm));
	do {
		const char *next = strptime(buf, *fmt, &tm);
		if (next) {
			if (!*next)
				return mktime(&tm);
			buf = next;
		} else {
			const char **p = timezones;
			while (isspace(*buf))
				buf++;
			while (*p) {
				if (!memcmp(buf, *p, strlen(*p))) {
					buf += strlen(*p);
					break;
				}
				p++;
			}
		}
		fmt++;
	} while (*buf && *fmt);
	printf("left: %s\n", buf);
	return mktime(&tm);				
}

static int convert_date_line(char *dst, void **buf, unsigned long *sp)
{
	unsigned long size = *sp;
	char *line = *buf;
	char *next = strchr(line, '\n');
	char *date = strchr(line, '>');
	int len;

	if (!next || !date)
		die("missing or bad author/committer line %s", line);
	next++; date += 2;

	*buf = next;
	*sp = size - (next - line);

	len = date - line;
	memcpy(dst, line, len);
	dst += len;

	/* Is it already in new format? */
	if (isdigit(*date)) {
		int datelen = next - date;
		memcpy(dst, date, datelen);
		return len + datelen;
	}

	/*
	 * Hacky hacky: one of the sparse old-style commits does not have
	 * any date at all, but we can fake it by using the committer date.
	 */
	if (*date == '\n' && strchr(next, '>'))
		date = strchr(next, '>')+2;

	return len + sprintf(dst, "%lu -0700\n", parse_oldstyle_date(date));
}

static void convert_date(void *buffer, unsigned long size, unsigned char *result_sha1)
{
	char *new = xmalloc(size + 100);
	unsigned long newlen = 0;
	
	// "tree <sha1>\n"
	memcpy(new + newlen, buffer, 46);
	newlen += 46;
	buffer += 46;
	size -= 46;

	// "parent <sha1>\n"
	while (!memcmp(buffer, "parent ", 7)) {
		memcpy(new + newlen, buffer, 48);
		newlen += 48;
		buffer += 48;
		size -= 48;
	}

	// "author xyz <xyz> date"
	newlen += convert_date_line(new + newlen, &buffer, &size);
	// "committer xyz <xyz> date"
	newlen += convert_date_line(new + newlen, &buffer, &size);

	// Rest
	memcpy(new + newlen, buffer, size);
	newlen += size;

	write_sha1_file(new, newlen, "commit", result_sha1);
	free(new);	
}

static void convert_commit(void *buffer, unsigned long size, unsigned char *result_sha1)
{
	void *orig_buffer = buffer;
	unsigned long orig_size = size;

	convert_ascii_sha1(buffer+5);
	buffer += 46;    /* "tree " + "hex sha1" + "\n" */
	while (!memcmp(buffer, "parent ", 7)) {
		convert_ascii_sha1(buffer+7);
		buffer += 48;
	}
	convert_date(orig_buffer, orig_size, result_sha1);
}

static struct entry * convert_entry(unsigned char *sha1)
{
	struct entry *entry = lookup_entry(sha1);
	char type[20];
	void *buffer, *data;
	unsigned long size;

	if (entry->converted)
		return entry;
	data = read_sha1_file(sha1, type, &size);
	if (!data)
		die("unable to read object %s", sha1_to_hex(sha1));

	buffer = xmalloc(size);
	memcpy(buffer, data, size);
	
	if (!strcmp(type, "blob")) {
		write_sha1_file(buffer, size, "blob", entry->new_sha1);
	} else if (!strcmp(type, "tree"))
		convert_tree(buffer, size, entry->new_sha1);
	else if (!strcmp(type, "commit"))
		convert_commit(buffer, size, entry->new_sha1);
	else
		die("unknown object type '%s' in %s", type, sha1_to_hex(sha1));
	entry->converted = 1;
	free(buffer);
	return entry;
}

int main(int argc, char **argv)
{
	unsigned char sha1[20];
	struct entry *entry;

	if (argc != 2 || get_sha1(argv[1], sha1))
		usage("convert-cache <sha1>");

	entry = convert_entry(sha1);
	printf("new sha1: %s\n", sha1_to_hex(entry->new_sha1));
	return 0;
}
