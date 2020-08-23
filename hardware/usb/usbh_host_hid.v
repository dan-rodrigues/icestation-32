// File ../../../../usbhost/usbh_host_hid_convertible.vhd translated with vhd2vl v3.0 VHDL to Verilog RTL translator
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
// USB HOST for HID devices
// drives SIE directly
// suggested reading
// http://www.usbmadesimple.co.uk/
// online USB descriptor parser
// https://eleccelerator.com/usbdescreqparser/
// no timescale needed

module usbh_host_hid
#(
parameter C_setup_retry=4,
parameter C_setup_interval=17,
parameter C_report_interval=16,
parameter C_report_endpoint=1,
parameter C_report_length=20, // bytes
parameter C_report_length_strict=0, // 0:accept length>0, 1:require exact length
parameter C_keepalive_setup=1'b1,
parameter C_keepalive_status=1'b1,
parameter C_keepalive_report=1'b1,
parameter C_keepalive_phase_bits=12, // keepalive/sof frequency 12:low speed, 15:full speed
// NOTE: C_keepalive_phase_bits=12 at C_usb_speed=0 ( 6 MHz)
//    or C_keepalive_phase_bits=15 at C_usb_speed=1 (48 MHz)
//  will send keepalive/SOF every 0.68 ms
// USB standard requires keepalive < 1 ms but SOF every 1 ms +-1%
// so far all full-speed devices tested accept SOF at 0.68 ms rate
parameter C_keepalive_phase=2048, // 4044:KEEPALIVE low speed, 2048:low/full speed good for both
parameter C_keepalive_type=1'b1, // 1:KEEPALIVE low speed (may work for full speed, LUT saver), 0:SOF full speed
parameter C_setup_rom_file="usbh_setup_rom.mem",
parameter C_setup_rom_len=16,
// FIXME: For C_usb_speed=1 reset timing is 4x shorter than required by USB standard
parameter C_usb_speed=0 // '0':6 MHz low speed '1':48 MHz full speed
)
(
input wire clk, // main clock input
input wire usb_dif, // differential or single-ended input
inout wire usb_dp, // single ended bidirectional
inout wire usb_dn,
input wire bus_reset, // force bus reset and setup (similar to re-plugging USB device)
output wire [7:0] led, // HID debugging
output wire [15:0] rx_count, // rx response length
output wire rx_done, // rx done
output wire [C_report_length * 8 - 1:0] hid_report, // HID report (filtered with expected length)
output wire hid_valid
);

wire clk_usb;  // 48 or 60 MHz
wire S_rxd;
wire S_rxdp; wire S_rxdn;
wire S_txdp; wire S_txdn; wire S_txoe;
wire [63:0] S_oled;
wire [1:0] S_LINESTATE;
wire S_LINECTRL;
wire S_TXVALID;
wire S_TXREADY;
wire S_RXVALID;
wire S_RXACTIVE;
wire S_RXERROR;
wire [7:0] S_DATAIN;
wire [7:0] S_DATAOUT;
wire S_BREAK;  // UTMI debug
wire S_sync_err; wire S_bit_stuff_err; wire S_byte_err;
reg [7:0] R_setup_rom_addr = 1'b0; reg [7:0] R_setup_rom_addr_acked = 1'b0;

reg [7:0] C_setup_rom[0:C_setup_rom_len-1];  // ( x"00", x"05", x"01", x"00", x"00", x"00", x"00", x"00", x"00", x"09", x"01", x"00", x"00", x"00", x"00", x"00" );
initial $readmemh(C_setup_rom_file, C_setup_rom);

