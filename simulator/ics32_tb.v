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

        // For simulator use, there's no point enabling this unless the bootloader itself is being tested
        // The sim performs the bootloaders job of copying the program from flash to CPU RAM
        // Enabling this just delays the program start
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

        .flash_clk(flash_clk),
        .flash_csn(flash_csn),
        .flash_in_en_bb(flash_in_en),
        .flash_in_bb(flash_in),
        .flash_out_bb(flash_out)
    );

    // --- Flash sim blackbox ---

    // Parameters could be forwarded to the sim factory functions
    // This could later be used to assume a certain power-up state (depending on icepack "-s" switch)

    wire flash_clk;
    wire flash_csn;
    wire [3:0] flash_in_en;
    wire [3:0] flash_in;
    wire [3:0] flash_out;

    flash_bb flash(
        .clk(flash_clk),
        .csn(flash_csn),
        .in_en(flash_in_en),
        .in(flash_in),
        .out(flash_out)
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
