#pragma once
#include <stddef.h>
#include <sys/types.h>

struct passwd {
	char *pw_name;
	char *pw_passwd;
	uid_t pw_uid;
	gid_t pw_gid;
	char *pw_gecos;
	char *pw_dir;
	char *pw_shell;
};

struct passwd *getpwnam(char const*), *getpwuid(uid_t), *getpwent(void);
void setpwent(void), endpwent(void);
int getpwnam_r(char const*, struct passwd*, char*, size_t, struct passwd**),
    getpwuid_r(uid_t, struct passwd*, char*, size_t, struct passwd**),
    getpwent_r(struct passwd*, char*, size_t, struct passwd**);