reg [2:0] R_setup_byte_counter = 1'b0;
reg ctrlin;
reg datastatus = 1'b0;
parameter C_datastatus_enable = 1'b0;
reg [15:0] R_packet_counter;
reg [1:0] R_state = 2'b00;
parameter C_STATE_DETACHED = 2'b00;
parameter C_STATE_SETUP = 2'b01;
parameter C_STATE_REPORT = 2'b10;
parameter C_STATE_DATA = 2'b11;
reg [C_setup_retry:0] R_retry;
reg [17:0] R_slow = 0;  // 2**17 clocks = 22 ms interval at 6 MHz
reg R_reset_pending;
reg R_reset_accepted;
// sie wires
reg start_i = 1'b0;
reg in_transfer_i = 1'b0;
reg sof_transfer_i = 1'b0;
reg resp_expected_i = 1'b0;
reg [7:0] token_pid_i = 0;
reg [6:0] token_dev_i = 0;
reg [3:0] token_ep_i = 0;
reg [15:0] data_len_i = 0;
reg data_idx_i = 1'b0;
wire [7:0] tx_data_i;
wire ack_o;
wire tx_pop_o;
wire [7:0] rx_data_o;
wire rx_push_o;
wire tx_done_o;
wire rx_done_o;
wire crc_err_o;
wire timeout_o;
wire [7:0] response_o;
wire [15:0] rx_count_o;
wire idle_o;
reg R_set_address_found;
reg [6:0] R_dev_address_requested;
reg [6:0] R_dev_address_confirmed;
reg [7:0] R_stored_response;
reg [15:0] R_wLength;
reg [15:0] R_bytes_remaining;
wire [7:0] S_expected_response;
reg R_advance_data = 1'b0;
wire S_transmission_over;
reg R_timeout;  // rising edge tracking
reg R_first_byte_0_found;

