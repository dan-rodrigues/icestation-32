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

    input [5:0] host_address,
    output reg [4:0] register_write_address,

    // writes

    output reg register_write_en,
    output reg [15:0] register_write_data,
    output reg ready,

    // ..from CPU

    input host_write_en,
    input [15:0] host_write_data,
    
    // ..from copper

    input cop_write_en,
    input [4:0] cop_write_address,
    input [15:0] cop_write_data,

    // CPU reads

    input host_read_en,
    output reg [4:0] read_address
);
    reg host_write_en_r, host_write_en_d;
    reg host_read_en_r, host_read_en_d;

    // only used in 8bit mode
    reg [7:0] host_write_data_r;
    reg [6:0] host_address_r;
    
    always @(posedge clk) begin
        host_address_r <= host_address;
        host_write_data_r <= host_write_data;

        host_write_en_r <= host_write_en;
        host_write_en_d <= host_write_en_r;

        host_read_en_r <= host_read_en;
        host_read_en_d <= host_read_en_r;
    end

    // this is intended to stall by some variable number of cycles, when that's inevitably needed
    
    reg [1:0] busy_counter;
    reg busy;

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
            end else if (host_read_en_r && !host_read_en_d || host_write_en_r && !host_write_en_d) begin
                ready <= 1;
                busy_counter <= 0;
                busy <= 0;
            end
        end
    end

    reg [7:0] data_t;

    always @(posedge clk) begin
        if (reset) begin
            data_t <= 0;
            register_write_en <= 0;
            register_write_address <= 0;
            register_write_data <= 0;
        end else if (USE_8BIT_BUS) begin
            if (host_write_en_r) begin
                if (host_address_r[0]) begin
                    register_write_data <= {host_write_data_r[7:0], data_t};
                    register_write_address <= host_address_r[5:1];
                    register_write_en <= 1;

                    data_t <= 0;
                end else begin
                    data_t <= host_write_data_r[7:0];
                    register_write_en <= 0;
                end
            end else begin
                register_write_address <= 0; 
                register_write_en <= 0;
            end
        end else begin
            if (cop_write_en && host_write_en) begin
                // this is either a software or hardware bug so flag it accordingly
                `stop($display("CPU / VDP copper write conflict");)
            end

            // if there was a conflict, prioritize the CPU
            if (host_write_en) begin
                register_write_address <= host_address;
                register_write_data <= host_write_data;
            end else if (cop_write_en) begin
                register_write_address <= cop_write_address;
                register_write_data <= cop_write_data;
            end

            // CPU is always free to read
            read_address <= host_address_r;

            if (cop_write_en || (host_write_en && !host_write_en_r)) begin
                register_write_en <= 1;
            end else begin
                register_write_en <= 0;
            end
        end
    end

endmodule
