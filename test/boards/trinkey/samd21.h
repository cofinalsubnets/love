// the atsamd21e18's registers this port touches (the datasheet's names), and the board's words
#pragma once
#include <stdint.h>

#define REG(a)   (*(volatile uint32_t *) (uintptr_t) (a))
#define REG16(a) (*(volatile uint16_t *) (uintptr_t) (a))
#define REG8(a)  (*(volatile uint8_t *) (uintptr_t) (a))

// --- the core -------------------------------------------------------------
#define ICSR_ADDR   0xE000ED04u
#define ICSR_PENDSTCLR (1u << 25)
#define VTOR_ADDR   0xE000ED08u
#define NVIC_ICER   0xE000E180u
#define NVIC_ICPR   0xE000E280u
#define AIRCR_ADDR  0xE000ED0Cu
#define SYST_CSR    0xE000E010u
#define SYST_RVR    0xE000E014u
#define SYST_CVR    0xE000E018u

// --- PM: the bus clocks ---------------------------------------------------
#define PM_AHBMASK   0x40000414u
#define PM_APBBMASK  0x4000041Cu
#define AHB_USB      (1u << 6)
#define APBB_USB     (1u << 5)

// --- SYSCTRL: the 8 MHz rc and the DFLL48M --------------------------------
#define SYSCTRL_PCLKSR   0x4000080Cu
#define SYSCTRL_OSC8M    0x40000820u
#define SYSCTRL_DFLLCTRL 0x40000824u
#define SYSCTRL_DFLLVAL  0x40000828u
#define SYSCTRL_DFLLMUL  0x4000082Cu
#define PCLKSR_DFLLRDY   (1u << 4)
#define DFLL_ENABLE  (1u << 1)
#define DFLL_MODE    (1u << 2)     // closed loop
#define DFLL_USBCRM  (1u << 5)     // usb start of frame the reference
#define DFLL_CCDIS   (1u << 8)

// --- GCLK -----------------------------------------------------------------
#define GCLK_STATUS  0x40000C01u
#define GCLK_CLKCTRL 0x40000C02u
#define GCLK_GENCTRL 0x40000C04u
#define GCLK_GENDIV  0x40000C08u
#define GCLK_SYNCBUSY (1u << 7)
#define GEN_SRC_ULP32K (3u << 8)
#define GEN_SRC_OSC8M  (6u << 8)
#define GEN_SRC_DFLL   (7u << 8)
#define GEN_GENEN      (1u << 16)
#define GEN_IDC        (1u << 17)
#define GEN_DIVSEL     (1u << 20)
#define CLK_CLKEN      (1u << 14)
#define CLK_ID_WDT     3u
#define CLK_ID_USB     6u

// --- WDT ------------------------------------------------------------------
#define WDT_CTRL     0x40001000u
#define WDT_CONFIG   0x40001001u
#define WDT_STATUS   0x40001007u
#define WDT_CLEAR    0x40001008u

// --- NVMCTRL, and the calibration words in the nvm software area ----------
#define NVM_CTRLB    0x41004004u
#define NVM_CAL1     0x00806024u   // bits 13.. usb transn, transp, trim; 26.. the dfll's coarse
#define NVM_UID0     0x0080A00Cu
#define NVM_UID1     0x0080A040u   // then 0x0080A044, 0x0080A048

// --- PORT: pin functions --------------------------------------------------
#define PORTA_PMUX(n)   (0x41004430u + (n))
#define PORTA_PINCFG(n) (0x41004440u + (n))

// --- the uf2 bootloader's double tap: this word at sram's last keeps a reset in it
#define BOOT_TAP     0x20007FFCu
#define BOOT_MAGIC   0xF01669EFu

void clocks_init(void);
void wdt_feed(void);
uint32_t clock_ms(void);
void chip_uid(uint32_t id[4]);
void boot_loader(void);
