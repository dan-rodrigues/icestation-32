// ics32_tb.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module ics32_tb(
    input clk_1x,
    input clk_2x,

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
    input btn_3
);
    ics32 #(
        .ENABLE_WIDESCREEN(1),
        .FORCE_FAST_CPU(0),
        .RESET_DURATION_EXPONENT(2),

        // For simulator use, there's no point enabling this unless the bootloader itself is being tested
        // The sim performs the bootloaders job of copying the program from flash to CPU RAM
        // Enabling this just delays the program start
        .ENABLE_BOOTLOADER(1)
    ) ics32 (
        .clk_1x(clk_1x),
        .clk_2x(clk_2x),
        .pll_locked(1),

        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),

        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),

        .vga_clk(vga_clk),
        .vga_de(vga_de),

        .btn_u(btn_u),
        .btn_1(btn_1),
        .btn_2(btn_2),
        .btn_3(btn_3),

        .led_r(led_r),
        .led_b(led_b),

        .flash_clk_ddr(flash_clk_ddr),
        .flash_csn(flash_csn),
        .flash_in_en(flash_in_en),
        .flash_in(flash_in),
        .flash_out(flash_out)
    );

    // --- Flash sim blackbox ---

    wire [1:0] flash_clk_ddr;
    wire flash_csn;
    wire [3:0] flash_in_en;
    wire [3:0] flash_in;
    wire [3:0] flash_out;

    reg [3:0] flash_in_r;
    reg [3:0] flash_out_r;
    reg flash_csn_r;

    assign flash_csn_bb = flash_csn_r;
    assign flash_in_bb = flash_in_r;
    assign flash_in_en_bb = flash_in_en;
    wire [3:0] flash_out = flash_out_r;
    
    always @(posedge clk_2x) begin
        flash_in_r <= flash_in;
        flash_csn_r <= flash_csn;

        flash_out_r <= flash_out_bb;
    end

    // This isn't quite what SB_IO does in DDR mode
    // Since we're not actually pushing out DDR data streams, this could be replaced with a reimplementation of flash_clk_out
    // There might be also a simpler way to do this in a way that works in both sims

    reg flash_clk_l, flash_clk_h;
    assign flash_clk_bb = clk_2x ? flash_clk_h : flash_clk_l;

    always @(posedge clk_2x) begin
        flash_clk_h <= flash_clk_ddr[0];
    end

    always @(negedge clk_2x) begin
        flash_clk_l <= flash_clk_ddr[1];
    end

    // Parameters could be forwarded to the sim factory functions
    // This could later be used to assume a certain power-up state (depending on icepack "-s" switch)

    wire flash_clk_bb;
    wire flash_csn_bb;
    wire [3:0] flash_in_bb;
    wire [3:0] flash_in_en_bb;
    wire [3:0] flash_out_bb;

    flash_bb flash(
        .clk(flash_clk_bb),
        .csn(flash_csn_bb),
        .in_en(flash_in_en_bb),
        .in(flash_in_bb),
        .out(flash_out_bb)
    );

endmodule

(* cxxrtl_blackbox *)
module flash_bb(
    input clk /* verilator public */,
    input csn /* verilator public */,
    input [3:0] in_en /* verilator public */,
    input [3:0] in /* verilator public */,
    (* cxxrtl_sync *) output [3:0] out /* verilator public */,
    (* cxxrtl_sync *) output [3:0] out_en /* verilator public */
);

/* verilator public_module */

endmodule
