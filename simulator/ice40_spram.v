module SB_SPRAM256KA (
    input [13:0] ADDRESS,
    input [15:0] DATAIN,
    input [3:0] MASKWREN,
    input WREN, CHIPSELECT, CLOCK, STANDBY, SLEEP, POWEROFF,
    output reg [15:0] DATAOUT
);
`ifndef BLACKBOX
`ifndef EQUIV
    reg [15:0] mem [0:16383];
    wire off = SLEEP || !POWEROFF;
    integer i;

    always @(posedge CLOCK) begin
        if (off) begin
            DATAOUT <= 0;
        end else
        if (STANDBY) begin
            DATAOUT <= 0;
        end else
        if (CHIPSELECT) begin
            if (!WREN) begin
                DATAOUT <= mem[ADDRESS];
            end else begin
                if (MASKWREN[0]) mem[ADDRESS][ 3: 0] <= DATAIN[ 3: 0];
                if (MASKWREN[1]) mem[ADDRESS][ 7: 4] <= DATAIN[ 7: 4];
                if (MASKWREN[2]) mem[ADDRESS][11: 8] <= DATAIN[11: 8];
                if (MASKWREN[3]) mem[ADDRESS][15:12] <= DATAIN[15:12];
                DATAOUT <= 0;
            end
        end
    end
endmodule