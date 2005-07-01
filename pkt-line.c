#include "cache.h"
#include "pkt-line.h"

/*
 * Write a packetized stream, where each line is preceded by
 * its length (including the header) as a 4-byte hex number.
 * A length of 'zero' means end of stream (and a length of 1-3
 * would be an error). 
 *
 * This is all pretty stupid, but we use this packetized line
 * format to make a streaming format possible without ever
 * over-running the read buffers. That way we'll never read
 * into what might be the pack data (which should go to another
 * process entirely).
 *
 * The writing side could use stdio, but since the reading
 * side can't, we stay with pure read/write interfaces.
 */
static void safe_write(int fd, const void *buf, unsigned n)
{
	while (n) {
		int ret = write(fd, buf, n);
		if (ret > 0) {
			buf += ret;
			n -= ret;
			continue;
		}
		if (!ret)
			die("write error (disk full?)");
		if (errno == EAGAIN || errno == EINTR)
			continue;
		die("write error (%s)", strerror(errno));
	}
}

/*
 * If we buffered things up above (we don't, but we should),
 * we'd flush it here
 */
void packet_flush(int fd)
{
	safe_write(fd, "0000", 4);
}

#define hex(a) (hexchar[(a) & 15])
void packet_write(int fd, const char *fmt, ...)
{
	static char buffer[1000];
	static char hexchar[] = "0123456789abcdef";
	va_list args;
	unsigned n;

	va_start(args, fmt);
	n = vsnprintf(buffer + 4, sizeof(buffer) - 4, fmt, args);
	va_end(args);
	if (n >= sizeof(buffer)-4)
		die("protocol error: impossibly long line");
	n += 4;
	buffer[0] = hex(n >> 12);
	buffer[1] = hex(n >> 8);
	buffer[2] = hex(n >> 4);
	buffer[3] = hex(n);
	safe_write(fd, buffer, n);
}

static void safe_read(int fd, void *buffer, unsigned size)
{
	int n = 0;

	while (n < size) {
		int ret = read(fd, buffer + n, size - n);
		if (ret < 0) {
			if (errno == EINTR || errno == EAGAIN)
				continue;
			die("read error (%s)", strerror(errno));
		}
		if (!ret)
			die("unexpected EOF");
		n += ret;
	}
}

int packet_read_line(int fd, char *buffer, unsigned size)
{
	int n;
	unsigned len;
	char linelen[4];

	safe_read(fd, linelen, 4);

	len = 0;
	for (n = 0; n < 4; n++) {
		unsigned char c = linelen[n];
		len <<= 4;
		if (c >= '0' && c <= '9') {
			len += c - '0';
			continue;
		}
		if (c >= 'a' && c <= 'f') {
			len += c - 'a' + 10;
			continue;
		}
		if (c >= 'A' && c <= 'F') {
			len += c - 'A' + 10;
			continue;
		}
		die("protocol error: bad line length character");
	}
	if (!len)
		return 0;
	len -= 4;
	if (len >= size)
		die("protocol error: bad line length %d", len);
	safe_read(fd, buffer, len);
	buffer[len] = 0;
	return len;
}
