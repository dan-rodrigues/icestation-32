// This is based on the iCE40 SPRAM cell in the yosys techlibs

module spram_256k (
    input clk,
    input cs,
    input [13:0] address,
    input [15:0] write_data,
    input [3:0] mask,
    input write_en,
    output reg [15:0] read_data
);
    SB_SPRAM256KA ram (
        .ADDRESS(address),
        .DATAIN(write_data),
        .MASKWREN(mask),
        .WREN(write_en),
        .CHIPSELECT(cs),
        .CLOCK(clk),
        .STANDBY(0),
        .SLEEP(0),
        .POWEROFF(1),
        .DATAOUT(read_data)
    );
    
endmodule
