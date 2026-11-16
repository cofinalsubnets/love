// bbc micro:bit v2 (nrf52833) register map, only what this port touches: values from the
// nrf52833 product specification, board facts from the v2 schematic. a single-precision
// FPU, so `mooncc -t thumb2sp`: f64 arithmetic softens to __aeabi_* calls
#pragma once
#include <stdint.h>

#define REG(a) (*(volatile uint32_t *)(uintptr_t)(a))

// --- memory map ----------------------------------------------------------
// no bootloader on the target: the daplink beside it writes flash from 0
#define APP_BASE  0x00000000u
#define SRAM_BASE 0x20000000u
#define SRAM_SIZE (128u * 1024u)

// --- CLOCK: the 32 MHz crystal, for the uart's baud -------------------------
#define CLOCK_HFCLKSTART   0x40000000u
#define CLOCK_HFSTARTED    0x40000100u
#define CLOCK_HFCLKSTAT    0x4000040Cu
#define HFCLKSTAT_XTAL     (1u << 0)
#define HFCLKSTAT_RUNNING  (1u << 16)

// --- GPIO ----------------------------------------------------------------
#define P0 0x50000000u
#define P1 0x50000300u
#define GPIO_OUTSET(p) ((p) + 0x508u)
#define GPIO_OUTCLR(p) ((p) + 0x50Cu)
#define GPIO_DIRSET(p) ((p) + 0x518u)
#define GPIO_CNF(p, n) ((p) + 0x700u + 4u * (n))
// the 5x5 matrix: a row driven high and a column held low light the led between them.
// rows P0.21 22 15 24 19, columns P0.28 11 31, P1.05, P0.30
#define LED_N   5
#define LED_MAX 8        // a cell's level: 0 dark .. LED_MAX full

// --- UART0, the legacy non-dma uart: P0.06 TX, P1.08 RX, the daplink's vcp --
#define UART0 0x40002000u
#define UART_STARTRX  (UART0 + 0x000u)
#define UART_STARTTX  (UART0 + 0x008u)
#define UART_RXDRDY   (UART0 + 0x108u)
#define UART_TXDRDY   (UART0 + 0x11Cu)
#define UART_ERROR    (UART0 + 0x124u)
#define UART_ERRORSRC (UART0 + 0x480u)
#define UART_ENABLE   (UART0 + 0x500u)
#define UART_PSELRTS  (UART0 + 0x508u)
#define UART_PSELTXD  (UART0 + 0x50Cu)
#define UART_PSELCTS  (UART0 + 0x510u)
#define UART_PSELRXD  (UART0 + 0x514u)
#define UART_RXD      (UART0 + 0x518u)
#define UART_TXD      (UART0 + 0x51Cu)
#define UART_BAUDRATE (UART0 + 0x524u)
#define UART_CONFIG   (UART0 + 0x56Cu)
#define UART_BAUD_115200 0x01D7E000u
#define TX_PIN 6u        // on P0
#define RX_PIN 8u        // on P1
#define PSEL_P1(n) ((1u << 5) | (n))
#define PSEL_OFF   0xFFFFFFFFu

// --- TIMER0: the 32-bit free-running microsecond counter ------------------
#define TIMER0 0x40008000u
#define TIMER_START     (TIMER0 + 0x000u)
#define TIMER_CLEAR     (TIMER0 + 0x00Cu)
#define TIMER_CAPTURE0  (TIMER0 + 0x040u)
#define TIMER_MODE      (TIMER0 + 0x504u)
#define TIMER_BITMODE   (TIMER0 + 0x508u)
#define TIMER_PRESCALER (TIMER0 + 0x510u)
#define TIMER_CC0       (TIMER0 + 0x540u)

// --- core ----------------------------------------------------------------
#define SCB_VTOR   0xE000ED08u
#define SCB_CPACR  0xE000ED88u
#define NVIC_ICER0 0xE000E180u
#define NVIC_ICPR0 0xE000E280u

// mkboot.l
void arm_dsb_isb(void);
void arm_wfi(void);
void arm_irq_off(void);

// microbit.c
void clocks_init(void);
int  clock_xtal(void);
void timer_init(void);
void led_init(void);
void serial_init(void);
void serial_putc(int c);
int  serial_rx_ready(void);
int  serial_getc(void);
uint32_t clock_ms(void);
uint32_t clock_us(void);
void led_put(int on);
void led_scan(uint8_t const *lv);
