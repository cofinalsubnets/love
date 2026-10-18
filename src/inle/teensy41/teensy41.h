// Teensy 4.1 (i.MX RT1062, Cortex-M7, XIP from FlexSPI NOR) register map, bare metal: only the
// registers this board touches, from the RT1060 RM and PJRC's cores/teensy4
#pragma once
#include <stdint.h>

#define REG(a) (*(volatile uint32_t *)(uintptr_t)(a))

// memory map: RAM is OCRAM2; the TCMs stay at the boot default
#define FLASH_BASE  0x60000000u   // 8 MB QSPI NOR on Teensy 4.1
#define ITCM_BASE   0x00000000u
#define DTCM_BASE   0x20000000u
#define OCRAM2_BASE 0x20200000u   // 512 KB, always mapped (not FlexRAM-carved)
#define OCRAM2_SIZE (512u * 1024u)
#define PSRAM_BASE  0x70000000u   // optional external PSRAM (Teensy 4.1 pads)

#define CCM_BASE        0x400FC000u
#define CCM_ANALOG_BASE 0x400D8000u
#define IOMUXC_BASE     0x401F8000u
#define IOMUXC_GPR_BASE 0x400AC000u
#define LPUART6_BASE    0x40198000u   // Teensy "Serial1": pin0 RX / pin1 TX
#define GPT1_BASE       0x401EC000u
#define GPIO2_BASE      0x401BC000u   // pin 13 LED lives on GPIO2_IO03
#define SCB_VTOR        0xE000ED08u
#define SCB_CPACR       0xE000ED88u   // FPU coprocessor access control

#define CCM_CCGR1 (CCM_BASE + 0x6Cu)   // GPT1 gates (CG10 bus, CG11 serial)
#define CCM_CCGR3 (CCM_BASE + 0x74u)   // LPUART6 gate (CG3)
#define CCM_CSCDR1 (CCM_BASE + 0x24u)  // UART_CLK_SEL (bit6) + UART_CLK_PODF[5:0]

// core = 24 MHz * DIV_SELECT / 2 / (ARM_PODF+1); 600 = 24*100/2/2. each mux or divider
// write handshakes through CDHIPR
#define CCM_CCSR   (CCM_BASE + 0x0Cu)
#define CCM_CACRR  (CCM_BASE + 0x10u)  // ARM_PODF[2:0] = divide-minus-one
#define CCM_CBCDR  (CCM_BASE + 0x14u)
#define CCM_CBCMR  (CCM_BASE + 0x18u)
#define CCM_CDHIPR (CCM_BASE + 0x48u)
#define CCSR_PLL1_SW_CLK_SEL (1u << 2)     // 1 = step_clk, 0 = pll1_main
#define CBCDR_PERIPH_CLK_SEL (1u << 25)    // 1 = periph_clk2 (the parking lane)
#define CBCDR_AHB_PODF_MASK  (7u << 10)    // 0 = /1
#define CBCDR_IPG_PODF_MASK  (3u << 8)     // 3 = /4 (IPG tops out at 150 MHz)
#define CBCDR_IPG_PODF_DIV4  (3u << 8)
#define CBCMR_PRE_PERIPH_MASK (3u << 18)
#define CBCMR_PRE_PERIPH_PLL1 (3u << 18)   // 3 = the divided ARM PLL
#define CBCMR_PERIPH_CLK2_MASK (3u << 12)
#define CBCMR_PERIPH_CLK2_OSC  (1u << 12)  // 24 MHz osc while parked
#define CDHIPR_ARM_PODF_BUSY       (1u << 16)
#define CDHIPR_PERIPH_CLK_SEL_BUSY (1u << 5)
#define CDHIPR_AHB_PODF_BUSY       (1u << 1)
#define CCM_ANALOG_PLL_ARM (CCM_ANALOG_BASE + 0x00u)
#define PLL_ARM_LOCK      (1u << 31)
#define PLL_ARM_ENABLE    (1u << 13)
#define PLL_ARM_POWERDOWN (1u << 12)

// DCDC: 600 MHz wants 1.25 V
#define DCDC_REG0 0x40080000u
#define DCDC_REG3 0x4008000Cu
#define DCDC_REG0_STS_DC_OK (1u << 31)     // output settled at target
#define DCDC_REG3_TRG_MASK 0x1Fu           // V = 0.8 + TRG * 0.025
#define DCDC_TRG_1V25 18u
#define CCGR_ON(cg) (3u << (2u * (cg)))   // clock running in all modes
#define CSCDR1_UART_CLK_SEL_OSC (1u << 6) // 1 = 24 MHz osc, 0 = pll3 / 6 (80 MHz)
#define CSCDR1_UART_CLK_PODF_MASK 0x3Fu
#define OSC_HZ 24000000u                  // on-board crystal

