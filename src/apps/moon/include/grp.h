#pragma once
#include <sys/types.h>

struct group {
	char  *gr_name;
	char  *gr_passwd;
	gid_t  gr_gid;
	char **gr_mem;
};

struct group *getgrnam(char const*);
struct group *getgrgid(gid_t);
struct group *getgrent(void);
void          setgrent(void);
void          endgrent(void);
int setgroups(size_t, gid_t const*);
