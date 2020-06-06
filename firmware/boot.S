.global _start

.equ CPU_RAM_BASE, 0x00000
.equ FLASH_BASE, 0x80000

.equ IPL_LENGTH, 0x10000
.equ IPL_START, FLASH_BASE
.equ IPL_END, IPL_START + IPL_LENGTH

_start:
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

trap:
    ebreak
