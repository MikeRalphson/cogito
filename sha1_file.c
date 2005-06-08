/*
 * GIT - The information manager from hell
 *
 * Copyright (C) Linus Torvalds, 2005
 *
 * This handles basic git sha1 object files - packing, unpacking,
 * creation etc.
 */
#include "cache.h"
#include "delta.h"

#ifndef O_NOATIME
#if defined(__linux__) && (defined(__i386__) || defined(__PPC__))
#define O_NOATIME 01000000
#else
#define O_NOATIME 0
#endif
#endif

static unsigned int sha1_file_open_flag = O_NOATIME;

static unsigned hexval(char c)
{
	if (c >= '0' && c <= '9')
		return c - '0';
	if (c >= 'a' && c <= 'f')
		return c - 'a' + 10;
	if (c >= 'A' && c <= 'F')
		return c - 'A' + 10;
	return ~0;
}

int get_sha1_hex(const char *hex, unsigned char *sha1)
{
	int i;
	for (i = 0; i < 20; i++) {
		unsigned int val = (hexval(hex[0]) << 4) | hexval(hex[1]);
		if (val & ~0xff)
			return -1;
		*sha1++ = val;
		hex += 2;
	}
	return 0;
}

static int get_sha1_file(const char *path, unsigned char *result)
{
	char buffer[60];
	int fd = open(path, O_RDONLY);
	int len;

	if (fd < 0)
		return -1;
	len = read(fd, buffer, sizeof(buffer));
	close(fd);
	if (len < 40)
		return -1;
	return get_sha1_hex(buffer, result);
}

static char *git_dir, *git_object_dir, *git_index_file, *git_refs_dir;
static void setup_git_env(void)
{
	git_dir = gitenv(GIT_DIR_ENVIRONMENT);
	if (!git_dir)
		git_dir = DEFAULT_GIT_DIR_ENVIRONMENT;
	git_object_dir = gitenv(DB_ENVIRONMENT);
	if (!git_object_dir) {
		git_object_dir = xmalloc(strlen(git_dir) + 9);
		sprintf(git_object_dir, "%s/objects", git_dir);
	}
	git_refs_dir = xmalloc(strlen(git_dir) + 6);
	sprintf(git_refs_dir, "%s/refs", git_dir);
	git_index_file = gitenv(INDEX_ENVIRONMENT);
	if (!git_index_file) {
		git_index_file = xmalloc(strlen(git_dir) + 7);
		sprintf(git_index_file, "%s/index", git_dir);
	}
}

char *get_object_directory(void)
{
	if (!git_object_dir)
		setup_git_env();
	return git_object_dir;
}

char *get_refs_directory(void)
{
	if (!git_refs_dir)
		setup_git_env();
	return git_refs_dir;
}

char *get_index_file(void)
{
	if (!git_index_file)
		setup_git_env();
	return git_index_file;
}

int get_sha1(const char *str, unsigned char *sha1)
{
	static char pathname[PATH_MAX];
	static const char *prefix[] = {
		"",
		"refs",
		"refs/tags",
		"refs/heads",
		"refs/snap",
		NULL
	};
	const char **p;

	if (!get_sha1_hex(str, sha1))
		return 0;

	if (!git_dir)
		setup_git_env();
	for (p = prefix; *p; p++) {
		snprintf(pathname, sizeof(pathname), "%s/%s/%s",
			 git_dir, *p, str);
		if (!get_sha1_file(pathname, sha1))
			return 0;
	}

	return -1;
}

char * sha1_to_hex(const unsigned char *sha1)
{
	static char buffer[50];
	static const char hex[] = "0123456789abcdef";
	char *buf = buffer;
	int i;

	for (i = 0; i < 20; i++) {
		unsigned int val = *sha1++;
		*buf++ = hex[val >> 4];
		*buf++ = hex[val & 0xf];
	}
	return buffer;
}

static void fill_sha1_path(char *pathbuf, const unsigned char *sha1)
{
	int i;
	for (i = 0; i < 20; i++) {
		static char hex[] = "0123456789abcdef";
		unsigned int val = sha1[i];
		char *pos = pathbuf + i*2 + (i > 0);
		*pos++ = hex[val >> 4];
		*pos = hex[val & 0xf];
	}
}