#define LPUART_BAUD  (LPUART6_BASE + 0x10u)
#define LPUART_STAT  (LPUART6_BASE + 0x14u)
#define LPUART_CTRL  (LPUART6_BASE + 0x18u)
#define LPUART_DATA  (LPUART6_BASE + 0x1Cu)
#define LPUART_FIFO  (LPUART6_BASE + 0x28u)
#define LPUART_WATER (LPUART6_BASE + 0x2Cu)
#define LPUART_BAUD_OSR(n)  (((n) - 1u) << 24)   // oversampling ratio - 1
#define LPUART_BAUD_SBR(n)  ((n) & 0x1FFFu)       // baud modulo divisor
#define LPUART_BAUD_BOTHEDGE (1u << 17)
#define LPUART_STAT_TDRE (1u << 23)               // TX data register empty
#define LPUART_STAT_TC   (1u << 22)               // transmit COMPLETE (shifter drained)
#define LPUART_STAT_RDRF (1u << 21)               // RX data register full
#define LPUART_STAT_OR   (1u << 19)               // RX overrun: halts reception until cleared
#define LPUART_CTRL_TE   (1u << 19)
#define LPUART_CTRL_RE   (1u << 18)
#define LPUART_FIFO_TXFE (1u << 7)                // enable TX FIFO
#define LPUART_FIFO_RXFLUSH (1u << 14)            // flush the RX FIFO (write-1)
#define LPUART_STAT_ERR  ((1u << 19) | (1u << 18) | (1u << 17) | (1u << 16))   // OR | NF | FE | PF, all write-1-clear
#define LPUART_FIFO_RXFE (1u << 3)                // enable RX FIFO

// IOMUXC: the two console pads and the LED pad
#define IOMUXC_SW_MUX_GPIO_AD_B0_02 (IOMUXC_BASE + 0x0C4u)  // pin1 TX1 -> LPUART6_TX (ALT2)
#define IOMUXC_SW_MUX_GPIO_AD_B0_03 (IOMUXC_BASE + 0x0C8u)  // pin0 RX1 -> LPUART6_RX (ALT2)
#define IOMUXC_SW_MUX_GPIO_B0_03    (IOMUXC_BASE + 0x148u)  // pin13 LED -> GPIO2_IO03 (ALT5)
// the RX daisy chain: SELECT_INPUT lives in the second block, +0x400 + 0x150 (imxrt.h offset150)
#define IOMUXC_LPUART6_RX_SELECT    (IOMUXC_BASE + 0x550u)
#define MUX_ALT(n) (n)
#define MUX_SION (1u << 4)
// pad control, 0x1F0 past its SW_MUX_CTL: at the reset default a pad won't drive the line
#define IOMUXC_SW_PAD_GPIO_AD_B0_02 (IOMUXC_BASE + 0x2B4u)  // pin1 TX pad ctl
#define IOMUXC_SW_PAD_GPIO_AD_B0_03 (IOMUXC_BASE + 0x2B8u)  // pin0 RX pad ctl
#define PAD_CTL_UART 0x10B0u   // DSE6 + SPEED2 + keeper -- PJRC's UART pad config

// GPT1, free-running
#define GPT1_CR  (GPT1_BASE + 0x00u)
#define GPT1_PR  (GPT1_BASE + 0x04u)
#define GPT1_CNT (GPT1_BASE + 0x24u)
#define GPT_CR_EN     (1u << 0)
#define GPT_CR_ENMOD  (1u << 1)
#define GPT_CR_CLKSRC_24M (5u << 6)   // crystal oscillator (24 MHz)
#define GPT_CR_EN_24M (1u << 10)       // the crystal path's own enable: without it CNT sits at 0
#define GPT_CR_FRR    (1u << 9)        // free-run (no compare reset)
#define GPT_CR_SWR    (1u << 15)       // software reset
#define GPT1_CCGR_BUS    10            // CCGR1 CG10
#define GPT1_CCGR_SERIAL 11           // CCGR1 CG11

#define GPIO2_DR       (GPIO2_BASE + 0x00u)
#define GPIO2_GDIR     (GPIO2_BASE + 0x04u)
#define GPIO2_PSR      (GPIO2_BASE + 0x08u)
#define GPIO2_DR_SET   (GPIO2_BASE + 0x84u)
#define GPIO2_DR_CLEAR (GPIO2_BASE + 0x88u)
#define LED_BIT 3u                     // GPIO2_IO03 = Teensy pin 13

void clocks_init(void);
void serial_init(void);
void serial_putc(int c);
int  serial_getc(void);
int  serial_rx_ready(void);
uint32_t serial_rx_lost(void);   // inbound bytes the soft ring could not hold, and clears
void gpio_init(unsigned pin);
void gpio_set_dir(unsigned pin, int out);
void gpio_put(unsigned pin, int hi);
int  gpio_get(unsigned pin);

// the asm helpers (mkboot.l) -- mooncc has no inline asm on thumb2
void arm_dsb_isb(void);
void arm_dsb(void);
void arm_wfi(void);
void arm_bkpt(void);
