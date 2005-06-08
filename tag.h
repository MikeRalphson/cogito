#ifndef TAG_H
#define TAG_H

#include "object.h"

extern const char *tag_type;

struct tag {
	struct object object;
	struct object *tagged;
	char *tag;
	char *signature; /* not actually implemented */
};

extern struct tag *lookup_tag(const unsigned char *sha1);
extern int parse_tag_buffer(struct tag *item, void *data, unsigned long size);
extern int parse_tag(struct tag *item);

#endif /* TAG_H */
