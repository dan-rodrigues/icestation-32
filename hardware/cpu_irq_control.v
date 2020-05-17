// cpu_irq_control.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

// this will eventually be removed whe the copper=like coprocessor is added

module cpu_irq_control(
    input clk,
    input reset,

    input frame_irq_requested,
    input raster_irq_requested,

    input irq_acknowledge,
    input raster_irq_acknowledge,

    output [3:0] irq
);
    reg [3:0] irq_r;

    assign irq = irq_r & ~{raster_irq_acknowledge, irq_acknowledge};

    always @(posedge clk) begin
        if (reset) begin
            irq_r <= 0;
        end else begin
            if (frame_irq_requested) begin
                irq_r[0] <= 1;
            end else if (irq_acknowledge) begin
                irq_r[0] <= 0;
            end

            if (raster_irq_requested && !raster_irq_acknowledge) begin
                irq_r[1] <= 1;
            end else if (raster_irq_acknowledge) begin
                irq_r[1] <= 0;
            end 
        end 
    end

endmodule
