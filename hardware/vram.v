`default_nettype none

// 64kbyte split into independently addressable 2x 32kbyte 16bit blocks

module vram(
    input clk,

    input [13:0] even_address,
    input [13:0] odd_address,
    input even_write_en,
    input odd_write_en,
    input [31:0] write_data,

    output [31:0] read_data
);
    SB_SPRAM256KA ram0 (
        .ADDRESS(even_address),
        .DATAIN(write_data[15:0]),
        .MASKWREN(4'b1111),
        .WREN(even_write_en),
        .CHIPSELECT(1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(read_data[15:0])
    );

    SB_SPRAM256KA ram1 (
        .ADDRESS(odd_address),
        .DATAIN(write_data[31:16]),
        .MASKWREN(4'b1111),
        .WREN(odd_write_en),
        .CHIPSELECT(1),
        .CLOCK(clk),
        .STANDBY(1'b0),
        .SLEEP(1'b0),
        .POWEROFF(1'b1),
        .DATAOUT(read_data[31:16])
    );

endmodule
