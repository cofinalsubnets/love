#pragma once
#define CLONE_NEWNS   131072
#define CLONE_NEWUSER 268435456
int unshare(int);
