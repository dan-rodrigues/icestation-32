// pdm_dac.v
//
// Based on the icebreaker-examples repo:
// https://github.com/icebreaker-fpga/icebreaker-examples/tree/master/gamepad-audio

`default_nettype none

module pdm_dac #(
    parameter integer WIDTH = 16
) (
    input clk,
    input reset,

    input [WIDTH - 1:0] pcm_in,
    input pcm_valid,

    output pdm_out
);
    reg [WIDTH - 1:0] pdm_level;
    reg [WIDTH + 1:0] pdm_sigma;
    assign pdm_out = ~pdm_sigma[WIDTH + 1];

    always @(posedge clk) begin
        if (reset) begin
            pdm_level <= 0;
            pdm_sigma <= 0;
        end else begin
            if (pcm_valid) begin
                pdm_level <= pcm_in + ((1 << (WIDTH - 1)));
            end

            pdm_sigma <= pdm_sigma + {pdm_out, pdm_out, pdm_level};
        end
    end

endmodule
