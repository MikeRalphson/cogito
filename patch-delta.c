/*
 * patch-delta.c:
 * recreate a buffer from a source and the delta produced by diff-delta.c
 *
 * (C) 2005 Nicolas Pitre <nico@cam.org>
 *
 * This code is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

#include <stdlib.h>
#include <string.h>
#include "delta.h"

void *patch_delta(void *src_buf, unsigned long src_size,
		  void *delta_buf, unsigned long delta_size,
		  unsigned long *dst_size)
{
	const unsigned char *data, *top;
	unsigned char *dst_buf, *out, cmd;
	unsigned long size;
	int i;

	/* the smallest delta size possible is 6 bytes */
	if (delta_size < 6)
		return NULL;

	data = delta_buf;
	top = delta_buf + delta_size;

	/* make sure the orig file size matches what we expect */
	size = i = 0;
	cmd = *data++;
	while (cmd) {
		if (cmd & 1)
			size |= *data++ << i;
		i += 8;
		cmd >>= 1;
	}
	if (size != src_size)
		return NULL;

	/* now the result size */
	size = i = 0;
	cmd = *data++;
	while (cmd) {
		if (cmd & 1)
			size |= *data++ << i;
		i += 8;
		cmd >>= 1;
	}
	dst_buf = malloc(size);
	if (!dst_buf)
		return NULL;

	out = dst_buf;
	while (data < top) {
		cmd = *data++;
		if (cmd & 0x80) {
			unsigned long cp_off = 0, cp_size = 0;
			const unsigned char *buf;
			if (cmd & 0x01) cp_off = *data++;
			if (cmd & 0x02) cp_off |= (*data++ << 8);
			if (cmd & 0x04) cp_off |= (*data++ << 16);
			if (cmd & 0x08) cp_off |= (*data++ << 24);
			if (cmd & 0x10) cp_size = *data++;
			if (cmd & 0x20) cp_size |= (*data++ << 8);
			if (cp_size == 0) cp_size = 0x10000;
			buf = (cmd & 0x40) ? dst_buf : src_buf;
			memcpy(out, buf + cp_off, cp_size);
			out += cp_size;
		} else {
			memcpy(out, data, cmd);
			out += cmd;
			data += cmd;
		}
	}

	/* sanity check */
	if (data != top || out - dst_buf != size) {
		free(dst_buf);
		return NULL;
	}

	*dst_size = size;
	return dst_buf;
}
