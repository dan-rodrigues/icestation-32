// vdp_host_interface.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

`include "debug.vh"

module vdp_host_interface #(
    parameter USE_8BIT_BUS = 0
) (
    input clk,
    input reset,

    input [6:0] address_in,
    output reg [5:0] address_out,

    // writes

    output reg write_en_out,
    output reg [15:0] data_out,
    output reg ready,

    // ..from CPU

    input write_en_in,
    input [15:0] data_in,
    
    // ..from copper (make above names consistent too)

    input cop_write_en,
    input [5:0] cop_write_address,
    input [15:0] cop_write_data,
    
    // (this may not be needed)
    output reg cop_write_ready,

    // CPU reads

    input read_en_in
);
    reg write_en_in_r, write_en_in_d;
    reg read_en_in_r, read_en_in_d;

    // only used in 8bit mode
    reg [7:0] data_in_r;
    reg [6:0] address_in_r;
    
    always @(posedge clk) begin
        address_in_r <= address_in;
        data_in_r <= data_in;

        write_en_in_r <= write_en_in;
        write_en_in_d <= write_en_in_r;

        read_en_in_r <= read_en_in;
        read_en_in_d <= read_en_in_r;
    end

    // this is intended to stall by some variable number of cycles, when that's inevitably needed
    
    reg [1:0] busy_counter;
    reg busy;

    // TODO: handle contention by stalling copper if needed
    // write_en currently active for just 1 cycle
    // OR: stalling possibly isn't needed, it can just buffer the write

    always @(posedge clk) begin
        if (cop_write_en) begin

        end
    end

    // cpu read / write control

    always @(posedge clk) begin
        if (reset) begin
            busy_counter <= 0;
            busy <= 0;
            ready <= 0;
        end else begin
            ready <= 0;

            // probably have to register this one anyway
            // can expose it as an output of delay_ff
            if (busy_counter > 0) begin
                busy_counter <= busy_counter - 1;
            end else if (busy) begin
                ready <= 1;
                busy <= 0;
            end else if (read_en_in_r && !read_en_in_d || write_en_in_r && !write_en_in_d) begin
                ready <= 1;
                busy_counter <= 0;
                busy <= 0;
            end
        end
    end

    reg [7:0] data_t;

    // FIXME: buffer writes betwee cpu/cop
    reg cpu_write_pending, cop_write_pending;
    reg [5:0] cpu_pending_address, cop_pending_address;
    reg [15:0] cpu_pending_data, cop_pending_data;

    always @(posedge clk) begin
        if (reset) begin
            data_t <= 0;
            write_en_out <= 0;
            address_out <= 0;
            data_out <= 0;
        end else if (USE_8BIT_BUS) begin
            if (write_en_in_r) begin
                if (address_in_r[0]) begin
                    data_out <= {data_in_r[7:0], data_t};
                    address_out <= address_in_r[6:1];
                    write_en_out <= 1;

                    data_t <= 0;
                end else begin
                    data_t <= data_in_r[7:0];
                    write_en_out <= 0;
                end
            end else begin
                address_out <= 0; 
                write_en_out <= 0;
            end
        end else begin
            // FIXME: this must be shared between cpu/cop

            // is there a CPU <-> COP write conflict?
            if (cop_write_en && write_en_in) begin
                // this is either a software or hardware bug so flag it accordingly
                `stop($display("CPU / VDP copper write conflict");)
            end

            // if there was a conflict, prioritize the CPU
            if (write_en_in) begin
                address_out <= address_in;
                data_out <= data_in;
            end else begin
                address_out <= cop_write_address;
                data_out <= cop_write_data;
            end

            // 1 cycle wstrb on rising edge only
            if (cop_write_en || (write_en_in && !write_en_in_r)) begin
                write_en_out <= 1;
            end else begin
                write_en_out <= 0;
            end
        end
    end

endmodule
