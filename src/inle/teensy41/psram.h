// FlexSPI2 external PSRAM at 0x70000000: psram_init answers total MB (0/8/16); psram_chip_id
// the raw probe id (0x..5D0D / 0x..5D9D a chip, 0 or 0xFFFF.. absent or bad solder)
#pragma once
#include <stdint.h>
uint32_t psram_init(void);
uint32_t psram_chip_id(int slot);
// the MB psram_init found, read back off the controller: for an image running in the psram,
// which a second psram_init would pull from under itself
uint32_t psram_mb(void);
