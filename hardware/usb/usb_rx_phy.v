// File ../../../../usb11_phy_vhdl/usb_rx_phy.vhd translated with vhd2vl v3.0 VHDL to Verilog RTL translator
// vhd2vl settings:
//  * Verilog Module Declaration Style: 2001

// vhd2vl is Free (libre) Software:
//   Copyright (C) 2001 Vincenzo Liguori - Ocean Logic Pty Ltd
//     http://www.ocean-logic.com
//   Modifications Copyright (C) 2006 Mark Gonzales - PMC Sierra Inc
//   Modifications (C) 2010 Shankar Giri
//   Modifications Copyright (C) 2002-2017 Larry Doolittle
//     http://doolittle.icarus.com/~larry/vhd2vl/
//   Modifications (C) 2017 Rodrigo A. Melo
//
//   vhd2vl comes with ABSOLUTELY NO WARRANTY.  Always check the resulting
//   Verilog for correctness, ideally with a formal verification tool.
//
//   You are welcome to redistribute vhd2vl under certain conditions.
//   See the license (GPLv2) file included with the source for details.

// The result of translation follows.  Its copyright status should be
// considered unchanged from the original VHDL.

// (c)EMARD
// License=GPL
// USB RX soft-core 
// differential data correctly recovered
// it works as drop in phy replacement
// but receives data more reliable than old core
// signal timings are not exactly identical as old core
// note that reset has direct logic here and some signals
// are named differently
// no timescale needed

module usb_rx_phy(
input wire clk,
input wire reset,
input wire usb_dif,
input wire usb_dp,
input wire usb_dn,
output wire [1:0] linestate,
output wire clk_recovered,
output wire clk_recovered_edge,
output wire rawdata,
input wire rx_en,
output wire rx_active,
output wire rx_error,
output wire valid,
output wire [7:0] data
);

parameter [31:0] C_clk_input_hz=6000000;
parameter [31:0] C_clk_bit_hz=1500000;
parameter [31:0] C_PA_bits=8;
// phase accumulator bits, 8 is ok
// input clock and reset
// differential D+/D- input



