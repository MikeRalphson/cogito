#include "tag.h"
#include "cache.h"

const char *tag_type = "tag";

struct tag *lookup_tag(const unsigned char *sha1)
{
        struct object *obj = lookup_object(sha1);
        if (!obj) {
                struct tag *ret = xmalloc(sizeof(struct tag));
                memset(ret, 0, sizeof(struct tag));
                created_object(sha1, &ret->object);
                ret->object.type = tag_type;
                return ret;
        }
	if (!obj->type)
		obj->type = tag_type;
        if (obj->type != tag_type) {
                error("Object %s is a %s, not a tree", 
                      sha1_to_hex(sha1), obj->type);
                return NULL;
        }
        return (struct tag *) obj;
}

int parse_tag_buffer(struct tag *item, void *data, unsigned long size)
{
	int typelen, taglen;
	unsigned char object[20];
	const char *type_line, *tag_line, *sig_line;
	char type[20];

        if (item->object.parsed)
                return 0;
        item->object.parsed = 1;

	if (size < 64)
		return -1;
	if (memcmp("object ", data, 7) || get_sha1_hex(data + 7, object))
		return -1;

	type_line = data + 48;
	if (memcmp("\ntype ", type_line-1, 6))
		return -1;

	tag_line = strchr(type_line, '\n');
	if (!tag_line || memcmp("tag ", ++tag_line, 4))
		return -1;

	sig_line = strchr(tag_line, '\n');
	if (!sig_line)
		return -1;
	sig_line++;

	typelen = tag_line - type_line - strlen("type \n");
	if (typelen >= 20)
		return -1;
	memcpy(type, type_line + 5, typelen);
	type[typelen] = '\0';
	taglen = sig_line - tag_line - strlen("tag \n");
	item->tag = xmalloc(taglen + 1);
	memcpy(item->tag, tag_line + 4, taglen);
	item->tag[taglen] = '\0';

	item->tagged = lookup_object_type(object, type);
	if (item->tagged)
		add_ref(&item->object, item->tagged);

	return 0;
}

int parse_tag(struct tag *item)
{
	char type[20];
	void *data;
	unsigned long size;
	int ret;

	if (item->object.parsed)
		return 0;
	data = read_sha1_file(item->object.sha1, type, &size);
	if (!data)
		return error("Could not read %s",
			     sha1_to_hex(item->object.sha1));
	if (strcmp(type, tag_type)) {
		free(data);
		return error("Object %s not a tag",
			     sha1_to_hex(item->object.sha1));
	}
	ret = parse_tag_buffer(item, data, size);
	free(data);
	return ret;
}
