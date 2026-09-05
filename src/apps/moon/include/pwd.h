#ifndef _AI_PWD_H
#define _AI_PWD_H
/* freestanding pwd.h for cc: the password-database entry + its lookups. */
#include <sys/types.h>

struct passwd {
	char *pw_name;   /* username */
	char *pw_passwd; /* password */
	uid_t pw_uid;    /* user id */
	gid_t pw_gid;    /* group id */
	char *pw_gecos;  /* real name */
	char *pw_dir;    /* home directory */
	char *pw_shell;  /* shell program */
};

struct passwd *getpwnam(char const*);
struct passwd *getpwuid(uid_t);
struct passwd *getpwent(void);
void           setpwent(void);
void           endpwent(void);
#endif
