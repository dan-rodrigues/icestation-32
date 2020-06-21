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

// When QE=1, the /WP pin becomes IO2 and /HOLD pin becomes IO3. 
# .equ FLASH_WP_HOLD_DEFAULT, (0 << 2 | 1 << 3)

_start:
    la a2, FLASH_CTRL_BASE

    li a0, (~FLASH_CTRL_ACTIVE & FLASH_CTRL_ACTIVE) | FLASH_CTRL_CLK
    sh a0, (a2)

    // CSN low, clock high
    li a0, FLASH_CTRL_ACTIVE | FLASH_CTRL_CLK
    sh a0, (a2)

    // 1. read SR2
    li a0, 0x35
    jal ra, spi_transfer

    // 2. load SR2 contents, set QE bit and save it for later
    jal ra, spi_transfer
    ori s0, a0, FLASH_SR2_QE

    // complete cmd
    li a1, FLASH_CTRL_CSN | FLASH_CTRL_ACTIVE | FLASH_CTRL_CLK
    sh a1, (a2)
    li a1, FLASH_CTRL_ACTIVE | FLASH_CTRL_CLK
    sh a1, (a2)

    // volatile status reg write enable, immediately before the write
    li a0, 0x50
    jal ra, spi_transfer
    
    // complete cmd (TODO reuse)
    li a1, FLASH_CTRL_CSN | FLASH_CTRL_ACTIVE | FLASH_CTRL_CLK
    sh a1, (a2)
    li a1, FLASH_CTRL_ACTIVE | FLASH_CTRL_CLK
    sh a1, (a2)

    // write SR2
    li a0, 0x31
    jal ra, spi_transfer

    // send updated SR2
    mv a0, s0
    jal ra, spi_transfer

    // QE bit now set, deassert /CS, hand back flash to flash controller
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

trap:
    ebreak
