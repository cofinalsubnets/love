#pragma once
#include <stddef.h>
#include <sys/types.h>

struct group {
	char  *gr_name;
	char  *gr_passwd;
	gid_t  gr_gid;
	char **gr_mem;
};

struct group *getgrnam(char const*), *getgrgid(gid_t), *getgrent(void);
void setgrent(void), endgrent(void);
int getgrnam_r(char const*, struct group*, char*, size_t, struct group**),
    getgrgid_r(gid_t, struct group*, char*, size_t, struct group**),
    getgrent_r(struct group*, char*, size_t, struct group**);
int setgroups(size_t, gid_t const*);
