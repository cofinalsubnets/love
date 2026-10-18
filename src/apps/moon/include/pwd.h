#ifndef _LOVE_PWD_H
#define _LOVE_PWD_H
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

struct passwd *getpwnam(char const*);
struct passwd *getpwuid(uid_t);
struct passwd *getpwent(void);
void           setpwent(void);
void           endpwent(void);
#endif
