#include "boot_defines.S"

.global _start

.global spi_transfer
.global spi_complete_cmd

_start:
    la sp, CPU_RAM_BASE + 0x10000

#ifdef BOOT_DISPLAY
    jal bp_print_init

#ifdef BOOT_PROMPT
    // "Press button..."
    li a0, 0x2041   
    la a1, prompt_string
    jal bp_print

    sw a0, (a1)
    la a0, PAD_DATA
    la a2, LED_DATA
loop_wait_button:
    // LED counter on upper bits
    addi t0, t0, 1
    srli t1, t0, 16
    sw t1, (a2)
    
    // Did user press button yet?
    lw a1, (a0)
    andi a1, a1, PAD_USER_BUTTON
    beqz a1, loop_wait_button

    // LEDs cleared once user advances
    sw x0, (a2)
#endif

    // "Starting..."
    li a0, 0x2041
    la a1, starting_string
    jal bp_print
#endif

// Flash configuration:

    la a2, FLASH_CTRL_BASE

    // Begin with deactivated flash
    li a0, FLASH_CTRL_CSN
    sh a0, (a2)

    // Activate flash, clock low, /WP and /HOLD high
    li a0, FLASH_CTRL_ACTIVE | | (0xc << FLASH_CTRL_IN_EN_SHIFT) | 0xc
    sh a0, (a2)

    // Power up
    li a0, 0xab
    jal spi_transfer
    jal spi_complete_cmd

#ifdef ASSUME_WINBOND
    jal gp, winbond_configure
#else

    // Determine flash based on MFID
    jal gp, flash_detect
    li a1, RESULT_WINBOND
    bne a0, a1, try_issi

    li a0, 0x2041 + (2 * 0x40)
    la a1, winbond_flash_string
    jal bp_print
    li a2, FLASH_CTRL_BASE

    jal gp, winbond_configure
    j crm_setup

try_issi:
    li a1, RESULT_ISSI
    bne a0, a1, unknown_flash

    li a0, 0x2041 + (2 * 0x40)
    la a1, issi_flash_string
    jal bp_print
    li a2, FLASH_CTRL_BASE

    jal gp, issi_configure
    j crm_setup

unknown_flash:
    li a0, 0x2041 + (2 * 0x40)
    la a1, unknown_flash_string
    jal bp_print
    ebreak

#endif

crm_setup:
    // Quad read (setup for hardware flash controller)
    li a0, 0xeb

#ifdef QPI_MODE
    jal qpi_transfer
#else
    jal spi_transfer
#endif

    // Dummy address used to initiate CRM, doesn't matter where
    li a0, 0x20
    jal qpi_transfer
    li a0, 0
    jal qpi_transfer
    li a0, 0
    jal qpi_transfer
    li a0, CRM_BYTE
    jal qpi_transfer

#ifndef QPI_MODE

    // 4x dummy bytes
    jal qpi_transfer
    jal qpi_transfer

#endif

    // CPU has finished flash config, deassert /CS, hand back flash to flash controller
    li a1, FLASH_CTRL_CSN
    sh a1, (a2)

#ifndef BOOT_NO_IPL
// IPL:

    la a0, IPL_START
    la a1, IPL_END
    la a2, CPU_RAM_BASE
loop_ipl:
    lw a3, (a0)
    sw a3, (a2)
    addi a0, a0, 4
    addi a2, a2, 4
    blt a0, a1, loop_ipl
#endif

    j CPU_RAM_BASE

// Sends one QPI byte
// a0: byte to send

qpi_transfer:
    li t0, 0
    li t1, 2
    li t2, 0

loop_send_qpi:
    // Lower clk, set output nybble
    li a1, FLASH_CTRL_ACTIVE | (0xf << FLASH_CTRL_IN_EN_SHIFT)
    andi t3, a0, 0xf0
    slli a0, a0, 4
    srli t3, t3, 4
    or a1, a1, t3
    sh a1, (a2)

    // raise clk
    ori a1, a1, FLASH_CTRL_CLK
    sh a1, (a2)

    add t0, t0, 1
    bne t0, t1, loop_send_qpi

    // disable outputs, lower clk
    li t0, FLASH_CTRL_ACTIVE
    sh t0, (a2)

    ret

// Sends and receives one SPI byte 
// a0: byte to send
// Returns: byte received

spi_transfer:
    li t0, 0
    li t1, 8
    li t2, 0

loop_send_spi:
    // Lower clk, drive all bits except MISO
    // (|= 0xc) is to keep /WP and /HOLD high
    // Winbond parts don't seem affected, ISSI parts may be
    li a1, FLASH_CTRL_ACTIVE | (0xd << FLASH_CTRL_IN_EN_SHIFT) | 0xc
    andi t3, a0, 0x80
    add a0, a0, a0
    srli t3, t3, 7
    or a1, a1, t3
    sh a1, (a2)

    // Read input bit
    add t2, t2, t2
    lh t3, (a2)
    andi t3, t3, (1 << 1)
    srli t3, t3, 1
    or t2, t2, t3

    // Raise clk
    ori a1, a1, FLASH_CTRL_CLK
    sh a1, (a2)

    add t0, t0, 1
    bne t0, t1, loop_send_spi

    // Disable outputs, except /WP and /HOLD
    li t0, FLASH_CTRL_ACTIVE | (0xc << FLASH_CTRL_IN_EN_SHIFT) | 0xc
    sh t0, (a2)

    // a0 = read byte
    mv a0, t2
    
    ret

// Deasserts, then reasserts CSN to make the flash ready for next command

spi_complete_cmd:
    li t0, FLASH_CTRL_CSN | FLASH_CTRL_ACTIVE
    sh t0, (a2)
    li t0, FLASH_CTRL_ACTIVE | (0xc << FLASH_CTRL_IN_EN_SHIFT) | 0xc
    sh t0, (a2)

    ret

prompt_string:
    .string "PRESS BUTTON   "
starting_string:
    .string "STARTING NOW   "

unknown_flash_string:
    .string "UNRECOGNIZED FLASH VENDOR  "

winbond_flash_string:
    .string "WINBOND"
issi_flash_string:
    .string "ISSI   "

.align 4
