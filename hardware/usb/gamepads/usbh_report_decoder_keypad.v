// usbh_report_decoder_keypad.v: Generic USB keyboard keypad
//
// Copyright (C) 2020 Mara "vmedea" <vmedea@protonmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

// HID report layout:
//
//  [7:0]   Modifier keys
//  [15:8]  Padding
//  [23:16] Keycode 0
//  [31:24] Keycode 1
//  [39:32] Keycode 2
//  [47:40] Keycode 3
//  [55:48] Keycode 4
//  [63:56] Keycode 5
//
module keycode_match #(
    parameter [7:0] KEYCODE = 8'h00
) (
    input  wire [63:0] i_report,
    output wire        o_btn
);
    wire [7:0] key0 = i_report[23:16];
    wire [7:0] key1 = i_report[31:24];
    wire [7:0] key2 = i_report[39:32];
    wire [7:0] key3 = i_report[47:40];
    wire [7:0] key4 = i_report[55:48];
    wire [7:0] key5 = i_report[63:56];

    wire o_btn = key0 == KEYCODE | key1 == KEYCODE | key2 == KEYCODE | key3 == KEYCODE | key4 == KEYCODE | key5 == KEYCODE;
endmodule

module usbh_report_decoder_keypad(
    input  wire        i_clk,
    input  wire [63:0] i_report,
    input  wire        i_report_valid,
    output reg   [11:0] o_btn
);
    wire left, right, up, down, a, b, x, y, l, r, select, start;

    // Mimic Wii dance mat layout
    //
    // ┌───┬───┬───┐
    // │ B │ ↑ │ A │
    // ├───┼───┼───┤
    // │ ← │   │ → │
    // ├───┼───┼───┤
    // │ Y │ ↓ │ X │
    // └───┴───┴───┘

    keycode_match #(.KEYCODE(8'h5c /* keypad 4 */)) m_left(.i_report(i_report), .o_btn(left));
    keycode_match #(.KEYCODE(8'h5e /* keypad 5 */)) m_right(.i_report(i_report), .o_btn(right));
    keycode_match #(.KEYCODE(8'h60 /* keypad 8 */)) m_up(.i_report(i_report), .o_btn(up));
    keycode_match #(.KEYCODE(8'h5a /* keypad 2 */)) m_down(.i_report(i_report), .o_btn(down));
    keycode_match #(.KEYCODE(8'h61 /* keypad 9 */)) m_a(.i_report(i_report), .o_btn(a));
    keycode_match #(.KEYCODE(8'h5f /* keypad 7 */)) m_b(.i_report(i_report), .o_btn(b));
    keycode_match #(.KEYCODE(8'h5b /* keypad 3 */)) m_x(.i_report(i_report), .o_btn(x));
    keycode_match #(.KEYCODE(8'h59 /* keypad 1 */)) m_y(.i_report(i_report), .o_btn(y));

    keycode_match #(.KEYCODE(8'h62 /* keypad 0 */)) m_l(.i_report(i_report), .o_btn(l));
    keycode_match #(.KEYCODE(8'h63 /* keypad . */)) m_r(.i_report(i_report), .o_btn(r));

    keycode_match #(.KEYCODE(8'h57 /* keypad + */)) m_select(.i_report(i_report), .o_btn(select));
    keycode_match #(.KEYCODE(8'h58 /* keypad ⏎ */)) m_start(.i_report(i_report), .o_btn(start));

    always @(posedge i_clk) begin
        if (i_report_valid) begin
            o_btn <= {
                r, l, x, a,
                right, left, down, up,
                start, select, y, b
            };
        end
    end

endmodule

