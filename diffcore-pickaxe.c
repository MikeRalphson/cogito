/*
 * Copyright (C) 2005 Junio C Hamano
 */
#include "cache.h"
#include "diff.h"
#include "diffcore.h"

static int contains(struct diff_filespec *one,
		    const char *needle, unsigned long len)
{
	unsigned long offset, sz;
	const char *data;
	if (diff_populate_filespec(one, 0))
		return 0;
	sz = one->size;
	data = one->data;
	for (offset = 0; offset + len <= sz; offset++)
		     if (!strncmp(needle, data + offset, len))
			     return 1;
	return 0;
}

void diffcore_pickaxe(const char *needle, int opts)
{
	struct diff_queue_struct *q = &diff_queued_diff;
	unsigned long len = strlen(needle);
	int i, has_changes;
	struct diff_queue_struct outq;
	outq.queue = NULL;
	outq.nr = outq.alloc = 0;

	if (opts & DIFF_PICKAXE_ALL) {
		/* Showing the whole changeset if needle exists */
		for (i = has_changes = 0; !has_changes && i < q->nr; i++) {
			struct diff_filepair *p = q->queue[i];
			if (!DIFF_FILE_VALID(p->one)) {
				if (!DIFF_FILE_VALID(p->two))
					continue; /* ignore unmerged */
				/* created */
				if (contains(p->two, needle, len))
					has_changes++;
			}
			else if (!DIFF_FILE_VALID(p->two)) {
				if (contains(p->one, needle, len))
					has_changes++;
			}
			else if (!diff_unmodified_pair(p) &&
				 contains(p->one, needle, len) !=
				 contains(p->two, needle, len))
				has_changes++;
		}
		if (has_changes)
			return; /* not munge the queue */

		/* otherwise we will clear the whole queue
		 * by copying the empty outq at the end of this
		 * function, but first clear the current entries
		 * in the queue.
		 */
		for (i = 0; i < q->nr; i++)
			diff_free_filepair(q->queue[i]);
	}
	else 
		/* Showing only the filepairs that has the needle */
		for (i = 0; i < q->nr; i++) {
			struct diff_filepair *p = q->queue[i];
			has_changes = 0;
			if (!DIFF_FILE_VALID(p->one)) {
				if (!DIFF_FILE_VALID(p->two))
					; /* ignore unmerged */
				/* created */
				else if (contains(p->two, needle, len))
					has_changes = 1;
			}
			else if (!DIFF_FILE_VALID(p->two)) {
				if (contains(p->one, needle, len))
					has_changes = 1;
			}
			else if (!diff_unmodified_pair(p) &&
				 contains(p->one, needle, len) !=
				 contains(p->two, needle, len))
				has_changes = 1;

			if (has_changes)
				diff_q(&outq, p);
			else
				diff_free_filepair(p);
		}

	free(q->queue);
	*q = outq;
	return;
}
