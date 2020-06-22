.global _start

.equ CPU_RAM_BASE, 0x00000
.equ FLASH_CTRL_BASE, 0x70000
.equ FLASH_BASE, 0x80000

.equ IPL_LENGTH, 0x10000
.equ IPL_START, FLASH_BASE
.equ IPL_END, IPL_START + IPL_LENGTH

.equ FLASH_CTRL_ACTIVE, (1 << 15)
.equ FLASH_CTRL_CLK, (1 << 8)
.equ FLASH_CTRL_CSN, (1 << 9)
.equ FLASH_CTRL_IN_SHIFT, 0
.equ FLASH_CTRL_IN_EN_SHIFT, 4

.equ FLASH_SR2_QE, (1 << 1)

#define QPI_MODE 0

_start:

// Enable QE bit:

    la a2, FLASH_CTRL_BASE

    li a0, (~FLASH_CTRL_ACTIVE & FLASH_CTRL_ACTIVE) | FLASH_CTRL_CLK
    sh a0, (a2)

    // CSN low, clock high
    li a0, FLASH_CTRL_ACTIVE | FLASH_CTRL_CLK
    sh a0, (a2)

    // power up
    li a0, 0xab
    jal spi_transfer
    jal spi_complete_cmd

    // read SR2
    li a0, 0x35
    jal spi_transfer
    jal spi_transfer
    // SR2 |= QE
    ori s0, a0, FLASH_SR2_QE
    jal spi_complete_cmd

    // volatile status reg write enable, immediately before the write
    li a0, 0x50
    jal spi_transfer
    jal spi_complete_cmd

    // write updated SR2
    li a0, 0x31
    jal spi_transfer
    mv a0, s0
    jal spi_transfer
    jal spi_complete_cmd

#if QPI_MODE

    // enter QPI mode prior to the initial CRM command
    li a0, 0x38
    jal spi_transfer
    jal spi_complete_cmd

#endif

// CRM setup

    // Quad read (setup for hardware flash controller)
    li a0, 0xeb

#if QPI_MODE
    jal qpi_transfer
#else
    jal spi_transfer
#endif

    // dummy address
    li a0, 0x10 // (0x100000, in defined range)
    jal qpi_transfer
    li a0, 0
    jal qpi_transfer
    li a0, 0
    jal qpi_transfer
    // M5-4 = 2'b10 to enable CRM
    li a0, 0x20
    jal qpi_transfer

#if !QPI_MODE

    // 4x dummy bytes
    jal qpi_transfer
    jal qpi_transfer

#endif

    // CPU has finished flash config, deassert /CS, hand back flash to flash controller
    li a1, FLASH_CTRL_CSN | FLASH_CTRL_CLK
    sh a1, (a2)

// IPL:

    la a0, IPL_START
    la a1, IPL_END
    la a2, CPU_RAM_BASE
    bge a0, a1, trap
loop_ipl:
    lw a3, (a0)
    sw a3, (a2)
    addi a0, a0, 4
    addi a2, a2, 4
    blt a0, a1, loop_ipl

loop:
    j CPU_RAM_BASE

// a0: byte to send
// returns: (nothing)

qpi_transfer:
    li t0, 0
    li t1, 2
    li t2, 0
loop_send_qpi:
    // negedge..

    // lower clk
    li a1, FLASH_CTRL_ACTIVE | (0xf << FLASH_CTRL_IN_EN_SHIFT)

    // set output nybble
    andi t3, a0, 0xf0
    slli a0, a0, 4
    srli t3, t3, 4
    or a1, a1, t3
    sh a1, (a2)

    // posedge..
    // nothing to read as IOs are all output

    // raise clk
    ori a1, a1, FLASH_CTRL_CLK
    sh a1, (a2)

    add t0, t0, 1
    bne t0, t1, loop_send_qpi

    // disable outputs
    li t0, FLASH_CTRL_ACTIVE | FLASH_CTRL_CLK
    sh t0, (a2)

    ret

// a0: byte to send
// returns: byte received

spi_transfer:
    li t0, 0
    li t1, 8
    li t2, 0
loop_send_spi:
    // negedge..

    // lower clk
    li a1, FLASH_CTRL_ACTIVE | (1 << FLASH_CTRL_IN_EN_SHIFT)

    // set output bit
    andi t3, a0, 0x80
    add a0, a0, a0
    srli t3, t3, 7
    or a1, a1, t3
    sh a1, (a2)

    // posedge..

    // read input bit
    add t2, t2, t2
    lh t3, (a2)
    andi t3, t3, (1 << 1)
    srli t3, t3, 1
    or t2, t2, t3

    // raise clk
    ori a1, a1, FLASH_CTRL_CLK
    sh a1, (a2)

    add t0, t0, 1
    bne t0, t1, loop_send_spi

    // a0 = read byte
    mv a0, t2

    ret

// deasserts, then reasserts CSN to make the flash ready for another command

spi_complete_cmd:
    li t0, FLASH_CTRL_CSN | FLASH_CTRL_ACTIVE | FLASH_CTRL_CLK
    sh t0, (a2)
    li t0, FLASH_CTRL_ACTIVE | FLASH_CTRL_CLK
    sh t0, (a2)

    ret

trap:
    ebreak