// entity
parameter C_PA_inc = 2 ** (C_PA_bits - 1) * C_clk_bit_hz / C_clk_input_hz;  // default PA increment
//  constant C_PA_phase: unsigned(C_PA_bits-2 downto 0) :=
//  (
//    C_PA_bits-2 => '0', -- 1/4
//    C_PA_bits-3 => '0', -- 1/8
//    C_PA_bits-4 => '0', -- 1/16
//    C_PA_bits-5 => '0', -- 1/32
//    others      => '1'
//  );
parameter C_PA_compensate = C_PA_inc[C_PA_bits - 2:0] + C_PA_inc[C_PA_bits - 2:0] + C_PA_inc[C_PA_bits - 2:0];
parameter C_PA_init = C_PA_compensate;
parameter C_valid_init = 8'h80;  // (data'high => '1', others => '0'); -- adjusted (1 bit early) to split stream at byte boundary
parameter C_idlecnt_init = 7'b1000000;  // (6 => '1', others => '0'); -- 6 data bits + 1 stuff bit
reg [C_PA_bits - 1:0] R_PA;
reg [1:0] R_dif_shift;
reg [1:0] R_clk_recovered_shift;
wire S_clk_recovered;
wire S_linebit; reg R_linebit_prev; wire S_bit; wire R_bit;
reg R_frame;
reg [7:0] R_data; reg [7:0] R_data_latch;
reg [7:0] R_valid = C_valid_init;
reg [1:0] R_linestate; reg [1:0] R_linestate_sync;
reg [1:0] R_linestate_prev;
reg [6:0] R_idlecnt = C_idlecnt_init;
reg R_preamble;
reg R_rxactive;
reg R_rx_en;
reg R_valid_prev;

  always @(posedge clk) begin
    if((usb_dn == 1'b1 || usb_dp == 1'b1) && rx_en == 1'b1) begin
      // during SE0, this avoids noise at differential input
      R_dif_shift <= {usb_dif,R_dif_shift[(1):1]};
    end
    R_clk_recovered_shift <= {S_clk_recovered,R_clk_recovered_shift[(1):1]};
    R_linestate <= {usb_dn,usb_dp};
    R_linestate_prev <= R_linestate;
    R_rx_en <= rx_en;
  end

  always @(posedge clk) begin
    if(R_dif_shift[(1)] != R_dif_shift[((1)) - 1]) begin
      R_PA[((C_PA_bits - 1)) - 1:0] <= C_PA_init[((C_PA_bits - 1)) - 1:0];
    end
    else begin
      R_PA <= R_PA + C_PA_inc;
    end
  end

  assign S_clk_recovered = R_PA[(C_PA_bits - 1)];
  assign clk_recovered = S_clk_recovered;
  assign clk_recovered_edge = R_clk_recovered_shift[1] != S_clk_recovered ? 1'b1 : 1'b0;
  //  clk_recovered_edge <= '1' when R_clk_recovered_shift(1) /= S_clk_recovered or R_linestate = "00" else '0';  -- NOTE: allows clocking during SE0
  assign S_linebit = R_dif_shift[((1)) - 1];
  assign S_bit =  ~(S_linebit ^ R_linebit_prev);
  // process that just shifts data and skips stuffed bit
  always @(posedge clk) begin
    if(R_rx_en == 1'b1 && reset == 1'b0) begin
      if(R_clk_recovered_shift[1] != S_clk_recovered) begin
        // synchronous with recovered clock
        if(R_linebit_prev == S_linebit) begin
          R_idlecnt <= {R_idlecnt[0],R_idlecnt[(6):1]};
          // shift (used for stuffed bit removal)
        end
        else begin
          R_idlecnt <= C_idlecnt_init;
          // reset
        end
        R_linebit_prev <= S_linebit;
        if((R_idlecnt[0] == 1'b0 && R_frame == 1'b1) || R_frame == 1'b0) begin
          // skips stuffed bit if in the frame
          if(R_linestate_sync == 2'b00) begin
            R_data <= {8{1'b0}};
            // SE0 resets data to prevent restarting the frame from old shifted data
          end
          else begin
            R_data <= {S_bit,R_data[(7):1]};
            // only payload bits, skips stuffed bit
          end
        end
        if(R_frame == 1'b1 && R_valid[1] == 1'b1) begin
          // timing early, gated to latch byte
          //          if R_frame = '1' then -- timing early
          //          if R_rxactive = '1' and R_valid(1) = '1' then -- timing exact but gated to latch byte
          //          if R_rxactive = '1' then -- timing exact, data exact
          R_data_latch <= R_data;
          // FIXME is there a better way (bit delay) than to register whole R_data byte
        end
      end
    end
  end

  always @(posedge clk) begin
    if(R_rx_en == 1'b1 && reset == 1'b0) begin
      if(R_clk_recovered_shift[1] != S_clk_recovered) begin
        // synchronous with recovered clock
        if(R_linestate_sync == 2'b00) begin
          // SE0 -- single-ended detection of the end of frame
          R_frame <= 1'b0;
          R_valid <= {8{1'b0}};
          R_preamble <= 1'b0;
          R_rxactive <= 1'b0;
        end
        else begin
          if(R_frame == 1'b1) begin
            // differential reading of the frame
            if(R_preamble == 1'b1) begin
              // wait for first preamble byte
              if(R_data[((7)) - 1:((7)) - 6] == 6'b100000) begin
                // 100000 detects end of preamble
                R_preamble <= 1'b0;
                R_valid <= C_valid_init;
                R_rxactive <= 1'b1;
                // timing 2 bits later
              end
              // exact timing: this makes the rxactive rise at the same time as orig phy
              //                  if S_bit = '1' and R_data(R_data'high downto R_data'high-3) = "0000" then -- 10000 detects end of preamble early
              //                    R_rxactive <= '1';
              //                  end if;
            end
            else begin
              // after preamble is found, circular-shift "R_valid" register
              if(R_idlecnt[0] == 1'b0) begin
                // if stuffed bit is not expected
                R_valid <= {R_valid[0],R_valid[(7):1]};
              end
              else begin
                // stuffed bit S_bit=0 is expected
                if(S_bit == 1'b1) begin
                  // if stuffed bit is wrong (line probably idle)
                  R_valid <= {8{1'b0}};
                  // drop frame
                  R_frame <= 1'b0;
                  R_rxactive <= 1'b0;
                end
              end
              // skip stuffed bit
            end
          end
          else begin
            // R_frame = '0'
            //              if S_bit = '0' and R_data(R_data'high downto R_data'high-1) = "11" then -- exact timing differential detection of the start of frame
            if(R_data[(7):((7)) - 5] == 6'b000111) begin
              // later timing differential detection of the start of frame
              R_frame <= 1'b1;
              R_preamble <= 1'b1;
              R_valid <= {8{1'b0}};
              R_rxactive <= 1'b0;
            end
          end
        end
        R_linestate_sync <= R_linestate;
      end
      // synchronous with recovered clock
    end
    else begin
      // R_rx_en = '0'
      R_valid <= {8{1'b0}};
      R_frame <= 1'b0;
      R_rxactive <= 1'b0;
    end
  end

  assign data = R_data_latch;
  // delayed 1 cycle in order to detect SE0 reliably
  assign rawdata = R_linebit_prev;
  assign linestate = R_linestate;
  // timing 1 bit early
  //  linestate <= R_linestate_prev; -- exact timing to match timing with original
  //  rx_active <= R_rxactive; -- exact timing
  assign rx_active = R_frame;
  // timing early
  assign rx_error = 1'b0;
  //B_valid_1clk: block
  //begin
  always @(posedge clk) begin
    R_valid_prev <= R_valid[0];
  end

  //    valid <= '1' when R_valid_prev = '0' and R_valid(0) = '1' else '0'; -- single clk cycle
  assign valid = R_valid[0] &  ~R_valid_prev;
    // single clk cycle
  //    valid <= R_valid(0); -- spans several clk cycles
  //end block;
// architecture

endmodule
