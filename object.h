#ifndef OBJECT_H
#define OBJECT_H

struct object_list {
	struct object *item;
	struct object_list *next;
};

struct object {
	unsigned parsed : 1;
	unsigned used : 1;
	unsigned int flags;
	unsigned char sha1[20];
	const char *type;
	struct object_list *refs;
};

int nr_objs;
struct object **objs;

struct object *lookup_object(unsigned char *sha1);

void created_object(unsigned char *sha1, struct object *obj);

void add_ref(struct object *refer, struct object *target);

void mark_reachable(struct object *obj, unsigned int mask);

#endif /* OBJECT_H */
