// File hdl/spdif_tx.vhd translated with vhd2vl v3.0 VHDL to Verilog RTL translator
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

// https://ackspace.nl/wiki/SP/DIF_transmitter_project
// EMARD's modification: phase accu clk divider
// no timescale needed

module spdif_tx(
input wire clk,
input wire [23:0] data_in,
output reg address_out,
output wire spdif_out
);

parameter [31:0] C_clk_freq=25000000;
parameter [31:0] C_sample_freq=48000;
// Hz sample rate
// system clock
// 24-bit signed value
// 1 address bit means stereo only



// math to digitaly divide input clock into 128x Fsample (6.144MHz for 48K samplerate)
parameter C_phase_accu_bits = 24;  //clock divider phase accumulator
// constant C_phase_increment: integer := C_sample_freq * 2**(C_phase_accu_bits+7) / C_clk_freq; -- exact expression but it overflows with trellis
parameter C_phase_increment = (C_sample_freq / 100) * 2 ** (C_phase_accu_bits - 3) / (C_clk_freq / 100) * 2 ** 10;  // works with trellis up to C_clk_freq = 100 MHz
reg [C_phase_accu_bits - 1:0] R_phase_accu;
reg [1:0] R_clkdiv_shift;
reg [23:0] data_in_buffer;
reg [5:0] bit_counter = 1'b0;
reg [8:0] frame_counter = 1'b0;
reg data_biphase = 1'b0;
reg [7:0] data_out_buffer;
reg parity;
reg [23:0] channel_status_shift;
wire [23:0] channel_status = 24'b001000000000000001000000;

  always @(posedge clk) begin
    R_phase_accu <= R_phase_accu + C_phase_increment;
    R_clkdiv_shift <= {R_clkdiv_shift[0],R_phase_accu[C_phase_accu_bits - 1]};
  end

  always @(posedge clk) begin
    if(R_clkdiv_shift == 2'b01) begin
      bit_counter <= bit_counter + 1;
    end
  end

  always @(posedge clk) begin
    if(R_clkdiv_shift == 2'b01) begin
      parity <= data_in_buffer[23] ^ data_in_buffer[22] ^ data_in_buffer[21] ^ data_in_buffer[20] ^ data_in_buffer[19] ^ data_in_buffer[18] ^ data_in_buffer[17] ^ data_in_buffer[16] ^ data_in_buffer[15] ^ data_in_buffer[14] ^ data_in_buffer[13] ^ data_in_buffer[12] ^ data_in_buffer[11] ^ data_in_buffer[10] ^ data_in_buffer[9] ^ data_in_buffer[8] ^ data_in_buffer[7] ^ data_in_buffer[6] ^ data_in_buffer[5] ^ data_in_buffer[4] ^ data_in_buffer[3] ^ data_in_buffer[2] ^ data_in_buffer[1] ^ data_in_buffer[0] ^ channel_status_shift[23];
      if(bit_counter == 6'b000011) begin
        data_in_buffer <= data_in;
      end
      if(bit_counter == 6'b111111) begin
        if(frame_counter == 9'b101111111) begin
          frame_counter <= {9{1'b0}};
        end
        else begin
          frame_counter <= frame_counter + 1;
        end
      end
    end
  end

  always @(posedge clk) begin
    if(R_clkdiv_shift == 2'b01) begin
      if(bit_counter == 6'b111111) begin
        if(frame_counter == 9'b101111111) begin
          // next frame is 0, load preamble Z
          address_out <= 1'b0;
          channel_status_shift <= channel_status;
          data_out_buffer <= 8'b10011100;
        end
        else begin
          if(frame_counter[0] == 1'b1) begin
            // next frame is even, load preamble X
            channel_status_shift <= {channel_status_shift[22:0],1'b0};
            data_out_buffer <= 8'b10010011;
            address_out <= 1'b0;
          end
          else begin
            // next frame is odd, load preable Y
            data_out_buffer <= 8'b10010110;
            address_out <= 1'b1;
          end
        end
      end
      else begin
        if(bit_counter[2:0] == 3'b111) begin
          // load new part of data into buffer
          case(bit_counter[5:3])
          3'b000 : begin
            data_out_buffer <= {1'b1,data_in_buffer[0],1'b1,data_in_buffer[1],1'b1,data_in_buffer[2],1'b1,data_in_buffer[3]};
          end
          3'b001 : begin
            data_out_buffer <= {1'b1,data_in_buffer[4],1'b1,data_in_buffer[5],1'b1,data_in_buffer[6],1'b1,data_in_buffer[7]};
          end
          3'b010 : begin
            data_out_buffer <= {1'b1,data_in_buffer[8],1'b1,data_in_buffer[9],1'b1,data_in_buffer[10],1'b1,data_in_buffer[11]};
          end
          3'b011 : begin
            data_out_buffer <= {1'b1,data_in_buffer[12],1'b1,data_in_buffer[13],1'b1,data_in_buffer[14],1'b1,data_in_buffer[15]};
          end
          3'b100 : begin
            data_out_buffer <= {1'b1,data_in_buffer[16],1'b1,data_in_buffer[17],1'b1,data_in_buffer[18],1'b1,data_in_buffer[19]};
          end
          3'b101 : begin
            data_out_buffer <= {1'b1,data_in_buffer[20],1'b1,data_in_buffer[21],1'b1,data_in_buffer[22],1'b1,data_in_buffer[23]};
          end
          3'b110 : begin
            data_out_buffer <= {5'b10101,channel_status_shift[23],1'b1,parity};
          end
          default : begin
          end
          endcase
        end
        else begin
          data_out_buffer <= {data_out_buffer[6:0],1'b0};
        end
      end
    end
  end

  always @(posedge clk) begin
    if(R_clkdiv_shift == 2'b01) begin
      if(data_out_buffer[(7)] == 1'b1) begin
        data_biphase <=  ~data_biphase;
      end
    end
  end

  assign spdif_out = data_biphase;

endmodule
