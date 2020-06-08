`ifndef bus_arbiter_vh
`define bus_arbiter_vh

localparam BA_CPU_RAM = (1 << 0);
localparam BA_VDP = (1 << 1);
localparam BA_DSP = (1 << 2);
localparam BA_PAD = (1 << 3);
localparam BA_BOOT = (1 << 4);
localparam BA_FLASH = (1 << 5);

localparam BA_ALL = BA_CPU_RAM | BA_VDP | BA_DSP | BA_PAD | BA_BOOT | BA_FLASH;

`endif
