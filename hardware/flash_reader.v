// flash_reader.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

// This flash controller assumes QPI (or QSPI) and CRM have been preenabled
// The assumed CRM command is 0xeb (Fast Read Quad I/O)
// It will keep CRM enabled after every read

`default_nettype none

// Note flash_in, flash_in_en and flash_csn are not registered in this module
// They are registered externally (SB_IO instances for up5k)

module flash_reader #(
    parameter [0:0] ASSUME_QPI = 0
) (
    input clk,
    input reset,

    input valid,
    input [23:0] address,
    input size,
    output reg [31:0] data,
    output reg ready,

    output reg flash_clk_en,
    output reg flash_csn,
    output reg [3:0] flash_in,
    output reg [3:0] flash_in_en,
    input [3:0] flash_out
);
    localparam DUMMY_CYCLES = ASSUME_QPI ? 0 : 4;

    // Winbond: byte[5:4] == 2'b10
    // ISSI: byte[7:4] == 4'b1001
    localparam [7:0] CRM_BYTE = 8'h20 | 8'h80;

    reg [4:0] state;
    
    wire [3:0] byte_state = state[4:1];
    wire nybble_state = state[0];

    reg [3:0] read_buffer;
    wire [7:0] read_byte = {read_buffer, flash_out};

    always @(posedge clk) begin
        if (nybble_state) begin
            read_buffer <= flash_out;
        end
    end

    reg [7:0] selected_byte;

    always @* begin
        case (byte_state)
            0: selected_byte = address[23:16];
            1: selected_byte = address[15:8];
            2: selected_byte = address[7:0];
            default: selected_byte = CRM_BYTE;
        endcase
    end

    always @* begin
        flash_in = nybble_state ? selected_byte[3:0] : selected_byte[7:4];
    end

    always @(posedge clk) begin
        if (!nybble_state) begin
            case (byte_state - (DUMMY_CYCLES / 2))
                5: data[7:0] <= read_byte;
                6: data[15:8] <= read_byte;
                7: data[23:16] <= read_byte;
                8: data[31:24] <= read_byte;
            endcase
        end
    end

    wire halted = (reset || !valid || ready);

    always @* begin
        if (halted) begin
            flash_in_en = 0;
            flash_csn = 1;
        end else begin
            flash_csn = 0;

            case (byte_state)
                0, 1, 2, 3: flash_in_en = 4'hf;
                default: flash_in_en = 0;
            endcase
        end
    end

    wire [4:0] state_final = 5'h0b + (size ? 4 : 0) + DUMMY_CYCLES;

    always @(posedge clk) begin
        if (halted) begin
            flash_clk_en <= 0;
            state <= 0;
            ready <= 0;
        end else begin
            if (flash_clk_en) begin
                state <= state + 1;
            end

            flash_clk_en <= 1;

            if (state == state_final) begin
                ready <= 1;
            end
        end
    end

endmodule
