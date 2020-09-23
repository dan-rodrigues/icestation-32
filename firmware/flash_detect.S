#include "boot_defines.S"

.global flash_detect

// Returns:
// a0:
//  - 00: Unrecognized
//  - 01: Winbond
//  - 02: ISSI

.equ MFID_WINDBOND, 0xef
.equ MFID_ISSI, 0x9d

flash_detect:
    // Read JEDEC ID
    li a0, 0x9f
    jal spi_transfer
    jal spi_transfer
    jal spi_complete_cmd

    li a1, MFID_WINDBOND
    bne a0, a1, try_issi

    li a0, RESULT_WINBOND
    jr (gp)

try_issi:
    li a1, MFID_ISSI
    bne a0, a1, unknown_flash

    li a0, RESULT_ISSI
    jr (gp)

unknown_flash:
    li a0, RESULT_UNKNOWN
    jr (gp)

