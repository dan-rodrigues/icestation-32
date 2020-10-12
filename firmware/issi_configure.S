.global issi_configure

# QPI not supported (yet) for ISSI config

issi_configure:
    // Read status register
    li a0, 0x05
    jal spi_transfer
    jal spi_transfer
    // SR |= QE
    ori s0, a0, 0x40
    jal spi_complete_cmd

    // Write-enable SR
    li a0, 0x06
    jal spi_transfer
    jal spi_complete_cmd

    // Write status register
    li a0, 0x01
    jal spi_transfer
    mv a0, s0
    jal spi_transfer
    mv ra, gp
    j spi_complete_cmd

