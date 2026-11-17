#include "../impl.h"

/* no name database: every lookup misses, so callers fall back to numeric ids */
struct passwd *getpwuid(uid_t u) { return 0; }
struct passwd *getpwnam(char const *n) { return 0; }
struct group *getgrgid(gid_t g) { return 0; }
struct group *getgrnam(char const *n) { return 0; }
struct passwd *getpwent(void) { return 0; }
struct group *getgrent(void) { return 0; }
void setpwent(void) { }
void endpwent(void) { }
void setgrent(void) { }
void endgrent(void) { }
