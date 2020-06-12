// ics32_tb.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module ics32_tb(
`ifndef EXTERNAL_CLOCKS
    input clk_12m,
`else
    input clk_1x,
    input clk_2x,
`endif

    output [3:0] vga_r,
    output [3:0] vga_g,
    output [3:0] vga_b,

    output vga_hsync,
    output vga_vsync,

    output vga_clk,
    output vga_de,

    output led_r,
    output led_b,

    input btn_1,
    input btn_2,
    input btn_3
);
    ics32 #(
        .ENABLE_WIDESCREEN(1),
        .FORCE_FAST_CPU(0),
        .RESET_DURATION(4),
        // .ENABLE_BOOTLOADER(1)
        .ENABLE_BOOTLOADER(0)
    ) ics32 (
`ifndef EXTERNAL_CLOCKS
        .clk_12m(clk_12m),
`else
        .clk_1x(clk_1x),
        .clk_2x(clk_2x),
`endif

        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),

        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),

        .vga_clk(vga_clk),
        .vga_de(vga_de),

        .btn_1(btn_1),
        .btn_2(btn_2),
        .btn_3(btn_3),

        .led_r(led_r),
        .led_b(led_b),

        .flash_sck(flash_sck),
        .flash_csn(flash_csn),
        .flash_mosi(flash_mosi),
        .flash_miso(flash_miso)
    );

    // flash to be used in simulator

    wire flash_csn;
    wire flash_sck;
    wire flash_mosi;
    wire flash_miso;

    sim_spiflash sim_flash(
        .SPI_FLASH_CS(flash_csn),
        .SPI_FLASH_MISO(flash_miso),
        .SPI_FLASH_MOSI(flash_mosi),
        .SPI_FLASH_SCLK(flash_sck)
    );

endmodule