/*
 * NOTE! This returns a statically allocated buffer, so you have to be
 * careful about using it. Do a "strdup()" if you need to save the
 * filename.
 *
 * Also note that this returns the location for creating.  Reading
 * SHA1 file can happen from any alternate directory listed in the
 * DB_ENVIRONMENT environment variable if it is not found in
 * the primary object database.
 */
char *sha1_file_name(const unsigned char *sha1)
{
	static char *name, *base;

	if (!base) {
		const char *sha1_file_directory = get_object_directory();
		int len = strlen(sha1_file_directory);
		base = xmalloc(len + 60);
		memcpy(base, sha1_file_directory, len);
		memset(base+len, 0, 60);
		base[len] = '/';
		base[len+3] = '/';
		name = base + len + 1;
	}
	fill_sha1_path(name, sha1);
	return base;
}

static struct alternate_object_database {
	char *base;
	char *name;
} *alt_odb;

/*
 * Prepare alternate object database registry.
 * alt_odb points at an array of struct alternate_object_database.
 * This array is terminated with an element that has both its base
 * and name set to NULL.  alt_odb[n] comes from n'th non-empty
 * element from colon separated ALTERNATE_DB_ENVIRONMENT environment
 * variable, and its base points at a statically allocated buffer
 * that contains "/the/directory/corresponding/to/.git/objects/...",
 * while its name points just after the slash at the end of
 * ".git/objects/" in the example above, and has enough space to hold
 * 40-byte hex SHA1, an extra slash for the first level indirection,
 * and the terminating NUL.
 * This function allocates the alt_odb array and all the strings
 * pointed by base fields of the array elements with one xmalloc();
 * the string pool immediately follows the array.
 */
static void prepare_alt_odb(void)
{
	int pass, totlen, i;
	const char *cp, *last;
	char *op = NULL;
	const char *alt = gitenv(ALTERNATE_DB_ENVIRONMENT) ? : "";

	/* The first pass counts how large an area to allocate to
	 * hold the entire alt_odb structure, including array of
	 * structs and path buffers for them.  The second pass fills
	 * the structure and prepares the path buffers for use by
	 * fill_sha1_path().
	 */
	for (totlen = pass = 0; pass < 2; pass++) {
		last = alt;
		i = 0;
		do {
			cp = strchr(last, ':') ? : last + strlen(last);
			if (last != cp) {
				/* 43 = 40-byte + 2 '/' + terminating NUL */
				int pfxlen = cp - last;
				int entlen = pfxlen + 43;
				if (pass == 0)
					totlen += entlen;
				else {
					alt_odb[i].base = op;
					alt_odb[i].name = op + pfxlen + 1;
					memcpy(op, last, pfxlen);
					op[pfxlen] = op[pfxlen + 3] = '/';
					op[entlen-1] = 0;
					op += entlen;
				}
				i++;
			}
			while (*cp && *cp == ':')
				cp++;
			last = cp;
		} while (*cp);
		if (pass)
			break;
		alt_odb = xmalloc(sizeof(*alt_odb) * (i + 1) + totlen);
		alt_odb[i].base = alt_odb[i].name = NULL;
		op = (char*)(&alt_odb[i+1]);
	}
}

static char *find_sha1_file(const unsigned char *sha1, struct stat *st)
{
	int i;
	char *name = sha1_file_name(sha1);

	if (!stat(name, st))
		return name;
	if (!alt_odb)
		prepare_alt_odb();
	for (i = 0; (name = alt_odb[i].name) != NULL; i++) {
		fill_sha1_path(name, sha1);
		if (!stat(alt_odb[i].base, st))
			return alt_odb[i].base;
	}
	return NULL;
}

int check_sha1_signature(unsigned char *sha1, void *map, unsigned long size, const char *type)
{
	char header[100];
	unsigned char real_sha1[20];
	SHA_CTX c;

	SHA1_Init(&c);
	SHA1_Update(&c, header, 1+sprintf(header, "%s %lu", type, size));
	SHA1_Update(&c, map, size);
	SHA1_Final(real_sha1, &c);
	return memcmp(sha1, real_sha1, 20) ? -1 : 0;
}

