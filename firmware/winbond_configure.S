#include "boot_defines.S"

.global winbond_configure

winbond_configure:
    // Read SR2
    li a0, 0x35
    jal spi_transfer
    jal spi_transfer
    // SR2 |= QE
    ori s0, a0, FLASH_SR2_QE
    jal spi_complete_cmd

    // Volatile status reg write enable, immediately before the write
    li a0, 0x50
    jal spi_transfer
    jal spi_complete_cmd

    // Write updated SR2
    li a0, 0x31
    jal spi_transfer
    mv a0, s0
    jal spi_transfer

#ifdef QPI_MODE

    jal spi_complete_cmd

    // Enter QPI mode prior to the initial CRM command
    li a0, 0x38
    jal spi_transfer
    mv ra, gp
    j spi_complete_cmd

#else

    mv ra, gp
    j spi_complete_cmd

#endif