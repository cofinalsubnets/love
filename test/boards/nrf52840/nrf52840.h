// seeed xiao nrf52840 (sense) register map, only what this port touches: values from the
// nrf52840 product specification, board facts from the xiao schematic. a single-precision
// FPU, so `mooncc -t thumb2sp`: f64 arithmetic softens to __aeabi_* calls
#pragma once
#include <stdint.h>

#define REG(a) (*(volatile uint32_t *)(uintptr_t)(a))

// --- memory map ----------------------------------------------------------
// the adafruit uf2 bootloader keeps the mbr and softdevice below the app and itself at the
// top of flash; the app is never handed the softdevice, so its ram reservation stays clear.
// the app here is loader.c, its ram sram's top 16 KB, and the battery runs below it
#define APP_BASE  0x00027000u
#define SRAM_BASE 0x20000000u
#define SRAM_SIZE (256u * 1024u)

// --- FICR: the chip's 64-bit device id --------------------------------------
#define FICR_DEVICEID0 0x10000060u
#define FICR_DEVICEID1 0x10000064u

// --- CLOCK: the 64 MHz crystal, which usb wants ------------------------------
#define CLOCK_HFCLKSTART   0x40000000u
#define CLOCK_HFSTARTED    0x40000100u
#define CLOCK_HFCLKSTAT    0x4000040Cu
#define HFCLKSTAT_XTAL     (1u << 0)
#define HFCLKSTAT_RUNNING  (1u << 16)

// --- GPIO ----------------------------------------------------------------
#define P0 0x50000000u
#define GPIO_OUTSET(p) ((p) + 0x508u)
#define GPIO_OUTCLR(p) ((p) + 0x50Cu)
#define GPIO_DIRSET(p) ((p) + 0x518u)
#define LED_RED   26u    // P0, low lights it
#define LED_GREEN 30u
#define LED_BLUE  6u

// --- TIMER0: the 32-bit free-running microsecond counter ------------------
#define TIMER0 0x40008000u
#define TIMER_START     (TIMER0 + 0x000u)
#define TIMER_CLEAR     (TIMER0 + 0x00Cu)
#define TIMER_CAPTURE0  (TIMER0 + 0x040u)
#define TIMER_MODE      (TIMER0 + 0x504u)
#define TIMER_BITMODE   (TIMER0 + 0x508u)
#define TIMER_PRESCALER (TIMER0 + 0x510u)
#define TIMER_CC0       (TIMER0 + 0x540u)

// --- POWER: usb's regulator, and the retained register the bootloader reads after a reset
#define POWER_USBREGSTATUS 0x40000438u   // bit 1: the regulator's output ready
#define POWER_GPREGRET 0x4000051Cu
#define GPREGRET_UF2   0x57u     // come up as the uf2 drive

// --- core ----------------------------------------------------------------
#define SCB_AIRCR  0xE000ED0Cu
#define SCB_CPACR  0xE000ED88u

// mkboot.l
void arm_dsb_isb(void);
void arm_wfi(void);
void arm_irq_off(void);

// nrf52840.c
void clocks_init(void);
int  clock_xtal(void);
void timer_init(void);
void led_init(void);
void serial_putc(int c);
uint32_t clock_ms(void);
void led_put(uint32_t pin, int on);
void reset(void);
void reboot_uf2(void);

// usb.c
void usb_init(void);
void usb_off(void);
void usb_poll(void);
void usb_putc(int c);
void usb_flush(void);
int  usb_up(void);
int  usb_rx_ready(void);
int  usb_getc(void);

// the image's, main.c or loader.c: what 134 baud on the console asks
void usb_reboot(void);
