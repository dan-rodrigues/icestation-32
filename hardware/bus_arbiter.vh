`ifndef bus_arbiter_vh
`define bus_arbiter_vh

`define BA_CPU_RAM (1 << 0)
`define BA_VDP (1 << 1)
`define BA_DSP (1 << 2)
`define BA_PAD (1 << 3)
`define BA_BOOT (1 << 4)
`define BA_FLASH (1 << 5)

`define BA_ALL (`BA_CPU_RAM | `BA_VDP | `BA_DSP | `BA_PAD | `BA_BOOT | `BA_FLASH)

`endif
