#pragma once
int mount(char const*, char const*, char const*, unsigned long, void const*), umount(char const*),
    umount2(char const*, int);
