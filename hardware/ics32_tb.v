// ics32_tb.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module ics32_tb(
    input clk_12m,

    output [3:0] vga_r,
    output [3:0] vga_g,
    output [3:0] vga_b,

    output vga_hsync,
    output vga_vsync,

    output vga_clk,
    output vga_de,

    output hsync,
    output vsync,

    output led_r,
    output led_b
);
    ics32 #(
        .ENABLE_WIDESCREEN(1),
        .FORCE_FAST_CPU(1),
        .RESET_DURATION(4),
        .ENABLE_IPL(1)
    ) ics32 (
        .clk_12m(clk_12m),

        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),

        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),

        .vga_clk(vga_clk),
        .vga_de(vga_de),

        .hsync(hsync),
        .vsync(vsync),

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
