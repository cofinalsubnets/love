// RP2350 register map (Cortex-M33, no Pico SDK): only what the frontend touches, from the
// datasheet's register listings. the names are ../rp2040/rp2040.h's, so usb.c and probe.c
// build against either chip
#pragma once
#include <stdint.h>

#define REG(a) (*(volatile uint32_t *)(a))
// atomic access aliases: write to base+offset
#define REG_XOR 0x1000u
#define REG_SET 0x2000u
#define REG_CLR 0x3000u

// peripheral bases
#define CLOCKS_BASE     0x40010000u
#define RESETS_BASE     0x40020000u
#define IO_BANK0_BASE   0x40028000u
#define PADS_BANK0_BASE 0x40038000u
#define XOSC_BASE       0x40048000u
#define PLL_SYS_BASE    0x40050000u
#define PLL_USB_BASE    0x40058000u
#define UART0_BASE      0x40070000u
#define TIMER_BASE      0x400b0000u   // timer0
#define TICKS_BASE      0x40108000u
#define SIO_BASE        0xd0000000u
#define PPB_BASE        0xe0000000u
#define CPACR_ADDR      (PPB_BASE + 0xed88u)

// RESETS
#define RESETS_RESET      (RESETS_BASE + 0x0u)
#define RESETS_RESET_DONE (RESETS_BASE + 0x8u)
#define RST_IO_BANK0   (1u << 6)
#define RST_PADS_BANK0 (1u << 9)
#define RST_PLL_SYS    (1u << 14)
#define RST_PLL_USB    (1u << 15)
#define RST_TIMER      (1u << 23)
#define RST_UART0      (1u << 26)
#define RST_USBCTRL    (1u << 28)

// XOSC (12 MHz crystal)
#define XOSC_CTRL    (XOSC_BASE + 0x0u)
#define XOSC_STATUS  (XOSC_BASE + 0x4u)
#define XOSC_STARTUP (XOSC_BASE + 0xcu)
#define XOSC_CTRL_ENABLE   (0xfabu << 12)
#define XOSC_CTRL_1_15MHZ  0xaa0u
#define XOSC_STATUS_STABLE (1u << 31)

// PLL_SYS
#define PLL_CS       (PLL_SYS_BASE + 0x0u)
#define PLL_PWR      (PLL_SYS_BASE + 0x4u)
#define PLL_FBDIV    (PLL_SYS_BASE + 0x8u)
#define PLL_PRIM     (PLL_SYS_BASE + 0xcu)
#define PLL_CS_LOCK      (1u << 31)
#define PLL_PWR_VCOPD    (1u << 5)
#define PLL_PWR_POSTDIVPD (1u << 3)
#define PLL_PWR_DSMPD    (1u << 2)
#define PLL_PWR_PD       (1u << 0)

// CLOCKS: the divisors' integer part moved up to bit 16, and clk_usb's pair to 0x60
#define CLK_REF_CTRL      (CLOCKS_BASE + 0x30u)
#define CLK_REF_DIV       (CLOCKS_BASE + 0x34u)
#define CLK_REF_SELECTED  (CLOCKS_BASE + 0x38u)
#define CLK_SYS_CTRL      (CLOCKS_BASE + 0x3cu)
#define CLK_SYS_DIV       (CLOCKS_BASE + 0x40u)
#define CLK_SYS_SELECTED  (CLOCKS_BASE + 0x44u)
#define CLK_PERI_CTRL     (CLOCKS_BASE + 0x48u)
#define CLK_PERI_SELECTED (CLOCKS_BASE + 0x50u)
#define CLK_USB_CTRL      (CLOCKS_BASE + 0x60u)
#define CLK_USB_DIV       (CLOCKS_BASE + 0x64u)
#define CLK_REF_SRC_XOSC   0x2u
#define CLK_SYS_SRC_REF    0x0u
#define CLK_SYS_SRC_AUX    0x1u
#define CLK_SYS_AUX_PLLSYS 0x0u
#define CLK_PERI_AUX_XOSC  0x4u
#define CLK_PERI_ENABLE    (1u << 11)
#define CLK_AUXSRC_LSB     5
#define CLK_DIV_1          (1u << 16)

// TICKS: timer0's and the watchdog's microsecond ticks, clk_ref cycles a tick
#define TICKS_TIMER0_CTRL     (TICKS_BASE + 0x18u)
#define TICKS_TIMER0_CYCLES   (TICKS_BASE + 0x1cu)
#define TICKS_WATCHDOG_CTRL   (TICKS_BASE + 0x30u)
#define TICKS_WATCHDOG_CYCLES (TICKS_BASE + 0x34u)

// IO_BANK0 / PADS_BANK0: a pad comes up isolated, ISO cleared once it is set up
#define IO_BANK0_GPIO_CTRL(n) (IO_BANK0_BASE + 0x4u + (n) * 0x8u)
#define PADS_BANK0_GPIO(n)    (PADS_BANK0_BASE + 0x4u + (n) * 0x4u)
#define PADS_PDE (1u << 2)
#define PADS_PUE (1u << 3)
#define PADS_IE  (1u << 6)
#define PADS_OD  (1u << 7)
#define PADS_ISO (1u << 8)
#define IO_FUNC_UART 2u      // GPIO0/1 -> UART0 TX/RX
#define IO_FUNC_SIO  5u

// UART0 (PL011), as the rp2040's
#define UART_DR    (UART0_BASE + 0x00u)
#define UART_FR    (UART0_BASE + 0x18u)
#define UART_IBRD  (UART0_BASE + 0x24u)
#define UART_FBRD  (UART0_BASE + 0x28u)
#define UART_LCR_H (UART0_BASE + 0x2cu)
#define UART_CR    (UART0_BASE + 0x30u)
#define UART_FR_TXFF (1u << 5)
#define UART_FR_RXFE (1u << 4)
#define UART_FR_BUSY (1u << 3)
#define UART_LCR_H_SPS    (1u << 7)
#define UART_LCR_H_WLEN_8 (0x3u << 5)
#define UART_LCR_H_FEN    (1u << 4)
#define UART_LCR_H_STP2   (1u << 3)
#define UART_LCR_H_EPS    (1u << 2)
#define UART_LCR_H_PEN    (1u << 1)
#define UART_CR_UARTEN (1u << 0)
#define UART_CR_TXE    (1u << 8)
#define UART_CR_RXE    (1u << 9)

// SIO
#define SIO_GPIO_IN      (SIO_BASE + 0x04u)
#define SIO_GPIO_OUT_SET (SIO_BASE + 0x18u)
#define SIO_GPIO_OUT_CLR (SIO_BASE + 0x20u)
#define SIO_GPIO_OE_SET  (SIO_BASE + 0x38u)
#define SIO_GPIO_OE_CLR  (SIO_BASE + 0x40u)

// TIMER0 (64-bit microsecond)
#define TIMER_TIMEHR (TIMER_BASE + 0x08u)
#define TIMER_TIMELR (TIMER_BASE + 0x0cu)

// rp2350.c
void clocks_init(void);
void serial_putc(int c);   // the board's console, main.c's
uint32_t clock_ms(void);
void chip_uid(uint8_t id[8]);
void rom_bootsel(void);
void gpio_init(unsigned pin);
void gpio_set_dir(unsigned pin, int out);
void gpio_put(unsigned pin, int hi);
int  gpio_get(unsigned pin);
