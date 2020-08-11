// ics32_top_ulx3s.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module ics32_top_ulx3s #(
    parameter [0:0] ENABLE_WIDESCREEN = 1,
    parameter [0:0] ENABLE_FAST_CPU = 0
) (
    input clk_25mhz,

    output [3:0] gpdi_dp,
    output [3:0] gpdi_dn,

    output [7:0] led,

    input [6:0] btn,

    output flash_csn,
    inout [3:0] flash_io
);
    // --- ECP5 PLL (640x480 or 848x480 clock selection) ---

    wire clk_1x, clk_2x, clk_10x;
    wire pll_locked;

    pll_ecp5 #(
        .ENABLE_FAST_CLK(ENABLE_WIDESCREEN)
    ) pll (
        .clk_25m(clk_25mhz),

        .locked(pll_locked),
        .clk_1x(clk_1x),
        .clk_2x(clk_2x),
        .clk_10x(clk_10x)
    );

    // --- HDMI ---

    hdmi_encoder hdmi(
        .pixel_clk(clk_2x),
        .pixel_clk_x5(clk_10x),

        .red({2{vga_r}}),
        .green({2{vga_g}}),
        .blue({2{vga_b}}),

        .vde(vga_de),
        .hsync(vga_hsync),
        .vsync(vga_vsync),

        .gpdi_dp(gpdi_dp),
        .gpdi_dn(gpdi_dn)
    );

    // --- ECP5 Flash IO ---

    wire [3:0] flash_out;
    wire [3:0] flash_in_en;
    wire [3:0] flash_in;

    // Flash bidirectional IO

    wire [3:0] flash_out_r;
    wire [3:0] flash_in_en_r;
    wire [3:0] flash_in_r;

    (* BEL="X11/Y93/SLICEA" *) TRELLIS_SLICE flash_in_r_0 (
        .CLK(clk_2x),
        .M0(flash_in[0]), .M1(flash_in[1]),
        .Q0(flash_in_r[0]), .Q1(flash_in_r[1])
    );

    (* BEL="X11/Y93/SLICEB" *) TRELLIS_SLICE flash_in_r_1 (
        .CLK(clk_2x),
        .M0(flash_in[2]), .M1(flash_in[3]),
        .Q0(flash_in_r[2]), .Q1(flash_in_r[3])
    );

    (* BEL="X11/Y93/SLICEC" *) TRELLIS_SLICE flash_in_en_r_0 (
        .CLK(clk_2x),
        .M0(~flash_in_en[0]), .M1(~flash_in_en[1]),
        .Q0(flash_in_en_r[0]), .Q1(flash_in_en_r[1])
    );

    (* BEL="X11/Y93/SLICED" *) TRELLIS_SLICE flash_in_en_r_1 (
        .CLK(clk_2x),
        .M0(~flash_in_en[2]), .M1(~flash_in_en[3]),
        .Q0(flash_in_en_r[2]), .Q1(flash_in_en_r[3])
    );

    (* BEL="X9/Y93/SLICEA" *) TRELLIS_SLICE flash_out_r_0 (
        .CLK(clk_2x),
        .M0(flash_out[0]), .M1(flash_out[1]),
        .Q0(flash_out_r[0]), .Q1(flash_out_r[1]),
    );

    (* BEL="X9/Y93/SLICEB" *) TRELLIS_SLICE flash_out_r_1 (
        .CLK(clk_2x),
        .M0(flash_out[2]), .M1(flash_out[3]),
        .Q0(flash_out_r[2]), .Q1(flash_out_r[3]),
    );

    BB flash_io_bb[3:0] (
        .I(flash_in_r),
        .T(flash_in_en_r),
        .O(flash_out),
        .B(flash_io)
    );

    // Flash CSN

    wire flash_csn_r;

    (* BEL="X15/Y93/SLICEA" *) TRELLIS_SLICE flash_csn_r_0 (
        .CLK(clk_2x),
        .M0(flash_csn_io),
        .Q0(flash_csn_r)
    );

    OB flash_csn_ob(
        .I(flash_csn_r),
        .O(flash_csn)
    );

    // SPI CLK

    // * The ECP5 SPI clock must be controlled with USRMCLK
    // * DDR primitive can't be used with USRMCLK
    // * There is no built in supported to route a global clock USRMCLK

    wire flash_clk_out = clk_2x ? flash_clk_ddr_r[0] : flash_clk_ddr_r[1];

    wire [1:0] flash_clk_ddr_r;

    (* BEL="X2/Y93/SLICEA" *) TRELLIS_SLICE ddr_ff_0 (
        .CLK(clk_2x),
        .M0(flash_clk_ddr[0]),
        .Q0(flash_clk_ddr_r[0])
    );

    (* BEL="X2/Y92/SLICEA" *) TRELLIS_SLICE #(.CLKMUX("INV")) ddr_ff_1 (
        .CLK(clk_2x),
        .M0(flash_clk_ddr[1]),
        .Q0(flash_clk_ddr_r[1])
    );
    
    USRMCLK spi_clk (
        .USRMCLKI(flash_clk_out),
        .USRMCLKTS(1'b0)
    );

    // --- icestation-32 ---

    wire flash_csn_io;
    wire [1:0] flash_clk_ddr;

    wire [3:0] vga_r, vga_g, vga_b;
    wire vga_de, vga_vsync, vga_hsync;

    ics32 #(
        .ENABLE_WIDESCREEN(ENABLE_WIDESCREEN),
        .ENABLE_FAST_CPU(ENABLE_FAST_CPU),
        .RESET_DURATION_EXPONENT(24),
        .ENABLE_BOOTLOADER(1)
    ) ics32 (
        .clk_1x(clk_1x),
        .clk_2x(clk_2x),
        .pll_locked(pll_locked),

        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),

        .vga_de(vga_de),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),

        .btn_u(btn[3]),
        .btn_1(btn[4]),
        .btn_2(btn[5]),
        .btn_3(btn[6]),

        .led(led),

        .flash_clk_ddr(flash_clk_ddr),
        .flash_csn(flash_csn_io),
        .flash_in_en(flash_in_en),
        .flash_in(flash_in),
        .flash_out(flash_out_r)
    );

endmodule