void *map_sha1_file(const unsigned char *sha1, unsigned long *size)
{
	struct stat st;
	void *map;
	int fd;
	char *filename = find_sha1_file(sha1, &st);

	if (!filename) {
		error("cannot map sha1 file %s", sha1_to_hex(sha1));
		return NULL;
	}

	fd = open(filename, O_RDONLY | sha1_file_open_flag);
	if (fd < 0) {
		/* See if it works without O_NOATIME */
		switch (sha1_file_open_flag) {
		default:
			fd = open(filename, O_RDONLY);
			if (fd >= 0)
				break;
		/* Fallthrough */
		case 0:
			perror(filename);
			return NULL;
		}

		/* If it failed once, it will probably fail again. Stop using O_NOATIME */
		sha1_file_open_flag = 0;
	}
	map = mmap(NULL, st.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
	close(fd);
	if (-1 == (int)(long)map)
		return NULL;
	*size = st.st_size;
	return map;
}

int unpack_sha1_header(z_stream *stream, void *map, unsigned long mapsize, void *buffer, unsigned long size)
{
	/* Get the data stream */
	memset(stream, 0, sizeof(*stream));
	stream->next_in = map;
	stream->avail_in = mapsize;
	stream->next_out = buffer;
	stream->avail_out = size;

	inflateInit(stream);
	return inflate(stream, 0);
}

void *unpack_sha1_rest(z_stream *stream, void *buffer, unsigned long size)
{
	int bytes = strlen(buffer) + 1;
	char *buf = xmalloc(1+size);

	memcpy(buf, buffer + bytes, stream->total_out - bytes);
	bytes = stream->total_out - bytes;
	if (bytes < size) {
		stream->next_out = buf + bytes;
		stream->avail_out = size - bytes;
		while (inflate(stream, Z_FINISH) == Z_OK)
			/* nothing */;
	}
	buf[size] = 0;
	inflateEnd(stream);
	return buf;
}

/*
 * We used to just use "sscanf()", but that's actually way
 * too permissive for what we want to check. So do an anal
 * object header parse by hand.
 */
int parse_sha1_header(char *hdr, char *type, unsigned long *sizep)
{
	int i;
	unsigned long size;

	/*
	 * The type can be at most ten bytes (including the 
	 * terminating '\0' that we add), and is followed by
	 * a space. 
	 */
	i = 10;
	for (;;) {
		char c = *hdr++;
		if (c == ' ')
			break;
		if (!--i)
			return -1;
		*type++ = c;
	}
	*type = 0;

	/*
	 * The length must follow immediately, and be in canonical
	 * decimal format (ie "010" is not valid).
	 */
	size = *hdr++ - '0';
	if (size > 9)
		return -1;
	if (size) {
		for (;;) {
			unsigned long c = *hdr - '0';
			if (c > 9)
				break;
			hdr++;
			size = size * 10 + c;
		}
	}
	*sizep = size;

	/*
	 * The length must be followed by a zero byte
	 */
	return *hdr ? -1 : 0;
}

void * unpack_sha1_file(void *map, unsigned long mapsize, char *type, unsigned long *size)
{
	int ret;
	z_stream stream;
	char hdr[8192];

	ret = unpack_sha1_header(&stream, map, mapsize, hdr, sizeof(hdr));
	if (ret < Z_OK || parse_sha1_header(hdr, type, size) < 0)
		return NULL;

	return unpack_sha1_rest(&stream, hdr, *size);
}

int sha1_delta_base(const unsigned char *sha1, unsigned char *base_sha1)
{
	int ret;
	unsigned long mapsize, size;
	void *map;
	z_stream stream;
	char hdr[64], type[20];
	void *delta_data_head;

	map = map_sha1_file(sha1, &mapsize);
	if (!map)
		return -1;
	ret = unpack_sha1_header(&stream, map, mapsize, hdr, sizeof(hdr));
	if (ret < Z_OK || parse_sha1_header(hdr, type, &size) < 0) {
		ret = -1;
		goto out;
	}
	if (strcmp(type, "delta")) {
		ret = 0;
		goto out;
	}

	delta_data_head = hdr + strlen(hdr) + 1;
	ret = 1;
	memcpy(base_sha1, delta_data_head, 20);
 out:
	inflateEnd(&stream);
	munmap(map, mapsize);
	return ret;
}

int sha1_file_size(const unsigned char *sha1, unsigned long *sizep)
{
	int ret, status;
	unsigned long mapsize, size;
	void *map;
	z_stream stream;
	char hdr[64], type[20];
	const unsigned char *data;
	unsigned char cmd;
	int i;

	map = map_sha1_file(sha1, &mapsize);
	if (!map)
		return -1;
	ret = unpack_sha1_header(&stream, map, mapsize, hdr, sizeof(hdr));
	status = -1;
	if (ret < Z_OK || parse_sha1_header(hdr, type, &size) < 0)
		goto out;
	if (strcmp(type, "delta")) {
		*sizep = size;
		status = 0;
		goto out;
	}

	/* We are dealing with a delta object.  Inflated, the first
	 * 20 bytes hold the base object SHA1, and delta data follows
	 * immediately after it.
	 *
	 * The initial part of the delta starts at delta_data_head +
	 * 20.  Borrow code from patch-delta to read the result size.
	 */
	data = hdr + strlen(hdr) + 1 + 20;

	/* Skip over the source size; we are not interested in
	 * it and we cannot verify it because we do not want
	 * to read the base object.
	 */
	cmd = *data++;
	while (cmd) {
		if (cmd & 1)
			data++;
		cmd >>= 1;
	}
	/* Read the result size */
	size = i = 0;
	cmd = *data++;
	while (cmd) {
		if (cmd & 1)
			size |= *data++ << i;
		i += 8;
		cmd >>= 1;
	}
	*sizep = size;
	status = 0;
 out:
	inflateEnd(&stream);
	munmap(map, mapsize);
	return status;
}

void * read_sha1_file(const unsigned char *sha1, char *type, unsigned long *size)
{
	unsigned long mapsize;
	void *map, *buf;

	map = map_sha1_file(sha1, &mapsize);
	if (map) {
		buf = unpack_sha1_file(map, mapsize, type, size);
		munmap(map, mapsize);
		if (buf && !strcmp(type, "delta")) {
			void *ref = NULL, *delta = buf;
			unsigned long ref_size, delta_size = *size;
			buf = NULL;
			if (delta_size > 20)
				ref = read_sha1_file(delta, type, &ref_size);
			if (ref)
				buf = patch_delta(ref, ref_size,
						  delta+20, delta_size-20, 
						  size);
			free(delta);
			free(ref);
		}
		return buf;
	}
	return NULL;
}

void *read_object_with_reference(const unsigned char *sha1,
				 const char *required_type,
				 unsigned long *size,
				 unsigned char *actual_sha1_return)
{
	char type[20];
	void *buffer;
	unsigned long isize;
	unsigned char actual_sha1[20];

	memcpy(actual_sha1, sha1, 20);
	while (1) {
		int ref_length = -1;
		const char *ref_type = NULL;

		buffer = read_sha1_file(actual_sha1, type, &isize);
		if (!buffer)
			return NULL;
		if (!strcmp(type, required_type)) {
			*size = isize;
			if (actual_sha1_return)
				memcpy(actual_sha1_return, actual_sha1, 20);
			return buffer;
		}
		/* Handle references */
		else if (!strcmp(type, "commit"))
			ref_type = "tree ";
		else if (!strcmp(type, "tag"))
			ref_type = "object ";
		else {
			free(buffer);
			return NULL;
		}
		ref_length = strlen(ref_type);

		if (memcmp(buffer, ref_type, ref_length) ||
		    get_sha1_hex(buffer + ref_length, actual_sha1)) {
			free(buffer);
			return NULL;
		}
		/* Now we have the ID of the referred-to object in
		 * actual_sha1.  Check again. */
	}
}

int write_sha1_file(void *buf, unsigned long len, const char *type, unsigned char *returnsha1)
{
	int size;
	unsigned char *compressed;
	z_stream stream;
	unsigned char sha1[20];
	SHA_CTX c;
	char *filename;
	static char tmpfile[PATH_MAX];
	unsigned char hdr[50];
	int fd, hdrlen, ret;

	/* Generate the header */
	hdrlen = sprintf((char *)hdr, "%s %lu", type, len)+1;

	/* Sha1.. */
	SHA1_Init(&c);
	SHA1_Update(&c, hdr, hdrlen);
	SHA1_Update(&c, buf, len);
	SHA1_Final(sha1, &c);

	if (returnsha1)
		memcpy(returnsha1, sha1, 20);

	filename = sha1_file_name(sha1);
	fd = open(filename, O_RDONLY);
	if (fd >= 0) {
		/*
		 * FIXME!!! We might do collision checking here, but we'd
		 * need to uncompress the old file and check it. Later.
		 */
		close(fd);
		return 0;
	}

	if (errno != ENOENT) {
		fprintf(stderr, "sha1 file %s: %s", filename, strerror(errno));
		return -1;
	}

	snprintf(tmpfile, sizeof(tmpfile), "%s/obj_XXXXXX", get_object_directory());

	fd = mkstemp(tmpfile);
	if (fd < 0) {
		fprintf(stderr, "unable to create temporary sha1 filename %s: %s", tmpfile, strerror(errno));
		return -1;
	}

	/* Set it up */
	memset(&stream, 0, sizeof(stream));
	deflateInit(&stream, Z_BEST_COMPRESSION);
	size = deflateBound(&stream, len+hdrlen);
	compressed = xmalloc(size);

	/* Compress it */
	stream.next_out = compressed;
	stream.avail_out = size;

	/* First header.. */
	stream.next_in = hdr;
	stream.avail_in = hdrlen;
	while (deflate(&stream, 0) == Z_OK)
		/* nothing */;

	/* Then the data itself.. */
	stream.next_in = buf;
	stream.avail_in = len;
	while (deflate(&stream, Z_FINISH) == Z_OK)
		/* nothing */;
	deflateEnd(&stream);
	size = stream.total_out;

	if (write(fd, compressed, size) != size)
		die("unable to write file");
	fchmod(fd, 0444);
	close(fd);
	free(compressed);

	ret = link(tmpfile, filename);
	if (ret < 0) {
		ret = errno;

		/*
		 * Coda hack - coda doesn't like cross-directory links,
		 * so we fall back to a rename, which will mean that it
		 * won't be able to check collisions, but that's not a
		 * big deal.
		 *
		 * When this succeeds, we just return 0. We have nothing
		 * left to unlink.
		 */
		if (ret == EXDEV && !rename(tmpfile, filename))
			return 0;
	}
	unlink(tmpfile);
	if (ret) {
		if (ret != EEXIST) {
			fprintf(stderr, "unable to write sha1 filename %s: %s", filename, strerror(ret));
			return -1;
		}
		/* FIXME!!! Collision check here ? */
	}

	return 0;
}

int write_sha1_from_fd(const unsigned char *sha1, int fd)
{
	char *filename = sha1_file_name(sha1);

	int local;
	z_stream stream;
	unsigned char real_sha1[20];
	unsigned char buf[4096];
	unsigned char discard[4096];
	int ret;
	SHA_CTX c;

	local = open(filename, O_WRONLY | O_CREAT | O_EXCL, 0666);

	if (local < 0)
		return error("Couldn't open %s\n", filename);

	memset(&stream, 0, sizeof(stream));

	inflateInit(&stream);

	SHA1_Init(&c);

	do {
		ssize_t size;
		size = read(fd, buf, 4096);
		if (size <= 0) {
			close(local);
			unlink(filename);
			if (!size)
				return error("Connection closed?");
			perror("Reading from connection");
			return -1;
		}
		write(local, buf, size);
		stream.avail_in = size;
		stream.next_in = buf;
		do {
			stream.next_out = discard;
			stream.avail_out = sizeof(discard);
			ret = inflate(&stream, Z_SYNC_FLUSH);
			SHA1_Update(&c, discard, sizeof(discard) -
				    stream.avail_out);
		} while (stream.avail_in && ret == Z_OK);
		
	} while (ret == Z_OK);
	inflateEnd(&stream);

	close(local);
	SHA1_Final(real_sha1, &c);
	if (ret != Z_STREAM_END) {
		unlink(filename);
		return error("File %s corrupted", sha1_to_hex(sha1));
	}
	if (memcmp(sha1, real_sha1, 20)) {
		unlink(filename);
		return error("File %s has bad hash\n", sha1_to_hex(sha1));
	}
	
	return 0;
}

int has_sha1_file(const unsigned char *sha1)
{
	struct stat st;
	return !!find_sha1_file(sha1, &st);
}

int index_fd(unsigned char *sha1, int fd, struct stat *st)
{
	unsigned long size = st->st_size;
	void *buf;
	int ret;

	buf = "";
	if (size)
		buf = mmap(NULL, size, PROT_READ, MAP_PRIVATE, fd, 0);
	close(fd);
	if ((int)(long)buf == -1)
		return -1;

	ret = write_sha1_file(buf, size, "blob", sha1);
	if (size)
		munmap(buf, size);
	return ret;
}