reg [7:0] R_report_buf[0:C_report_length - 1];
reg [15:0] R_rx_count;
reg R_hid_valid;
reg R_crc_err;
reg R_rx_done;

  generate if (C_usb_speed == 1) begin: G_full_speed
    assign clk_usb = clk;
    // 48 MHz with "usb_rx_phy_48MHz.vhd" or 60 MHz with "usb_rx_phy_60MHz.vhd"
    // transciever soft-core
    //usb_fpga_pu_dp <= '0'; -- D+ pulldown for USB host mode
    //usb_fpga_pu_dn <= '0'; -- D- pulldown for USB host mode
    assign S_rxd = usb_dif;
    // differential input reads D+
    //S_rxd <= usb_dp; -- single-ended input reads D+ may work as well
    assign S_rxdp = usb_dp;
    // single-ended input reads D+
    assign S_rxdn = usb_dn;
    // single-ended input reads D-
    assign usb_dp = S_txoe == 1'b0 ? S_txdp : 1'bZ;
    assign usb_dn = S_txoe == 1'b0 ? S_txdn : 1'bZ;
  end
  endgenerate
  generate if (C_usb_speed == 0) begin: G_low_speed
    assign clk_usb = clk;
    // 6 MHz
    // transciever soft-core
    // for low speed USB, here are swaped D+ and D-
    //usb_fpga_pu_dp <= '0'; -- D+ pulldown for USB host mode
    //usb_fpga_pu_dn <= '0'; -- D- pulldown for USB host mode
    assign S_rxd = ~usb_dif;
    // differential input reads inverted D+ for low speed
    //S_rxd <= not usb_dp; -- single-ended input reads D+ may work as well
    assign S_rxdp = usb_dn;
    // single-ended input reads D- for low speed
    assign S_rxdn = usb_dp;
    // single-ended input reads D+ for low speed
    assign usb_dp = S_txoe == 1'b0 ? S_txdn : 1'bZ;
    assign usb_dn = S_txoe == 1'b0 ? S_txdp : 1'bZ;
  end
  endgenerate
  reg R_txover_debug = 1'b1;
  assign led = {R_reset_pending, R_txover_debug, R_setup_rom_addr_acked[3], S_LINESTATE, R_state};
  // USB1.1 PHY soft-core
  usb_phy
  E_usb11_phy(
    .clk(clk_usb),
    // full speed: 48 MHz or 60 MHz, low speed: 6 MHz or 7.5 MHz
    .rst(~bus_reset),
    // 1-don't reset, 0-hold reset
    .phy_tx_mode(1'b1),
    // 1-differential, 0-single-ended
    // UTMI interface to usb-serial core
    .LineCtrl_i(S_LINECTRL),
    .TxValid_i(S_TXVALID),
    .DataOut_i(S_DATAOUT),
    // 8-bit TX
    .TxReady_o(S_TXREADY),
    .RxValid_o(S_RXVALID),
    .DataIn_o(S_DATAIN),
    // 8-bit RX
    .RxActive_o(S_RXACTIVE),
    .RxError_o(S_RXERROR),
    .LineState_o(S_LINESTATE),
    // 2-bit
    // debug interface
    .sync_err_o(S_sync_err),
    .bit_stuff_err_o(S_bit_stuff_err),
    .byte_err_o(S_byte_err),
    // transciever interface to hardware
    .rxd(S_rxd),
    // differential input from D+
    .rxdp(S_rxdp),
    // single-ended input from D+
    .rxdn(S_rxdn),
    // single-ended input from D-
    .txdp(S_txdp),
    // single-ended output to D+
    .txdn(S_txdn),
    // single-ended output to D-
    // 3-state control: 0-output, 1-input
    .txoe(S_txoe));


  // address advance, retry logic, set_address accpetance
  assign S_transmission_over = rx_done_o == 1'b1 || (timeout_o == 1'b1 && R_timeout == 1'b0) ? 1'b1 : 1'b0;
  always @(posedge clk_usb) begin
    R_timeout <= timeout_o;
    if(R_reset_accepted == 1'b1) begin
      R_setup_rom_addr <= 8'd0;
      R_setup_rom_addr_acked <= 8'd0;
      R_setup_byte_counter <= 3'd0;
      R_retry <= 0;
      R_reset_pending <= 1'b0;
      R_txover_debug <= 1'b0;
    end
    else begin
      if(bus_reset == 1'b1) begin
        R_reset_pending <= 1'b1;
      end
      case(R_state)
      C_STATE_DETACHED : begin
        // start from unitialized device
        R_dev_address_confirmed <= 7'd0;
        R_retry <= 0;
      end
      C_STATE_SETUP : begin
        if(S_transmission_over == 1'b1) begin
          R_txover_debug <= 1'b1;
          // decide to continue with next setup or to retry
          case(token_pid_i)
          8'h2D : begin
            if(rx_done_o == 1'b1 && response_o == 8'hD2) begin
              // ACK to SETUP
              // continue with next setup
              R_setup_rom_addr_acked <= R_setup_rom_addr;
              R_retry <= 0;
            end
            else begin
              // failed, rewind to unacknowledged setup and retry
              R_setup_rom_addr <= R_setup_rom_addr_acked;
              if(R_retry[C_setup_retry] == 1'b0) begin
                R_retry <= R_retry + 1;
              end
            end
          end
          endcase
        end
        else begin
          // transmission is going on -- advance address
          if(tx_pop_o == 1'b1) begin
            R_setup_rom_addr <= R_setup_rom_addr + 1;
            R_setup_byte_counter <= R_setup_byte_counter + 1;
          end
        end
        R_stored_response <= 8'h00;
      end
      C_STATE_REPORT : begin
        if(S_transmission_over == 1'b1) begin
          // multiple timeouts at waiting for response will detach
          if(timeout_o == 1'b1 && R_timeout == 1'b0) begin
            if(R_retry[C_setup_retry] == 1'b0) begin
              R_retry <= R_retry + 1;
            end
          end
          else begin
            if(rx_done_o == 1'b1) begin
              R_retry <= 0;
            end
          end
        end
      end
      default : begin
        // C_STATE_DATA =>
        if(S_transmission_over == 1'b1) begin
          case(token_pid_i)
          8'hE1 : begin
            if(rx_done_o == 1'b1 && response_o == 8'hD2) begin
              // ACK to DATA OUT
              R_stored_response <= response_o;
              // continue with next setup
              R_setup_rom_addr_acked <= R_setup_rom_addr;
              R_retry <= 0;
            end
            else begin
              // failed, rewind to unacknowledged setup and retry
              R_setup_rom_addr <= R_setup_rom_addr_acked;
              if(R_retry[C_setup_retry] == 1'b0) begin
                R_retry <= R_retry + 1;
              end
            end
          end
          default : begin
            // x"69"
            if(timeout_o == 1'b1 && R_timeout == 1'b0) begin
              if(R_retry[C_setup_retry] == 1'b0) begin
                R_retry <= R_retry + 1;
              end
            end
            else begin
              if(rx_done_o == 1'b1) begin
                R_stored_response <= response_o;
                // SIE quirk: set address returns 4B = PID_DATA1 instead of D2
                if(response_o == 8'h4B) begin
                  R_retry <= 0;
                  R_dev_address_confirmed <= R_dev_address_requested;
                end
                else // set address failed
                  R_retry <= R_retry + 1;
              end
            end
          end
          endcase
        end
        else begin
          // transmission is going on -- advance address but only data, not setup counter
          if(tx_pop_o == 1'b1) begin
            R_setup_rom_addr <= R_setup_rom_addr + 1;
          end
        end
      end
      endcase
    end
    // reset accepted
  end

  assign tx_data_i = C_setup_rom[R_setup_rom_addr];
  // B_requested_set_address: block
  // NOTE: it works only if each setup packet in ROM is 8 bytes
  // if data is added to ROM, then R_setup_rom_addr should be
  // replaced with another register that tracks actual offset from
  // setup packet
  always @(posedge clk_usb) begin
    case(R_state)
    C_STATE_DETACHED : begin
      R_dev_address_requested <= 7'd0;
      R_set_address_found <= 1'b0;
      R_wLength <= 16'h0000;
    end
    C_STATE_SETUP : begin
      case(R_setup_byte_counter[2:0])
      3'b000 : begin
        // every 8 bytes, 1st byte
        if(tx_data_i == 8'h00) begin
          R_first_byte_0_found <= 1'b1;
        end
        else begin
          R_first_byte_0_found <= 1'b0;
        end
      end
      3'b001 : begin
        // every 8 bytes, 2nd byte
        if(tx_data_i == 8'h05) begin
          R_set_address_found <= R_first_byte_0_found;
        end
        R_wLength <= 16'h0000;
      end
      3'b010 : begin
        // every 8 bytes, 3rd byte
        if(R_set_address_found == 1'b1) begin
          // every 8 bytes, 3rd byte
          R_dev_address_requested <= tx_data_i[6:0];
        end
      end
      3'b110 : begin
        // every 8 bytes, 7th byte
        R_wLength[7:0] <= tx_data_i;
      end
      3'b111 : begin
        // every 8 bytes, 8th byte wLength high byte currently forced to 0
        R_wLength[15:8] <= 8'h00;
        // tx_data_i;
      end
      endcase
    end
    default : begin
      R_wLength <= 16'h0000;
      R_set_address_found <= 1'b0;
    end
    endcase
  end

  reg [10:0] R_sof_counter;
  // FIXME not sure how to map counter to dev and ep
  wire [6:0] S_sof_dev = R_sof_counter[10:4];
  wire [3:0] S_sof_ep  = R_sof_counter[3:0];

  assign S_expected_response = data_idx_i == 1'b1 ? 8'h4B : 8'hC3;
  always @(posedge clk_usb) begin
    R_advance_data <= 1'b0;
    // default
    case(R_state)
    C_STATE_DETACHED : begin
      // start from unitialized device
      R_reset_accepted <= 1'b0;
      if(S_LINESTATE == 2'b01) begin
        if(R_slow[17] == 1'b0) begin
          // 22 ms
          R_slow <= R_slow + 1;
        end
        else begin
          R_slow <= 18'd0;
          sof_transfer_i <= 1'b1;
          // transfer SOF or linectrl
          in_transfer_i <= 1'b1;
          // 0:SOF, 1:linectrl
          token_pid_i[1:0] <= 2'b11;
          // linectrl: bus reset
          token_dev_i <= 7'd0;
          // after reset device address will be 0
          resp_expected_i <= 1'b0;
          ctrlin <= 1'b0;
          start_i <= 1'b1;
          R_packet_counter <= 16'h0000;
          R_sof_counter <= 11'd0;
          R_state <= C_STATE_SETUP;
        end
      end
      else begin
        start_i <= 1'b0;
        R_slow <= 18'd0;
      end
    end
    C_STATE_SETUP : begin
      // send setup sequence (enumeration)
      if(idle_o == 1'b1) begin
        if(R_slow[C_setup_interval] == 1'b0) begin
          R_slow <= R_slow + 1;
          if(R_retry[C_setup_retry] == 1'b1) begin
            R_reset_accepted <= 1'b1;
            R_state <= C_STATE_DETACHED;
          end
          if(R_slow[C_keepalive_phase_bits-1:0] == C_keepalive_phase && C_keepalive_setup == 1'b1) begin
            // keepalive: first at 0.35 ms, then every 0.68 ms
            // keepalive signal
            sof_transfer_i <= 1'b1;
            // transfer SOF or linectrl
            in_transfer_i <= C_keepalive_type;
            // 0:SOF, 1:linectrl
            if(C_keepalive_type)
              token_pid_i[1:0] <= 2'b00;
            else
            begin
              token_pid_i <= 8'hA5;
              token_dev_i <= S_sof_dev;
              token_ep_i  <= S_sof_ep;
              data_len_i  <= 16'h0000;
              R_sof_counter <= R_sof_counter + 1;
            end
            // linectrl: keepalive
            resp_expected_i <= 1'b0;
            start_i <= 1'b1;
          end
          else begin
            start_i <= 1'b0;
          end
        end
        else begin
          // time passed, send next setup packet or read status or read response
          R_slow <= 18'd0;
          sof_transfer_i <= 1'b0;
          token_dev_i <= R_dev_address_confirmed;
          token_ep_i <= 4'h0;
          resp_expected_i <= 1'b1;
          if(R_setup_rom_addr == C_setup_rom_len) begin
            data_len_i <= 16'h0000;
            start_i <= 1'b0;
            R_state <= C_STATE_REPORT;
          end
          else begin
            in_transfer_i <= 1'b0;
            token_pid_i <= 8'h2D;
            data_len_i <= 16'h0008;
            if(R_set_address_found == 1'b1 || ctrlin == 1'b1 || R_wLength != 16'h0000) begin
              R_bytes_remaining <= R_wLength;
              //                  R_bytes_remaining <= x"0000";
              if(R_set_address_found == 1'b1) begin
                ctrlin <= 1'b1;
                datastatus <= 1'b0;
              end
              else begin
                datastatus <= C_datastatus_enable;
                // after IN send status OUT
              end
              data_idx_i <= 1'b1;
              // next sending as DATA1
              R_state <= C_STATE_DATA;
            end
            else begin
              data_idx_i <= 1'b0;
              // send as DATA0
              ctrlin <= tx_data_i[7];
              R_packet_counter <= R_packet_counter + 1;
              start_i <= 1'b1;
            end
          end
        end
      end
      else begin
        // not idle
        start_i <= 1'b0;
      end
    end
    C_STATE_REPORT : begin
      // request report (send IN request)
      if(idle_o == 1'b1) begin
        if(R_slow[C_report_interval] == 1'b0) begin
          R_slow <= R_slow + 1;
          if(R_slow[C_keepalive_phase_bits-1:0] == C_keepalive_phase && C_keepalive_report == 1'b1) begin
            // keepalive: first at 0.35 ms, then every 0.68 ms
            // keepalive signal
            sof_transfer_i <= 1'b1;
            // transfer SOF or linectrl
            in_transfer_i <= C_keepalive_type;
            // 0:SOF, 1:linectrl
            if(C_keepalive_type)
              token_pid_i[1:0] <= 2'b00;
            else
            begin
              token_pid_i <= 8'hA5;
              token_dev_i <= S_sof_dev;
              token_ep_i  <= S_sof_ep;
              data_len_i  <= 16'h0000;
              R_sof_counter <= R_sof_counter + 1;
            end
            // linectrl: keepalive
            resp_expected_i <= 1'b0;
            start_i <= 1'b1;
          end
          else begin
            start_i <= 1'b0;
          end
        end
        else begin
          R_slow <= 18'd0;
          // HOST: < SYNC ><  IN  ><ADR0>EP1 CRC5
          // D+ ___-_-_-_---_--___-_-_-_-__-_-_--________
          // D- ---_-_-_-___-__---_-_-_-_--_-_-__--__----
          //       00000001100101100000000100000101
          //       < 0  8 >< 9  6 ><  0  ><1 ><CRC>
          sof_transfer_i <= 1'b0;
          in_transfer_i <= 1'b1;
          token_pid_i <= 8'h69;
          if(C_keepalive_type == 1'b0)
            token_dev_i <= R_dev_address_confirmed;
          token_ep_i <= C_report_endpoint;
          data_idx_i <= 1'b0;
          //              R_packet_counter <= R_packet_counter + 1;
          resp_expected_i <= 1'b1;
          start_i <= 1'b1;
          if(R_reset_pending == 1'b1 || S_LINESTATE == 2'b00 || R_retry[C_setup_retry] == 1'b1) begin
            R_reset_accepted <= 1'b1;
            R_state <= C_STATE_DETACHED;
          end
        end
      end
      else begin
        // not idle
        start_i <= 1'b0;
      end
    end
    default : begin
      // C_STATE_DATA receive or send data phase
      if(idle_o == 1'b1) begin
        if(R_slow[C_setup_interval] == 1'b0) begin
          R_slow <= R_slow + 1;
          if(R_retry[C_setup_retry] == 1'b1) begin
            R_reset_accepted <= 1'b1;
            R_state <= C_STATE_DETACHED;
          end
          if(R_slow[C_keepalive_phase_bits-1:0] == C_keepalive_phase && C_keepalive_status == 1'b1) begin
            // keepalive: first at 0.35 ms, then every 0.68 ms
            // keepalive signal
            sof_transfer_i <= 1'b1;
            // transfer SOF or linectrl
            in_transfer_i <= C_keepalive_type;
            // 0:SOF, 1:linectrl
            if(C_keepalive_type)
              token_pid_i[1:0] <= 2'b00;
            else
            begin
              token_pid_i <= 8'hA5;
              token_dev_i <= S_sof_dev;
              token_ep_i  <= S_sof_ep;
              data_len_i  <= 16'h0000;
              R_sof_counter <= R_sof_counter + 1;
            end
            // linectrl: keepalive
            resp_expected_i <= 1'b0;
            start_i <= 1'b1;
          end
          else begin
            start_i <= 1'b0;
          end
        end
        else begin
          // time to send request
          R_slow <= 18'd0;
          sof_transfer_i <= 1'b0;
          in_transfer_i <= ctrlin;
          if(ctrlin == 1'b1) begin
            token_pid_i <= 8'h69;
            // 69=IN
          end
          else begin
            token_pid_i <= 8'hE1;
            // E1=OUT
          end
          if(C_keepalive_type == 1'b0)
            token_dev_i <= R_dev_address_confirmed;
          token_ep_i <= 4'h0;
          resp_expected_i <= 1'b1;
          if(R_bytes_remaining != 16'h0000) begin
            if(R_bytes_remaining[15:3] != 13'd0) begin
              // 8 or more remaining bytes
              data_len_i <= 16'h0008;
              // transmit 8 bytes in a packet
            end
            else begin
              // less than 8 remaining
              data_len_i <= {13'd0,R_bytes_remaining[2:0]};
              // transmit remaining bytes (less than 8)
            end
          end
          else begin
            data_len_i <= 16'h0000;
          end
          if(ctrlin == 1'b1) begin
            if(R_stored_response == 8'h4B || R_stored_response == 8'hC3) begin
              // SIE quirk: 4B is returned for 0-len packet instead of D2 ACK
              R_advance_data <= 1'b1;
              if(R_bytes_remaining[15:3] == 13'd0) begin
                ctrlin <= 1'b0;
                if(datastatus == 1'b0) begin
                  R_state <= C_STATE_SETUP;
                end
                // after all IN packets, send 0-length OUT packet as confirmation.
                // TODO: see standard what is correct data_idx_i = 0 or 1
              end
              else begin
                R_advance_data <= 1'b1;
                R_packet_counter <= R_packet_counter + 1;
                start_i <= 1'b1;
              end
            end
            else begin
              R_packet_counter <= R_packet_counter + 1;
              start_i <= 1'b1;
            end
          end
          else begin
            // ctrlin = 0
            if(R_stored_response == 8'hD2) begin
              R_advance_data <= 1'b1;
              if(datastatus == 1'b1) begin
                R_state <= C_STATE_SETUP;
              end
              else begin
                if(R_bytes_remaining == 16'h0000) begin
                  ctrlin <= 1'b1;
                  // OUT phase will finish with IN 0-length packet
                end
              end
            end
            else begin
              R_packet_counter <= R_packet_counter + 1;
              start_i <= 1'b1;
            end
          end
        end
      end
      else begin
        start_i <= 1'b0;
      end
      // always during C_STATE_DATA
      // counts bytes required for DATA state, then exit
      if(R_advance_data == 1'b1) begin
        if(R_bytes_remaining != 16'h0000) begin
          if(R_bytes_remaining[15:3] != 13'd0) begin
            // 8 or more remaining bytes
            R_bytes_remaining[15:3] <= R_bytes_remaining[15:3] - 1;
          end
          else begin
            // less than 8 remaining
            R_bytes_remaining[2:0] <= 3'b000;
          end
          data_idx_i <=  ~data_idx_i;
          // alternates DATA 0/1
        end
        else begin
          if(ctrlin == 1'b1) begin
            data_idx_i <= 1'b1;
            // always DATA1 at last IN
          end
        end
      end
    end
    endcase
  end

  wire [6:0] reverse_token_dev_i = {
    token_dev_i[0], token_dev_i[1], token_dev_i[2], token_dev_i[3],
    token_dev_i[4], token_dev_i[5], token_dev_i[6]
  };
  wire [3:0] reverse_token_ep_i = {
    token_ep_i[0], token_ep_i[1], token_ep_i[2], token_ep_i[3]
  };
  // USB SIE-core
  usbh_sie usb_sie_core(
    .clk_i(clk_usb), // low speed: 6 MHz, full speed: 48 MHz
    .rst_i(bus_reset),
    .start_i(start_i),
    .in_transfer_i(in_transfer_i),
    .sof_transfer_i(sof_transfer_i),
    .resp_expected_i(resp_expected_i),
    .token_pid_i(token_pid_i),
    .token_dev_i(reverse_token_dev_i),
    .token_ep_i(reverse_token_ep_i),
    .data_len_i(data_len_i),
    .data_idx_i(data_idx_i),
    .tx_data_i(tx_data_i),
    .ack_o(ack_o),
    .tx_pop_o(tx_pop_o),
    .rx_data_o(rx_data_o),
    .rx_push_o(rx_push_o),
    .tx_done_o(tx_done_o),
    .rx_done_o(rx_done_o),
    .crc_err_o(crc_err_o),
    .timeout_o(timeout_o),
    .response_o(response_o),
    .rx_count_o(rx_count_o),
    .idle_o(idle_o),
    .utmi_txready_i(S_TXREADY),
    .utmi_data_i(S_DATAIN),
    .utmi_rxvalid_i(S_RXVALID),
    .utmi_rxactive_i(S_RXACTIVE),
    .utmi_linectrl_o(S_LINECTRL),
    .utmi_data_o(S_DATAOUT),
    .utmi_txvalid_o(S_TXVALID));

  // B_report_reader: block
  wire S_report_length_ok = C_report_length_strict ? R_rx_count == C_report_length : R_rx_count != 0;
  always @(posedge clk_usb) begin
    R_rx_count <= rx_count_o;
    // to offload routing (apart from this, "rx_count_o" could be used directly)
    if(rx_push_o == 1'b1) begin
      R_report_buf[R_rx_count] <= rx_data_o;
    end
    // rx_done_o is '1' for several clocks...
    // action on falling edge
    R_rx_done <= rx_done_o;
    if(R_rx_done == 1'b1 && rx_done_o == 1'b0) begin
      R_crc_err <= 1'b0;
    end
    else begin
      if(crc_err_o == 1'b1) begin
        R_crc_err <= 1'b1;
      end
    end
    // at falling edge of rx_done it should not accumulate any crc error
    if(R_rx_done == 1'b1 && rx_done_o == 1'b0 && R_crc_err == 1'b0 && timeout_o == 1'b0 && R_state == C_STATE_REPORT && S_report_length_ok) begin
      R_hid_valid <= 1'b1;
    end
    else begin
      R_hid_valid <= 1'b0;
    end
  end

  genvar i;
  generate for (i=0; i <= C_report_length - 1; i = i + 1) begin: G_report
      assign hid_report[i*8+7:i*8] = R_report_buf[i];
  end
  endgenerate
  assign hid_valid = R_hid_valid;
  assign rx_count = rx_count_o;
  // report byte count directly from SIE
  //rx_count <= R_packet_counter; -- debugging setup problems
  //rx_count(7 downto 0) <= R_stored_response;
  //rx_count(7 downto 0) <= R_E1_response;
  //rx_count(R_retry'range) <= R_retry; -- debugging report problems
  assign rx_done = rx_done_o;

endmodule
