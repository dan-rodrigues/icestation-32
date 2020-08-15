# Firmware

This program is stored in 1kbyte of preinitialized block RAM and is the first code to be run on startup.

## Tasks

* If the `BOOT_PROMPT` variable in the Makefile is set, initialize the VDP with a text prompt. The text prompt is shown until a button on the board is set. The button is the left-shift-key in simulators and the user button on the iCEBreaker.
* Power up the flash and enable quad IO.
* Enter QPI mode if the `QPI_MODE` define is set in boot.S. Default is to remain in QSPI mode.
* Perform a dummy flash read with CRM enabled. This is assumed by the hardware `flash_reader` module which will always keep the flash in CRM mode.
* Perform IPL. 64kbyte at offset 0x200000 in flash is copied to CPU RAM.
* Jump to offset 0x0000 in CPU RAM. The user program now has control of the system.