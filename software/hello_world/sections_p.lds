MEMORY
{
 SPRAM (xrw) : ORIGIN = 0x00000000, LENGTH = 0x10000
 FLASH_ASSETS (xr) : ORIGIN = 0x00050000, LENGTH = 0x030000
}
SECTIONS {
 .assets : AT (0x10000)
 {
  . = ALIGN(4);
  _flash_assets_start = .;
  rc-*(.*)
  _flash_assets_end = .;
 } >FLASH_ASSETS
    .text : AT (0)
    {
        . = ALIGN(4);
  vectors*(.text)
        *(.text)
        *(.text*)
        *(.rodata)
        *(.rodata*)
        *(.srodata)
        *(.srodata*)
        . = ALIGN(4);
        _etext = .;
        _sidata = _etext;
    } >SPRAM
 .data :
    {
        . = ALIGN(4);
        _sdata = .;
        _ram_start = .;
        . = ALIGN(4);
        *(.data)
        *(.data*)
        *(.sdata)
        *(.sdata*)
        . = ALIGN(4);
    } >SPRAM
    .bss :
    {
        . = ALIGN(4);
        _sbss = .;
        *(.bss)
        *(.bss*)
        *(.sbss)
        *(.sbss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } >SPRAM
    .heap :
    {
        . = ALIGN(4);
        _heap_start = .;
    } >SPRAM
}
