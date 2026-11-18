#pragma once
#define PR_SET_PDEATHSIG  1
#define PR_GET_PDEATHSIG  2
#define PR_SET_DUMPABLE   4
#define PR_SET_NAME      15
#define PR_GET_NAME      16
#define PR_SET_NO_NEW_PRIVS 38
int prctl(int, ...);
