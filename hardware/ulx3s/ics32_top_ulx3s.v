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

    // IO

    reg [3:0] flash_out_r;
    reg [3:0] flash_in_r, flash_in_en_r;

    always @(posedge clk_2x) begin
        flash_out_r <= flash_out;
        flash_in_r <= flash_in;

        // These enable inputs must be inverted to be used as an active-high tristate instead
        flash_in_en_r <= ~flash_in_en;
    end

    BB flash_io_bb[3:0] (
        .I(flash_in_r),
        .T(flash_in_en_r),
        .O(flash_out),
        .B(flash_io)
    );

    // CSN

    reg flash_csn_r;

    always @(posedge clk_2x) begin
        flash_csn_r <= flash_csn_io;
    end

    OB flash_csn_ob(
        .I(flash_csn_r),
        .O(flash_csn)
    );

    // CLK

    // * The ECP5 SPI clock must be controlled with USRMCLK
    // * DDR primitive can't be used with USRMCLK

    // The below block is meant to work around this constraint but isn't ideal
    // It is only "safe" because flask_clk_ddr_r[0] is either 0 or a duplicate of flash_clk_ddr[1]
    // This means the flash clk only rises when clk_2x falls so shouldn't be any setup/hold violation

    reg [1:0] flash_clk_ddr_r;
    wire flash_clk_out = clk_2x ? flash_clk_ddr_r[0] : flash_clk_ddr_r[1];

    always @(posedge clk_2x) begin
        flash_clk_ddr_r[0] <= flash_clk_ddr[0];
    end

    always @(negedge clk_2x) begin
        flash_clk_ddr_r[1] <= flash_clk_ddr[1];
    end

    USRMCLK spi_clk (
        .USRMCLKI(flash_clk_out),
        .USRMCLKTS(1'b0)
    );

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
        .flash_out(flash_out_r),
    );

endmodule
