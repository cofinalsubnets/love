#pragma once
#define AT_PAGESZ    6
#define AT_PLATFORM 15
#define AT_HWCAP    16
#define AT_SECURE   23
#define AT_RANDOM   25
#define AT_HWCAP2   26
unsigned long getauxval(unsigned long);
