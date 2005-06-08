#include "blob.h"
#include "cache.h"
#include <stdlib.h>

const char *blob_type = "blob";

struct blob *lookup_blob(const unsigned char *sha1)
{
	struct object *obj = lookup_object(sha1);
	if (!obj) {
		struct blob *ret = xmalloc(sizeof(struct blob));
		memset(ret, 0, sizeof(struct blob));
		created_object(sha1, &ret->object);
		ret->object.type = blob_type;
		return ret;
	}
	if (!obj->type)
		obj->type = blob_type;
	if (obj->type != blob_type) {
		error("Object %s is a %s, not a blob", 
		      sha1_to_hex(sha1), obj->type);
		return NULL;
	}
	return (struct blob *) obj;
}

int parse_blob_buffer(struct blob *item, void *buffer, unsigned long size)
{
	item->object.parsed = 1;
	return 0;
}

int parse_blob(struct blob *item)
{
        char type[20];
        void *buffer;
        unsigned long size;
	int ret;

        if (item->object.parsed)
                return 0;
        buffer = read_sha1_file(item->object.sha1, type, &size);
        if (!buffer)
                return error("Could not read %s",
                             sha1_to_hex(item->object.sha1));
        if (strcmp(type, blob_type))
                return error("Object %s not a blob",
                             sha1_to_hex(item->object.sha1));
	ret = parse_blob_buffer(item, buffer, size);
	free(buffer);
	return ret;
}
