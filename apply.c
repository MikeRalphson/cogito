static int check_index = 0;
static int write_index = 0;
	char *result;
	unsigned long resultsize;
static unsigned long linelen(const char *buffer, unsigned long size)
			{ "rename old ", gitdiff_renamesrc },
			{ "rename new ", gitdiff_renamedst },
				die("git diff header lacks filename information (line %d)", linenr);
	unsigned long oldlines, newlines;
	if (patch->is_new < 0) {
		patch->is_new =  !oldlines;
		if (!oldlines)
			patch->old_name = NULL;
	}
	if (patch->is_delete < 0) {
		patch->is_delete = !newlines;
		if (!newlines)
			patch->new_name = NULL;
	}

	if (patch->is_new != !oldlines)
		return error("new file depends on old contents");
	if (patch->is_delete != !newlines) {
		if (newlines)
			return error("deleted file still has contents");
		fprintf(stderr, "** warning: file %s becomes empty but is not deleted\n", patch->new_name);
	}
			if (len < 12 || memcmp(line, "\\ No newline", 12))
				return -1;
static int read_old_data(struct stat *st, const char *path, void *buf, unsigned long size)
{
	int fd;
	unsigned long got;

	switch (st->st_mode & S_IFMT) {
	case S_IFLNK:
		return readlink(path, buf, size);
	case S_IFREG:
		fd = open(path, O_RDONLY);
		if (fd < 0)
			return error("unable to open %s", path);
		got = 0;
		for (;;) {
			int ret = read(fd, buf + got, size - got);
			if (ret < 0) {
				if (errno == EAGAIN)
					continue;
				break;
			}
			if (!ret)
				break;
			got += ret;
		}
		close(fd);
		return got;

	default:
		return -1;
	}
}

static int find_offset(const char *buf, unsigned long size, const char *fragment, unsigned long fragsize, int line)
{
	int i;
	unsigned long start, backwards, forwards;

	if (fragsize > size)
		return -1;

	start = 0;
	if (line > 1) {
		unsigned long offset = 0;
		i = line-1;
		while (offset + fragsize <= size) {
			if (buf[offset++] == '\n') {
				start = offset;
				if (!--i)
					break;
			}
		}
	}

	/* Exact line number? */
	if (!memcmp(buf + start, fragment, fragsize))
		return start;

	/*
	 * There's probably some smart way to do this, but I'll leave
	 * that to the smart and beautiful people. I'm simple and stupid.
	 */
	backwards = start;
	forwards = start;
	for (i = 0; ; i++) {
		unsigned long try;
		int n;

		/* "backward" */
		if (i & 1) {
			if (!backwards) {
				if (forwards + fragsize > size)
					break;
				continue;
			}
			do {
				--backwards;
			} while (backwards && buf[backwards-1] != '\n');
			try = backwards;
		} else {
			while (forwards + fragsize <= size) {
				if (buf[forwards++] == '\n')
					break;
			}
			try = forwards;
		}

		if (try + fragsize > size)
			continue;
		if (memcmp(buf + try, fragment, fragsize))
			continue;
		n = (i >> 1)+1;
		if (i & 1)
			n = -n;
		fprintf(stderr, "Fragment applied at offset %d\n", n);
		return try;
	}

	/*
	 * We should start searching forward and backward.
	 */
	return -1;
}

struct buffer_desc {
	char *buffer;
	unsigned long size;
	unsigned long alloc;
};

static int apply_one_fragment(struct buffer_desc *desc, struct fragment *frag)
{
	char *buf = desc->buffer;
	const char *patch = frag->patch;
	int offset, size = frag->size;
	char *old = xmalloc(size);
	char *new = xmalloc(size);
	int oldsize = 0, newsize = 0;

	while (size > 0) {
		int len = linelen(patch, size);
		int plen;

		if (!len)
			break;

		/*
		 * "plen" is how much of the line we should use for
		 * the actual patch data. Normally we just remove the
		 * first character on the line, but if the line is
		 * followed by "\ No newline", then we also remove the
		 * last one (which is the newline, of course).
		 */
		plen = len-1;
		if (len > size && patch[len] == '\\')
			plen--;
		switch (*patch) {
		case ' ':
		case '-':
			memcpy(old + oldsize, patch + 1, plen);
			oldsize += plen;
			if (*patch == '-')
				break;
		/* Fall-through for ' ' */
		case '+':
			memcpy(new + newsize, patch + 1, plen);
			newsize += plen;
			break;
		case '@': case '\\':
			/* Ignore it, we already handled it */
			break;
		default:
			return -1;
		}
		patch += len;
		size -= len;
	}

	offset = find_offset(buf, desc->size, old, oldsize, frag->newpos);
	if (offset >= 0) {
		int diff = newsize - oldsize;
		unsigned long size = desc->size + diff;
		unsigned long alloc = desc->alloc;

		if (size > alloc) {
			alloc = size + 8192;
			desc->alloc = alloc;
			buf = xrealloc(buf, alloc);
			desc->buffer = buf;
		}
		desc->size = size;
		memmove(buf + offset + newsize, buf + offset + oldsize, size - offset - newsize);
		memcpy(buf + offset, new, newsize);
		offset = 0;
	}

	free(old);
	free(new);
	return offset;
}

static int apply_fragments(struct buffer_desc *desc, struct patch *patch)
{
	struct fragment *frag = patch->fragments;

	while (frag) {
		if (apply_one_fragment(desc, frag) < 0)
			return error("patch failed: %s:%d", patch->old_name, frag->oldpos);
		frag = frag->next;
	}
	return 0;
}

