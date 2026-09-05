#ifndef _AI_SYS_MOUNT_H
#define _AI_SYS_MOUNT_H
int mount(char const*, char const*, char const*, unsigned long, void const*);
int umount(char const*);
#endif
