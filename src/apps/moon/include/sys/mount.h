#pragma once
int mount(char const*, char const*, char const*, unsigned long, void const*);
int umount(char const*);
int umount2(char const*, int);
