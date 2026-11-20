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
#define NVMC_ICACHECNF     0x4001E540u   // the flash's instruction cache, off at reset

// --- GPIO ----------------------------------------------------------------
#define P0 0x50000000u
#define P1 0x50000300u
#define GPIO_OUTSET(p) ((p) + 0x508u)
#define GPIO_OUTCLR(p) ((p) + 0x50Cu)
#define GPIO_IN(p)     ((p) + 0x510u)
#define GPIO_DIRSET(p) ((p) + 0x518u)
#define GPIO_CNF(p, n) ((p) + 0x700u + 4u * (n))
// the 5x5 matrix: a row driven high and a column held low light the led between them.
// rows P0.21 22 15 24 19, columns P0.28 11 31, P1.05, P0.30
#define LED_N   5
#define LED_MAX 8        // a cell's level: 0 dark .. LED_MAX full
// the logo's touch pad P1.04, its 10M pull-up charging the pad; the speaker's drive P0.00
#define LOGO_PIN  4u     // on P1
#define SPKR_PIN  0u     // on P0
// the buttons, low when held: A the left P0.14, B the right P0.23
#define BTN_A     14u
#define BTN_B     23u

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
#define SCB_CPACR  0xE000ED88u

// mkboot.l
void arm_dsb_isb(void);
void arm_wfi(void);
void arm_irq_off(void);

// --- TEMP: the die's temperature in quarter degrees --------------------------
#define TEMP_START   0x4000C000u
#define TEMP_DATARDY 0x4000C100u
#define TEMP_TEMP    0x4000C508u

// --- RADIO, ble 1 Mbit: only the advertising transmit --------------------------
#define RADIO_TXEN        0x40001000u
#define RADIO_DISABLE     0x40001010u
#define RADIO_DISABLED    0x40001110u
#define RADIO_SHORTS      0x40001200u
#define RADIO_PACKETPTR   0x40001504u
#define RADIO_FREQUENCY   0x40001508u
#define RADIO_TXPOWER     0x4000150Cu
#define RADIO_MODE        0x40001510u
#define RADIO_PCNF0       0x40001514u
#define RADIO_PCNF1       0x40001518u
#define RADIO_BASE0       0x4000151Cu
#define RADIO_PREFIX0     0x40001524u
#define RADIO_TXADDRESS   0x4000152Cu
#define RADIO_CRCCNF      0x40001534u
#define RADIO_CRCPOLY     0x40001538u
#define RADIO_CRCINIT     0x4000153Cu
#define RADIO_DATAWHITEIV 0x40001554u
#define FICR_DEVICEADDR0  0x100000A4u
#define FICR_DEVICEADDR1  0x100000A8u
#define ADV_PDU_MAX 39   // header, length, the 6-byte address and 31 bytes of ad data

// --- PWM0, the speaker's samples: two sequences of duties by EasyDMA, ping-ponged ---
#define PWM0 0x4001C000u
#define PWM_TASKS_STOP       (PWM0 + 0x004u)
#define PWM_TASKS_SEQSTART0  (PWM0 + 0x008u)
#define PWM_EVENTS_STOPPED   (PWM0 + 0x104u)
#define PWM_EVENTS_SEQEND(i) (PWM0 + 0x110u + 4u * (i))
#define PWM_EVENTS_LOOPSDONE (PWM0 + 0x11Cu)
#define PWM_SHORTS           (PWM0 + 0x200u)
#define PWM_ENABLE           (PWM0 + 0x500u)
#define PWM_MODE             (PWM0 + 0x504u)
#define PWM_COUNTERTOP       (PWM0 + 0x508u)
#define PWM_PRESCALER        (PWM0 + 0x50Cu)
#define PWM_DECODER          (PWM0 + 0x510u)
#define PWM_LOOP             (PWM0 + 0x514u)
#define PWM_SEQ_PTR(i)       (PWM0 + 0x520u + 0x20u * (i))
#define PWM_SEQ_CNT(i)       (PWM0 + 0x524u + 0x20u * (i))
#define PWM_SEQ_REFRESH(i)   (PWM0 + 0x528u + 0x20u * (i))
#define PWM_SEQ_ENDDELAY(i)  (PWM0 + 0x52Cu + 0x20u * (i))
#define PWM_PSEL_OUT0        (PWM0 + 0x560u)
#define PWM_TOP 400u     // 16 MHz over 400: a 40 kHz carrier
#define PWM_RATE 10000u  // each duty held four periods: 10 kHz samples

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
void led_scan(uint8_t const *lv, uint32_t *noise);
uint32_t logo_us(void);
int buttons(void);
int32_t temp_read(void);
void ble_init(void);
void ble_addr(uint8_t *a);
void ble_adv(uint8_t const *pdu);
void pwm_start(uint16_t const *a, uint16_t const *b, uint32_t n);
int  pwm_ended(int i);
void pwm_stop(void);
