/*
 * Another stupid program, this one parsing the headers of an
 * email to figure out authorship and subject
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

static FILE *cmitmsg, *patchfile;

static char line[1000];
static char date[1000];
static char name[1000];
static char email[1000];
static char subject[1000];

static char *sanity_check(char *name, char *email)
{
	int len = strlen(name);
	if (len < 3 || len > 60)
		return email;
	if (strchr(name, '@') || strchr(name, '<') || strchr(name, '>'))
		return email;
	return name;
}

static int handle_from(char *line)
{
	char *at = strchr(line, '@');
	char *dst;

	if (!at)
		return 0;

	/*
	 * If we already have one email, don't take any confusing lines
	 */
	if (*email && strchr(at+1, '@'))
		return 0;

	while (at > line) {
		char c = at[-1];
		if (isspace(c) || c == '<')
			break;
		at--;
	}
	dst = email;
	for (;;) {
		unsigned char c = *at;
		if (!c || c == '>' || isspace(c))
			break;
		*at++ = ' ';
		*dst++ = c;
	}
	*dst++ = 0;

	at = line + strlen(line);
	while (at > line) {
		unsigned char c = *--at;
		if (isalnum(c))
			break;
		*at = 0;
	}

	at = line;
	for (;;) {
		unsigned char c = *at;
		if (!c)
			break;
		if (isalnum(c))
			break;
		at++;
	}

	at = sanity_check(at, email);
	
	strcpy(name, at);
	return 1;
}

static void handle_date(char *line)
{
	strcpy(date, line);
}

static void handle_subject(char *line)
{
	strcpy(subject, line);
}

static void add_subject_line(char *line)
{
	while (isspace(*line))
		line++;
	*--line = ' ';
	strcat(subject, line);
}

static void check_line(char *line, int len)
{
	static int cont = -1;
	if (!memcmp(line, "From:", 5) && isspace(line[5])) {
		handle_from(line+6);
		cont = 0;
		return;
	}
	if (!memcmp(line, "Date:", 5) && isspace(line[5])) {
		handle_date(line+6);
		cont = 0;
		return;
	}
	if (!memcmp(line, "Subject:", 8) && isspace(line[8])) {
		handle_subject(line+9);
		cont = 1;
		return;
	}
	if (isspace(*line)) {
		switch (cont) {
		case 0:
			fprintf(stderr, "I don't do 'Date:' or 'From:' line continuations\n");
			break;
		case 1:
			add_subject_line(line);
			return;
		default:
			break;
		}
	}
	cont = -1;
}

static char * cleanup_subject(char *subject)
{
	for (;;) {
		char *p;
		int len, remove;
		switch (*subject) {
		case 'r': case 'R':
			if (!memcmp("e:", subject+1, 2)) {
				subject +=3;
				continue;
			}
			break;
		case ' ': case '\t': case ':':
			subject++;
			continue;

		case '[':
			p = strchr(subject, ']');
			if (!p) {
				subject++;
				continue;
			}
			len = strlen(p);
			remove = p - subject;
			if (remove <= len *2) {
				subject = p+1;
				continue;
			}	
			break;
		}
		return subject;
	}
}			

static void cleanup_space(char *buf)
{
	unsigned char c;
	while ((c = *buf) != 0) {
		buf++;
		if (isspace(c)) {
			buf[-1] = ' ';
			c = *buf;
			while (isspace(c)) {
				int len = strlen(buf);
				memmove(buf, buf+1, len);
				c = *buf;
			}
		}
	}
}

static void handle_rest(void)
{
	char *sub = cleanup_subject(subject);
	cleanup_space(name);
	cleanup_space(date);
	cleanup_space(email);
	cleanup_space(sub);
	printf("Author: %s\nEmail: %s\nSubject: %s\nDate: %s\n\n", name, email, sub, date);
	FILE *out = cmitmsg;

	do {
		if (!memcmp("diff -", line, 6) ||
		    !memcmp("---", line, 3) ||
		    !memcmp("Index: ", line, 7))
			out = patchfile;

		fputs(line, out);
	} while (fgets(line, sizeof(line), stdin) != NULL);

	if (out == cmitmsg) {
		fprintf(stderr, "No patch found\n");
		exit(1);
	}

	fclose(cmitmsg);
	fclose(patchfile);
}

static int eatspace(char *line)
{
	int len = strlen(line);
	while (len > 0 && isspace(line[len-1]))
		line[--len] = 0;
	return len;
}

static void handle_body(void)
{
	int has_from = 0;

	/* First line of body can be a From: */
	while (fgets(line, sizeof(line), stdin) != NULL) {
		int len = eatspace(line);
		if (!len)
			continue;
		if (!memcmp("From:", line, 5) && isspace(line[5])) {
			if (!has_from && handle_from(line+6)) {
				has_from = 1;
				continue;
			}
		}
		line[len] = '\n';
		handle_rest();
		break;
	}
}

static void usage(void)
{
	fprintf(stderr, "mailinfo msg-file path-file < email\n");
	exit(1);
}

int main(int argc, char ** argv)
{
	if (argc != 3)
		usage();
	cmitmsg = fopen(argv[1], "w");
	if (!cmitmsg) {
		perror(argv[1]);
		exit(1);
	}
	patchfile = fopen(argv[2], "w");
	if (!patchfile) {
		perror(argv[2]);
		exit(1);
	}
	while (fgets(line, sizeof(line), stdin) != NULL) {
		int len = eatspace(line);
		if (!len) {
			handle_body();
			break;
		}
		check_line(line, len);
	}
	return 0;
}