static int apply_data(struct patch *patch, struct stat *st)
{
	char *buf;
	unsigned long size, alloc;
	struct buffer_desc desc;

	size = 0;
	alloc = 0;
	buf = NULL;
	if (patch->old_name) {
		size = st->st_size;
		alloc = size + 8192;
		buf = xmalloc(alloc);
		if (read_old_data(st, patch->old_name, buf, alloc) != size)
			return error("read of %s failed", patch->old_name);
	}

	desc.size = size;
	desc.alloc = alloc;
	desc.buffer = buf;
	if (apply_fragments(&desc, patch) < 0)
		return -1;
	patch->result = desc.buffer;
	patch->resultsize = desc.size;

	if (patch->is_delete && patch->resultsize)
		return error("removal patch leaves file contents");

	return 0;
}

		if (check_index) {
			int pos = cache_name_pos(old_name, strlen(old_name));
			if (pos < 0)
				return error("%s: does not exist in index", old_name);
			changed = ce_match_stat(active_cache[pos], &st);
			if (changed)
				return error("%s: does not match index", old_name);
		}
		if (patch->is_new < 0)
			patch->is_new = 0;
		if ((st.st_mode ^ patch->old_mode) & S_IFMT)
			return error("%s: wrong type", old_name);
		if (st.st_mode != patch->old_mode)
			fprintf(stderr, "warning: %s has type %o, expected %o\n",
				old_name, st.st_mode, patch->old_mode);
		if (check_index && cache_name_pos(new_name, strlen(new_name)) >= 0)
		if (!patch->new_mode)
			patch->new_mode = S_IFREG | 0644;

	if (new_name && old_name) {
		int same = !strcmp(old_name, new_name);
		if (!patch->new_mode)
			patch->new_mode = patch->old_mode;
		if ((patch->old_mode ^ patch->new_mode) & S_IFMT)
			return error("new mode (%o) of %s does not match old mode (%o)%s%s",
				patch->new_mode, new_name, patch->old_mode,
				same ? "" : " of ", same ? "" : old_name);
	}	

	if (apply_data(patch, &st) < 0)
		return error("%s: patch does not apply", old_name);
static void remove_file(struct patch *patch)
{
	if (write_index) {
		if (remove_file_from_cache(patch->old_name) < 0)
			die("unable to remove %s from index", patch->old_name);
	}
	unlink(patch->old_name);
}

static void add_index_file(const char *path, unsigned mode, void *buf, unsigned long size)
{
	struct stat st;
	struct cache_entry *ce;
	int namelen = strlen(path);
	unsigned ce_size = cache_entry_size(namelen);

	if (!write_index)
		return;

	ce = xmalloc(ce_size);
	memset(ce, 0, ce_size);
	memcpy(ce->name, path, namelen);
	ce->ce_mode = create_ce_mode(mode);
	ce->ce_flags = htons(namelen);
	if (lstat(path, &st) < 0)
		die("unable to stat newly created file %s", path);
	fill_stat_cache_info(ce, &st);
	if (write_sha1_file(buf, size, "blob", ce->sha1) < 0)
		die("unable to create backing store for newly created file %s", path);
	if (add_cache_entry(ce, ADD_CACHE_OK_TO_ADD) < 0)
		die("unable to add cache entry for %s", path);
}

static void create_file(struct patch *patch)
{
	const char *path = patch->new_name;
	unsigned mode = patch->new_mode;
	unsigned long size = patch->resultsize;
	char *buf = patch->result;

	if (!mode)
		mode = S_IFREG | 0644;
	if (S_ISREG(mode)) {
		int fd;
		mode = (mode & 0100) ? 0777 : 0666;
		fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, mode);
		if (fd < 0)
			die("unable to create file %s (%s)", path, strerror(errno));
		if (write(fd, buf, size) != size)
			die("unable to write file %s", path);
		close(fd);
		add_index_file(path, mode, buf, size);
		return;
	}
	if (S_ISLNK(mode)) {
		if (size && buf[size-1] == '\n')
			size--;
		buf[size] = 0;
		if (symlink(buf, path) < 0)
			die("unable to write symlink %s", path);
		add_index_file(path, mode, buf, size);
		return;
	}
	die("unable to write file mode %o", mode);
}

static void write_out_one_result(struct patch *patch)
{
	if (patch->is_delete > 0) {
		remove_file(patch);
		return;
	}
	if (patch->is_new > 0 || patch->is_copy) {
		create_file(patch);
		return;
	}
	/*
	 * Rename or modification boils down to the same
	 * thing: remove the old, write the new
	 */
	remove_file(patch);
	create_file(patch);
}

static void write_out_results(struct patch *list)
{
	if (!list)
		die("No changes");

	while (list) {
		write_out_one_result(list);
		list = list->next;
	}
}

static struct cache_file cache_file;

	int newfd;
	newfd = -1;
	write_index = check_index && apply;
	if (write_index)
		newfd = hold_index_file_for_update(&cache_file, get_index_file());
	if (check_index) {
		if (read_cache() < 0)
			die("unable to read index file");
	}

	if (apply)
		write_out_results(list);

	if (write_index) {
		if (write_cache(newfd, active_cache, active_nr) ||
		    commit_index_file(&cache_file))
			die("Unable to write new cachefile");
	}

		if (!strcmp(arg, "--index")) {
			check_index = 1;
			continue;
		}