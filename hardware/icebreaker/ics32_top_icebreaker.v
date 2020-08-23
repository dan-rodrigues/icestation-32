// ics32_top_icebreaker.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module ics32_top_icebreaker #(
    parameter [0:0] ENABLE_WIDESCREEN = 1,
) (
    input clk_12m,

    output [3:0] vga_r,
    output [3:0] vga_g,
    output [3:0] vga_b,

    output vga_hsync,
    output vga_vsync,

    output vga_clk,
    output vga_de,

    output led_r,
    output led_b,

    input btn_u,
    input btn_1,
    input btn_2,
    input btn_3,

    output flash_clk,
    output flash_csn,
    inout [3:0] flash_io
);
    // --- Clocks ---

    localparam integer CLK_2X_FREQ = ENABLE_WIDESCREEN ? `CLK_2X_WIDESCREEN : `CLK_2X_STANDARD;
    localparam integer CLK_1X_FREQ = ENABLE_WIDESCREEN ? `CLK_1X_WIDESCREEN : `CLK_1X_STANDARD;

    // --- iCE40 PLL (640x480 or 848x480 clock selection) ---

    wire clk_1x, clk_2x;
    wire pll_locked;

    pll_ice40 #(
        .ENABLE_FAST_CLK(ENABLE_WIDESCREEN)
    ) pll (
        .clk_12m(clk_12m),

        .locked(pll_locked),
        .clk_1x(clk_1x),
        .clk_2x(clk_2x)
    );

    // --- iCE40 Flash IO ---

    wire [3:0] flash_out;
    wire [3:0] flash_in_en;
    wire [3:0] flash_in;

    // IO

    SB_IO #(
        .PIN_TYPE(6'b110100),
        .PULLUP(1'b0),
        .NEG_TRIGGER(1'b0),
        .IO_STANDARD("SB_LVCMOS")
    ) flash_inout_sbio [3:0] (
        .PACKAGE_PIN(flash_io),
        .OUTPUT_ENABLE(flash_in_en),
        .CLOCK_ENABLE(1'b1),
        .OUTPUT_CLK(clk_2x),
        .D_OUT_0(flash_in),
        .INPUT_CLK(clk_2x),
        .D_IN_0(flash_out)
    );

    // CSN

    SB_IO #(
        .PIN_TYPE(6'b010100),
        .PULLUP(1'b0),
        .NEG_TRIGGER(1'b0),
        .IO_STANDARD("SB_LVCMOS")
    ) flash_csn_sbio (
        .PACKAGE_PIN(flash_csn),
        .CLOCK_ENABLE(1'b1),
        .OUTPUT_CLK(clk_2x),
        .D_OUT_0(flash_csn_io)
    );

    // CLK

    SB_IO #(
        .PIN_TYPE(6'b010000),
        .PULLUP(1'b0),
        .NEG_TRIGGER(1'b0),
        .IO_STANDARD("SB_LVCMOS")
    ) flash_clk_sbio (
        .PACKAGE_PIN(flash_clk),
        .CLOCK_ENABLE(1'b1),
        .OUTPUT_CLK(clk_2x),
        .D_OUT_0(flash_clk_ddr[0]),
        .D_OUT_1(flash_clk_ddr[1])
    );

    wire [3:0] flash_in;
    wire [3:0] flash_in_en;
    wire flash_csn_io;
    wire [1:0] flash_clk_ddr;
    
    ics32 #(
        .CLK_1X_FREQ(CLK_1X_FREQ),
        .CLK_2X_FREQ(CLK_2X_FREQ),
        .ENABLE_WIDESCREEN(ENABLE_WIDESCREEN),
        .ENABLE_FAST_CPU(0),
        .RESET_DURATION_EXPONENT(24),
        .ENABLE_BOOTLOADER(1)
    ) ics32 (
        .clk_1x(clk_1x),
        .clk_2x(clk_2x),
        .pll_locked(pll_locked),

        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),

        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),

        .vga_clk(vga_clk),
        .vga_de(vga_de),

        .btn_u(~btn_u),
        .btn_1(btn_1),
        .btn_2(btn_2),
        .btn_3(btn_3),

        .led({led_r, led_b}),

        .flash_clk_ddr(flash_clk_ddr),
        .flash_csn(flash_csn_io),
        .flash_in_en(flash_in_en),
        .flash_in(flash_in),
        .flash_out(flash_out)
    );

endmodule
