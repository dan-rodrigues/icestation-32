// ics32_top_icebreaker.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module ics32_top_icebreaker #(
    parameter [0:0] ENABLE_WIDESCREEN = 1,
    parameter [0:0] GAMEPAD_PMOD = 0
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

    output flash_clk,
    output flash_csn,
    inout [3:0] flash_io,

    input btn_u,

    // PMOD 2 (3-button breakout board PMOD *OR* gamepad + audio PMOD)

    inout pmod2_1,
    inout pmod2_2,
    inout pmod2_3,
    inout pmod2_4,

    inout pmod2_7,
    inout pmod2_8,
    inout pmod2_9,
    inout pmod2_10
);
    // --- PDM Audio DAC (Gamepad + audio PMOD) ---

    localparam PCM_WIDTH = 16;

    generate
        if (GAMEPAD_PMOD) begin
            wire pdm_audio_l, pdm_audio_r;

            // PDM stereo output

            SB_IO #(
                .PIN_TYPE(6'b010100),
                .PULLUP(1'b0),
                .NEG_TRIGGER(1'b0),
                .IO_STANDARD("SB_LVCMOS")
            ) pdm_stereo_dac_sbio [1:0] (
                .OUTPUT_CLK(clk_2x),

                .PACKAGE_PIN({pmod2_4, pmod2_10}),
                .D_OUT_0({pdm_audio_l, pdm_audio_r}),
            );

            pdm_dac #(
                .WIDTH(PCM_WIDTH)
            ) pdm_stereo_dac [1:0] (
                .clk(clk_2x),
                .reset(reset_2x),

                .pcm_in({audio_output_l, audio_output_r}),
                .pcm_valid({audio_output_valid, audio_output_valid}),

                .pdm_out({pdm_audio_l, pdm_audio_r})
            );
        end
    endgenerate

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

    // --- DVI video (dual PMOD with HDMI compatible port) ---

    // CLK

    SB_IO #(
        .PIN_TYPE(6'b010000),
        .PULLUP(1'b0),
        .NEG_TRIGGER(1'b0),
        .IO_STANDARD("SB_LVCMOS")
    ) vga_clk_sbio (
        .OUTPUT_CLK(clk_2x),

        .PACKAGE_PIN(vga_clk),
        .D_OUT_0(1'b0),
        .D_OUT_1(1'b1)
    );

    // RGBS + DE

    SB_IO #(
        .PIN_TYPE(6'b010100),
        .PULLUP(1'b0),
        .NEG_TRIGGER(1'b0),
        .IO_STANDARD("SB_LVCMOS")
    ) vga_rgbsde_sbio [14:0] (
        .OUTPUT_CLK(clk_2x),

        .PACKAGE_PIN({vga_de, vga_vsync, vga_hsync, vga_r, vga_g, vga_b}),
        .D_OUT_0({vga_de_io, vga_vsync_io, vga_hsync_io, vga_r_io, vga_g_io, vga_b_io}),
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
        .INPUT_CLK(clk_2x),
        .OUTPUT_CLK(clk_2x),

        .OUTPUT_ENABLE(flash_in_en),
        .PACKAGE_PIN(flash_io),
        .D_OUT_0(flash_in),
        .D_IN_0(flash_out)
    );

    // CSN

    SB_IO #(
        .PIN_TYPE(6'b010100),
        .PULLUP(1'b0),
        .NEG_TRIGGER(1'b0),
        .IO_STANDARD("SB_LVCMOS")
    ) flash_csn_sbio (
        .INPUT_CLK(clk_2x),
        .OUTPUT_CLK(clk_2x),

        .PACKAGE_PIN(flash_csn),
        .D_OUT_0(flash_csn_io)
    );

    // CLK

    SB_IO #(
        .PIN_TYPE(6'b010000),
        .PULLUP(1'b0),
        .NEG_TRIGGER(1'b0),
        .IO_STANDARD("SB_LVCMOS")
    ) flash_clk_sbio (
        .INPUT_CLK(clk_2x),
        .OUTPUT_CLK(clk_2x),

        .PACKAGE_PIN(flash_clk),
        .D_OUT_0(flash_clk_ddr[0]),
        .D_OUT_1(flash_clk_ddr[1])
    );

    // --- User inputs ---

    // Gamepads:

    wire [1:0] pad_read_data;

    generate
        if (GAMEPAD_PMOD) begin
            wire [1:0] pad_read_data_n;
            assign pad_read_data = ~pad_read_data_n;

            // Gamepad CLK + Latch

            SB_IO #(
                .PIN_TYPE(6'b010100),
                .PULLUP(1'b0),
                .NEG_TRIGGER(1'b0),
                .IO_STANDARD("SB_LVCMOS")
            ) gp_clk_latch_sbio [1:0] (
                .INPUT_CLK(clk_2x),
                .OUTPUT_CLK(clk_2x),

                .PACKAGE_PIN({pmod2_1, pmod2_7}),
                .D_OUT_0({pad_clk, pad_latch})
            );

            // Gamepad data

            // There are actually 4 controller ports on the PMOD but the system is 2P only

            SB_IO #(
                .PIN_TYPE(6'b000000),
                .PULLUP(1'b0),
                .NEG_TRIGGER(1'b0),
                .IO_STANDARD("SB_LVCMOS")
            ) gp_data_sbio [1:0] (
                .INPUT_CLK(clk_2x),
                .OUTPUT_CLK(clk_2x),

                .PACKAGE_PIN({pmod2_8, pmod2_2}),
                .D_IN_0(pad_read_data_n)
            );
        end else begin
            // Breakout board buttons:

            wire [2:0] btn_r;

            SB_IO #(
                .PIN_TYPE(6'b000000),
                .PULLUP(1'b0),
                .NEG_TRIGGER(1'b0),
                .IO_STANDARD("SB_LVCMOS")
            ) btn_sbio [2:0] (
                .INPUT_CLK(clk_2x),
                .OUTPUT_CLK(clk_2x),

                .PACKAGE_PIN({pmod2_10, pmod2_4, pmod2_9}),
                .D_IN_0(btn_r)
            );

            // P1 has limited inputs using the breakout board

            wire [11:0] pad_btn = {btn_r[0], btn_r[2], 5'b0, btn_r[1]};

            mock_gamepad mock_gamepad(
                .clk(clk_2x),

                .pad_clk(pad_clk),
                .pad_btn(pad_btn),
                .pad_latch(pad_latch),

                .pad_out(pad_read_data[0])
            );

            // P2 has no inputs when just using the breakout board
            
            assign pad_read_data[1] = 0;
        end
    endgenerate

    // User button:

    wire user_button;
    wire user_button_n = !user_button;

    SB_IO #(
        .PIN_TYPE(6'b000000),
        .PULLUP(1'b0),
        .NEG_TRIGGER(1'b0),
        .IO_STANDARD("SB_LVCMOS")
    ) btn_sbio (
        .INPUT_CLK(clk_2x),
        .OUTPUT_CLK(clk_2x),

        .PACKAGE_PIN(btn_u),
        .D_IN_0(user_button)
    );

    // --- icestation-32 ---

    wire reset_1x, reset_2x;

    wire [3:0] flash_in;
    wire [3:0] flash_in_en;
    wire flash_csn_io;
    wire [1:0] flash_clk_ddr;
    
    wire pad_latch, pad_clk;

    wire vga_hsync_io, vga_vsync_io, vga_de_io;
    wire [3:0] vga_r_io, vga_g_io, vga_b_io;

    wire audio_output_valid;
    wire [15:0] audio_output_l, audio_output_r;

    ics32 #(
        .CLK_1X_FREQ(CLK_1X_FREQ),
        .CLK_2X_FREQ(CLK_2X_FREQ),
        .ENABLE_WIDESCREEN(ENABLE_WIDESCREEN),
        .ENABLE_FAST_CPU(0),
        .RESET_DURATION_EXPONENT(24),
        .ENABLE_BOOTLOADER(1),
        .BOOTLOADER_SIZE(256),
    ) ics32 (
        .clk_1x(clk_1x),
        .clk_2x(clk_2x),
        .pll_locked(pll_locked),

        .reset_1x(reset_1x),
        .reset_2x(reset_2x),

        .vga_r(vga_r_io),
        .vga_g(vga_g_io),
        .vga_b(vga_b_io),

        .vga_hsync(vga_hsync_io),
        .vga_vsync(vga_vsync_io),
        .vga_de(vga_de_io),

        .pad_latch(pad_latch),
        .pad_clk(pad_clk),
        .pad_data(pad_read_data),

        .user_button(user_button_n),

        .led({led_r, led_b}),

        .flash_clk_ddr(flash_clk_ddr),
        .flash_csn(flash_csn_io),
        .flash_in_en(flash_in_en),
        .flash_in(flash_in),
        .flash_out(flash_out),

        .audio_output_l(audio_output_l),
        .audio_output_r(audio_output_r),
        .audio_output_valid(audio_output_valid)
    );

endmodule
