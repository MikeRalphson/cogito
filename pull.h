#ifndef PULL_H
#define PULL_H

/*
 * Fetch object given SHA1 from the remote, and store it locally under
 * GIT_OBJECT_DIRECTORY.  Return 0 on success, -1 on failure.  To be
 * provided by the particular implementation.
 */
extern int fetch(unsigned char *sha1);

/*
 * Fetch ref (relative to $GIT_DIR/refs) from the remote, and store
 * the 20-byte SHA1 in sha1.  Return 0 on success, -1 on failure.  To
 * be provided by the particular implementation.
 */
extern int fetch_ref(char *ref, unsigned char *sha1);

/* If set, the ref filename to write the target value to. */
extern const char *write_ref;

/* If set, the hash that the current value of write_ref must be. */
extern const unsigned char *current_ref;

/* Set to fetch the target tree. */
extern int get_tree;

/* Set to fetch the commit history. */
extern int get_history;

/* Set to fetch the trees in the commit history. */
extern int get_all;

/* Set to be verbose */
extern int get_verbosely;

/* Report what we got under get_verbosely */
extern void pull_say(const char *, const char *);

extern int pull(char *target);

#endif /* PULL_H */
