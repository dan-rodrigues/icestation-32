MEMORY
{
	// 2KByte at end is reserved for stack
	SPRAM (xrw) : ORIGIN = 0x00000000, LENGTH = 0xf800

	// This memory region would be used if the progam was XIP from the flash
	// Instead it is copied to the SPRAM
	// FLASH_IPL (xr) : ORIGIN = 0x00080000, LENGTH = 0x010000

	FLASH_ASSETS (xr) : ORIGIN = 0x01010000, LENGTH = 0xdf0000
}

SECTIONS {
	.flash_cpu : AT (0x10000)
	SUBALIGN(4)
	{
		_flash_cpu_start = .;

		// This works around an issue where an empty flash_cpu section causes
		// problems for flash_adpcm. If it is empty, the AT() above is
		// ignored and the flash_adpcm section is incorrectly placed.
		BYTE(0xff)
		. = ALIGN(4);

		// -flto means some sections don't get matched here depending on how
		// the file is used. The .gnu.lto.* sections containing the data do
		// not get included here. -flto is disabled for rc_* files because of
		// this
		*flash_cpu_*(.*)

		_flash_cpu_end = .;
	} >FLASH_ASSETS

	.flash_adpcm :
	SUBALIGN(1024)
	{
		_flash_adpcm_start = .;

		// Same -flto constraints apply to this too
		*adpcm_*(.*)

		flash_adpcm_end = .;
	} >FLASH_ASSETS

	// Main program and constants to be stored in first 64Kbyte of flash and
	// then loaded to the SPRAM during IPL

	.text : AT (0)
	{
		. = ALIGN(4);
		*(.text.reset)
		*(.text)           /* .text sections (code) */
		*(.text*)          /* .text* sections (code) */
		*(.rodata)         /* .rodata sections (constants, strings, etc.) */
		*(.rodata*)        /* .rodata* sections (constants, strings, etc.) */
		*(.srodata)        /* .rodata sections (constants, strings, etc.) */
		*(.srodata*)       /* .rodata* sections (constants, strings, etc.) */
		. = ALIGN(4);
		_etext = .;        /* define a global symbol at end of code */
		_sidata = _etext;  /* This is used by the startup in order to initialize the .data secion */
	} >SPRAM

	// Data section is also loaded during IPL
	// The .text and .data sections are loaded to the same SPRAM region

	.data :
	{
		. = ALIGN(4);
		_sdata = .;        /* create a global symbol at data start; used by startup code in order to initialise the .data section in RAM */
		_ram_start = .;    /* create a global symbol at ram start for garbage collector */
		. = ALIGN(4);
		*(.data)           /* .data sections */
		*(.data*)          /* .data* sections */
		*(.sdata)           /* .sdata sections */
		*(.sdata*)          /* .sdata* sections */
		. = ALIGN(4);

		// There is no need for a separate copy of .data section from flash
		// It is copied to SPRAM, along with the main program, by bootloader
		// _edata = .;
	} >SPRAM

	/* Uninitialized data section */
	.bss :
	{
		. = ALIGN(4);
		_sbss = .;         /* define a global symbol at bss start; used by startup code */
		*(.bss)
		*(.bss*)
		*(.sbss)
		*(.sbss*)
		*(COMMON)

		. = ALIGN(4);
		_ebss = .;         /* define a global symbol at bss end; used by startup code */
	} >SPRAM

	
	/* this is to define the start of the heap, and make sure we have a minimum size */
	.heap :
	{
		. = ALIGN(4);
		_heap_start = .;    /* define a global symbol at heap start */
	} >SPRAM
}
