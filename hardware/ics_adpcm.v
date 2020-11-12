// ics_adpcm.v
//
// Copyright (C) 2020 Dan Rodrigues <danrr.gh.oss@gmail.com>
//
// SPDX-License-Identifier: MIT

`default_nettype none

module ics_adpcm #(
    parameter integer OUTPUT_INTERVAL = 33700000 / 44100,
    parameter [15:0] ADPCM_BLOCK_SIZE = 1024 * 2, // in nibbles
    parameter [3:0] CHANNELS = 8,
    parameter ADPCM_STEP_LUT_PATH = "adpcm_step_lut.hex",

    // Derived parameters:
    // Verilog-2005 doesn't allow localparams to be used in port list although OSS tools allow it
    parameter CHANNEL_MSB = CHANNELS - 1
) (
    input clk,
    input reset,

    // Channel register writing

    input [7:0] ch_write_address,
    input [15:0] ch_write_data,
    input ch_write_en,
    input [1:0] ch_write_byte_mask,
    output reg ch_write_ready,

    // Global register writing

    input [0:0] gb_write_address,
    input [CHANNEL_MSB:0] gb_write_data,
    input gb_write_en,
    output reg gb_write_busy,
    output reg gb_write_ready,

    // Status register reading

    input [1:0] status_read_address,
    input status_read_request,
    output reg status_read_ready,
    output reg [CHANNEL_MSB:0] status_read_data,

    // Audio flags

    output reg [CHANNEL_MSB:0] gb_ended,
    output reg [CHANNEL_MSB:0] gb_playing,

    // PCM memory interface

    output [22:0] pcm_read_address,
    output reg pcm_address_valid,
    input pcm_data_ready,
    input [15:0] pcm_read_data,

    // Audio output

    output signed [15:0] output_l,
    output signed [15:0] output_r,
    output reg output_valid,

    // Debug

    output [15:0] dbg_adpcm_predictor,
    output [6:0] dbg_adpcm_step_index,
    output reg dbg_adpcm_valid
);
    localparam LOG2_DIVISOR = $clog2(OUTPUT_INTERVAL);
    localparam DIVIDER_BITS = LOG2_DIVISOR;

    localparam P_REG_READ_LATENCY = 1;
    localparam REG_READ_LATENCY = 2;

    localparam ADPCM_BLOCK_WIDTH = $clog2(ADPCM_BLOCK_SIZE) - 1;

    // --- Debug ---

    assign dbg_adpcm_predictor = adpcm_predictor;
    assign dbg_adpcm_step_index = adpcm_step_index;

    // --- Output clock divider ---

    reg [DIVIDER_BITS: 0] output_counter;
    wire output_ready = {{31 - DIVIDER_BITS{1'b0}}, output_counter} == OUTPUT_INTERVAL;

    always @(posedge clk) begin 
        if (reset || output_ready) begin
            output_counter <= 0;
        end else begin
            output_counter <= output_counter + 1;
        end
    end

    // --- Output ---

    // Accumulators:

    // If 2x hard multipliers were free, these accumulators could just stay in the MAC instances
    // This would mean these extra FFs aren't needed, but since only 1 multiplier is used, can't do that here

    reg [22:0] gb_level_l, gb_level_r;

    // Final truncation of the output happens here
    // When mixing all the channels, the lower 7 fraction bits are preserved to help with accuracy

    wire acc_start = state_changed_to(STATE_CH_VOLUME);

    assign output_l = gb_level_l[22:7];
    assign output_r = gb_level_r[22:7];

    reg acc_add_left;
    reg acc_add_right;

    always @(posedge clk) begin
        acc_add_left <= acc_start;
        acc_add_right <= 0;

        if (output_valid) begin
            gb_level_l <= 0;
            gb_level_r <= 0;
        end else if (acc_add_left) begin
            gb_level_l <= mac_result_clipped;
            acc_add_right <= 1;
        end else if (acc_add_right) begin
            gb_level_r <= mac_result_clipped;
        end
    end

    // Shared MAC:

    // It's expected that REG_VOLUME data is available by the time this is used

    always @(posedge clk) begin
        if (acc_start) begin
            mult_volume <= reg_read_data[7:0];
            mac_add <= gb_level_l;
        end else begin
            mult_volume <= reg_read_data[15:8];
            mac_add <= gb_level_r;
        end
        
        mult_sample <= adpcm_predictor;
    end

    reg signed [22:0] mac_add;
    reg signed [7:0] mult_volume;
    reg signed [15:0] mult_sample;
    reg signed [23:0] mac_result;

    reg signed [22:0] mac_result_clipped;

    always @* begin
        case (overflow(mac_result[23:22]))
            OVERFLOW_NEGATIVE: mac_result_clipped = 23'h400000;
            OVERFLOW_POSITIVE: mac_result_clipped = 23'h3fffff;
            default: mac_result_clipped = mac_result[22:0];
        endcase
    end

    always @* begin
        mac_result = mult_volume * mult_sample + mac_add;
    end

    // --- Registered inputs for writes ---

    reg [7:0] ch_write_address_r;
    reg [15:0] ch_write_data_r;
    reg ch_write_en_r, gb_write_en_r;

    reg [0:0] gb_write_address_r;

    wire regs_has_contention = reg_write_address == reg_read_address;

    always @(posedge clk) begin
        ch_write_address_r <= ch_write_address;
        ch_write_data_r <= ch_write_data;
        ch_write_en_r <= ch_write_en;

        gb_write_address_r <= gb_write_address[0];
        gb_write_en_r <= gb_write_en;
    end

    // --- Global registers ---

    // Writes:

    reg [CHANNEL_MSB:0] gb_start, gb_stop;

    always @(posedge clk) begin
        if (reset || output_ready) begin
            gb_start <= 0;
            gb_stop <= 0;

            gb_write_busy <= 0;
        end

        // These writes take precedence over the reset above

        if (gb_write_en_r) begin
            case (gb_write_address_r[0])
                0: gb_start <= gb_write_data[CHANNEL_MSB:0];
                1: gb_stop <= gb_write_data[CHANNEL_MSB:0];
            endcase

            gb_write_busy <= 1;
        end
    end

    // Reads:

    reg [1:0] status_read_address_r;

    reg status_read_request_r;
    wire status_read_request_rose = !status_read_request_r && status_read_request;
    reg status_read_ready_d;

    always @(posedge clk) begin
        status_read_address_r <= status_read_address;
        status_read_request_r <= status_read_request;
    end

    // Delay status_read_ready by 2 cycles

    always @(posedge clk) begin
        status_read_ready_d <= status_read_request_rose;
        status_read_ready <= status_read_ready_d;
    end

    // Status read addresses:
    // - 0:   gb_playing
    // - 1:   gb_ended
    // - 2/3: gb_write_busy on bit0, rest undefined

    always @(posedge clk) begin
        status_read_data <= status_read_address_r[0] ? gb_ended : gb_playing;

        // Only add extra mux on bit0
        if (status_read_address_r[1]) begin
            status_read_data[0] <= gb_write_busy;
        end
    end

    // Channel trigger shift register copy for FSM

    wire ch_complete = (state == STATE_CH_COMPLETE);

    reg [CHANNEL_MSB:0] gb_start_shift, gb_stop_shift;
    wire gb_start_current = gb_start_shift[0];
    wire gb_stop_shift_current = gb_stop_shift[0];

    always @(posedge clk) begin
        if (reset) begin
            gb_stop_shift <= {CHANNELS{1'b1}};
            gb_start_shift <= 0;
        end if (output_ready) begin
            gb_start_shift <= gb_start;
            gb_stop_shift <= gb_stop;
        end else if (ch_complete) begin
            gb_stop_shift <= gb_stop_shift >> 1;
            gb_start_shift <= gb_start_shift >> 1;
        end
    end

    // Channel start/end states

    wire ch_last = (ch == (CHANNELS - 1));

    reg [CHANNEL_MSB:0] gb_ended_shift, gb_started_shift, gb_playing_shift;
    reg gb_playing_current;

    always @(posedge clk) begin
        if (reset) begin
            gb_ended <= 0;
            gb_playing <= 0;
        end else if (output_ready) begin
            gb_ended <= (gb_ended | gb_ended_shift) & ~gb_started_shift;
            gb_ended_shift <= 0;
            gb_started_shift <= 0;

            gb_playing <= gb_playing_shift;
            gb_playing_shift <= 0;
        end else if (ch_complete && !ch_last) begin
            gb_ended_shift <= gb_ended_shift >> 1;
            gb_started_shift <= gb_started_shift >> 1;
            gb_playing_shift <= gb_playing_shift >> 1;
        end else begin
            gb_ended_shift[CHANNEL_MSB] <= gb_ended_shift[CHANNEL_MSB] | ch_ended;
            gb_started_shift[CHANNEL_MSB] <= gb_started_shift[CHANNEL_MSB] | gb_start_current;
            gb_playing_shift[CHANNEL_MSB] <= gb_playing_shift[CHANNEL_MSB] | gb_playing_current;
        end
    end

    // --- Public RAM ---

    // Register file:

    localparam [2:0]
        REG_START = 0,
        REG_FLAGS = 1,
        REG_END = 2,
        REG_LOOP = 3,
        REG_VOLUMES = 4,
        REG_PITCH = 5;

    reg [15:0] regs [0:255];

    reg regs_read_en;

    always @* begin
        case (state)
            STATE_CTRL_CHECK, STATE_CTRL_DONE, STATE_CH_VOLUME,
            STATE_ADPCM_WAIT_INIT_INDEX, STATE_ADPCM_WAIT_INIT_PREDICTOR, STATE_ADPCM_COMPUTE_DIFF,
            STATE_ADPCM_COMPLETE_STEP:
                regs_read_en = 1;
            default:
                regs_read_en = 0;
        endcase
    end

    // Read / Write:

    wire [7:0] reg_read_address = {1'b0, ch, regs_index};
    wire [7:0] reg_write_address = ch_write_address_r;
    reg [15:0] reg_read_ram_output;
    reg [15:0] reg_read_data;

    always @(posedge clk) begin
        if (ch_write_en_r && !(regs_read_en && regs_has_contention)) begin
            if (ch_write_byte_mask[0]) begin
                regs[reg_write_address][7:0] <= ch_write_data_r[7:0];
            end
            if (ch_write_byte_mask[1]) begin
                regs[reg_write_address][15:8] <= ch_write_data_r[15:8];
            end
        end

        // This extra stage is needed to help timing
        // Otherwise the below FSM ends up in the critical path
        reg_read_ram_output <= regs[reg_read_address];
        reg_read_data <= reg_read_ram_output;
    end

    // Delay the write acknowledge incase the write was prevented to avoid contention

    reg regs_write_pending;
    reg regs_write_en_d, gb_regs_write_en_d;

    wire regs_written = !(regs_read_en && regs_has_contention) && regs_write_pending;
    wire regs_write_en_rose = (!regs_write_en_d && ch_write_en_r);
    wire gb_regs_write_en_rose = (!gb_regs_write_en_d && gb_write_en_r);

    always @(posedge clk) begin
        regs_write_pending <= (regs_write_en_rose || regs_write_pending) && !regs_written;

        regs_write_en_d <= ch_write_en_r;
        gb_regs_write_en_d <= gb_write_en_r;
    end

    always @(posedge clk) begin
        if (reset) begin
            ch_write_ready <= 0;
        end else if (ch_write_en_r) begin
            // Active for a single cycle only
            ch_write_ready <= regs_written;
        end else begin
            ch_write_ready <= 0;
        end
    end

    always @(posedge clk) begin
        gb_write_ready <= gb_regs_write_en_rose;
    end

    // --- Private RAM ---

    // Register file:

    localparam [1:0]
        P_REG_PCM_INDEX_LO = 0,
        P_REG_PCM_INDEX_HI = 1,
        P_REG_ADPCM_PREDICTOR = 2,
        P_REG_PCM_INDEX_MID = 3;

    localparam
        CH_CTRL_P_PLAYING = 0;

    reg [15:0] p_regs [0:255];

    // Bottom 2 bits used for address
    // MSB used in FSM below
    reg [2:0] p_regs_index;

    reg p_reg_write_en;
    reg [1:0] p_regs_write_index;
    wire [7:0] p_regs_write_address = {2'b0, ch, p_regs_write_index[1:0]};

    wire [7:0] p_regs_address = {2'b0, ch, p_regs_index[1:0]};
    reg [15:0] p_reg_read_data, p_reg_write_data;

    // Both the ADPCM step index LUT and the private register file are stored in this RAM
    wire [7:0] p_reg_read_address = adpcm_needs_step_lut ? {1'b1, adpcm_step_index[6:0]} : p_regs_address;

    always @(posedge clk) begin
        if (p_reg_write_en) begin
            p_regs[p_regs_write_address] <= p_reg_write_data;
        end

        p_reg_read_data <= p_regs[p_reg_read_address];
    end

    // Writes:

    reg p_regs_writing;
    reg p_regs_write_complete;
    wire p_regs_start_writing = state_changed_to(STATE_CH_VOLUME);

    wire [1:0] p_regs_index_writing_offset = p_regs_write_index + 1;

    always @(posedge clk) begin
        p_regs_write_complete <= 0;
        p_reg_write_en <= p_regs_writing;

        case (p_regs_index_writing_offset)
            P_REG_PCM_INDEX_LO: p_reg_write_data <= pcm_target_index[15:0];
            P_REG_PCM_INDEX_HI: p_reg_write_data <= pcm_target_index[31:16];
            P_REG_ADPCM_PREDICTOR: p_reg_write_data <= adpcm_predictor;

            P_REG_PCM_INDEX_MID: begin
                p_reg_write_data[4:0] <= pcm_target_index[36:32];
                p_reg_write_data[5] <= ch_ctrl_p[CH_CTRL_P_PLAYING];
                p_reg_write_data[14:8] <= adpcm_step_index;

                p_regs_writing <= 0;
                p_regs_write_complete <= p_regs_writing;
            end
        endcase

        if (p_regs_start_writing) begin
            p_regs_writing <= 1;
            p_regs_write_index <= -1;
        end else begin
            p_regs_write_index <= p_regs_write_index + 1;
        end

        if (reset) begin
            p_regs_writing <= 0;
            p_reg_write_en <= 0;
        end
    end

    // ADPCM step LUT:

    reg adpcm_needs_step_lut;

    always @* begin
        case (state)
            STATE_ADPCM_COMPUTE_DIFF, STATE_READ_WAIT, STATE_ADPCM_PREPARE_COMPUTE_DIFF,
            STATE_ADPCM_COMPLETE_STEP, STATE_ADPCM_STORE_DIFF:
                adpcm_needs_step_lut = 1;
            default:
                adpcm_needs_step_lut = 0;
        endcase
    end

    // The 89 defined entries are loaded in the latter half of the RAM used for the private register file

    initial begin
        $readmemh(ADPCM_STEP_LUT_PATH, p_regs, 128, 128 + 88);
    end

    // The MSB is used to flag index as out-of-bounds
    // The lower 7 bits contains the replacement step index

    genvar i;
    generate
        for (i = 128 + 89; i < 255; i = i + 1) begin
            initial begin
                p_regs[i] = 16'h8000 + 88;
            end
        end
    endgenerate

    initial begin
        p_regs[255] = 16'h8000 + 0;
    end

    // --- Channel FSM ---

    localparam [3:0]
        STATE_LOAD_REGS = 0,
        STATE_REG_SETUP = 1,
        STATE_CTRL_CHECK = 2,
        STATE_ADPCM_PREPARE_COMPUTE_DIFF = 3,
        STATE_READ_WAIT = 4,
        STATE_CH_VOLUME = 5,
        STATE_CH_LOOP = 6,
        STATE_CH_COMPLETE = 7,
        STATE_ADPCM_STORE_DIFF = 8,
        STATE_OUTPUT_WAIT = 9,
        STATE_ADPCM_WAIT_INIT_PREDICTOR = 13,
        STATE_ADPCM_WAIT_INIT_INDEX = 14,
        STATE_CTRL_DONE = 15,
        STATE_ADPCM_COMPUTE_DIFF = 11,
        STATE_CH_ENDED = 12,
        STATE_ADPCM_COMPLETE_STEP = 10;

    reg [3:0] ch;
    reg [3:0] state;

    // One-hot friendly state change tracking
    // This shouldn't prevent yosys from extracting the FSM
    
    reg [15:0] state_previous_mask;

    integer state_index;
    always @(posedge clk) begin
        for (state_index = 0; state_index < 16; state_index = state_index + 1) begin
            state_previous_mask[state_index[3:0]] <= (state == state_index[3:0]);
        end
    end

    // ---

    reg [0:0] ch_ctrl_p;

    localparam
        CH_CTRL_LOOP = 0,
        CH_CTRL_ADPCM = 1;

    reg [2:0] regs_index;

    // --- Sample indexing ---

    // Index format:
    // - 25 bits integer sample index
    // - 12 bits fraction

    reg [36:0] pcm_target_index;
    reg pcm_target_index_16_preadd;

    // Target address is reached when stepping index catches up to the target
    reg pcm_target_address_reached;

    reg [24:0] pcm_stepping_index;
    assign pcm_read_address = pcm_stepping_index[24:2];

    wire block_starting = gb_start_current || adpcm_block_ended;

    reg [13:0] end_block, loop_block;
    reg end_block_reached;
    reg adpcm_block_ended;

    // Register anything involving big comparators to aid timing

    always @(posedge clk) begin
        pcm_target_address_reached <= pcm_stepping_index == pcm_target_index[36:12];
        end_block_reached <= (end_block == pcm_stepping_index[24:ADPCM_BLOCK_WIDTH + 1]);
        adpcm_block_ended <= pcm_stepping_index[ADPCM_BLOCK_WIDTH:0] == 0;
    end

    // --- PCM data registering ---

    reg [15:0] pcm_read_data_r;
    reg pcm_data_ready_r;

    // Max sample step is 16, which spans 4 words
    // 2bits + 1bit carry = 3bits required for a comparator to see if registered word is still valid

    reg [2:0] pcm_stepping_index_previous_word;
    wire pcm_registered_data_valid = pcm_stepping_index[4:2] == pcm_stepping_index_previous_word;

    always @(posedge clk) begin
        pcm_data_ready_r <= pcm_data_ready && pcm_address_valid;

        if (pcm_address_valid) begin
            pcm_read_data_r <= pcm_read_data;
        end
    end

    // --- ADPCM state ---

    reg [15:0] adpcm_predictor;
    reg [6:0] adpcm_step_index;

    // Select which 4bit ADPCM nybble is to be used

    reg [3:0] adpcm_nybble;
    wire adpcm_nybble_sign = adpcm_nybble[3];

    always @* begin
        case (pcm_stepping_index[1:0])
            0: adpcm_nybble = pcm_read_data_r[3:0];
            1: adpcm_nybble = pcm_read_data_r[7:4];
            2: adpcm_nybble = pcm_read_data_r[11:8];
            3: adpcm_nybble = pcm_read_data_r[15:12];
        endcase
    end

    // --- ADPCM predictor ---

    reg [15:0] adpcm_diff;

    // Predictor diff shift-and-add:

    // Shift-and-add to implement this:
    // adpcm_diff = (adpcm_nybble + 0.5) * step / 4

    wire adpcm_diff_preload = state == STATE_ADPCM_PREPARE_COMPUTE_DIFF;
    wire adpcm_diff_compute_complete = adpcm_nybble_shift == 0;

    always @(posedge clk) begin
        if (adpcm_diff_preload) begin
            adpcm_nybble_shift <= adpcm_nybble[2:0];
            adpcm_step_shift <= adpcm_step;
        end else begin
            adpcm_nybble_shift <= adpcm_nybble_shift << 1;
            adpcm_step_shift <= adpcm_step_shift >> 1;
        end
    end

    always @(posedge clk) begin
        if (adpcm_diff_preload) begin
            adpcm_diff <= {1'b0, adpcm_step} >> 3;
        end else if (adpcm_nybble_shift[2]) begin
            adpcm_diff <= adpcm_diff + adpcm_step_shift;
        end
    end

    reg [15:0] adpcm_predictor_nx;
    reg [16:0] adpcm_predictor_updated_no_clip;

    always @(posedge clk) begin
        if (adpcm_nybble_sign) begin
            adpcm_predictor_updated_no_clip <= $signed(adpcm_predictor) - $signed(adpcm_diff);
        end else begin
            adpcm_predictor_updated_no_clip <= $signed(adpcm_predictor) + $signed(adpcm_diff);
        end
    end

    // Predictor clipping:

    always @* begin
        case (overflow(adpcm_predictor_updated_no_clip[16:15]))
            OVERFLOW_NEGATIVE: adpcm_predictor_nx = 16'h8000;
            OVERFLOW_POSITIVE: adpcm_predictor_nx = 16'h7fff;
            default: adpcm_predictor_nx = adpcm_predictor_updated_no_clip[15:0];
        endcase
    end

    // Shift-and-add state for computing the diff

    reg [2:0] adpcm_nybble_shift;
    reg [14:0] adpcm_step_shift;
    wire [14:0] adpcm_step = p_reg_read_data[14:0];

    // --- ADPCM step index ---

    reg [6:0] adpcm_step_index_updated_no_clip;
    reg adpcm_step_index_needs_clipping;

    always @* begin
        adpcm_step_index_updated_no_clip = adpcm_step_delta + adpcm_step_index;

        if (p_reg_read_data[15]) begin
            adpcm_step_index_needs_clipping = 1;
        end else begin
            adpcm_step_index_needs_clipping = 0;
        end
    end

    // Step delta

    reg [6:0] adpcm_step_delta;

    always @(posedge clk) begin 
        adpcm_step_delta <= adpcm_nybble[2] ? (({5'b0, adpcm_nybble[1:0]} + 1) << 1) : -1;
    end

    // STATE_CTRL_CHECK:

    reg loop_check_needed;
    reg ch_ended;

    // STATE_CH_ENDED:

    reg ctrl_complete;

    // STATE_LOAD_REGS:

    wire [2:0] regs_index_loading_offset = (p_regs_index - P_REG_READ_LATENCY);
    wire regs_index_loading_complete = regs_index_loading_offset == {1'b0, P_REG_PCM_INDEX_MID};

    always @(posedge clk) begin
        output_valid <= 0;

        ctrl_complete <= 0;
        ch_ended <= 0;
        gb_playing_current <= 0;

        dbg_adpcm_valid <= 0;

        case (state)
            STATE_LOAD_REGS: begin
                p_regs_index <= p_regs_index + 1;

                case (regs_index_loading_offset[1:0])
                    P_REG_PCM_INDEX_LO: pcm_target_index[15:0] <= p_reg_read_data;
                    P_REG_PCM_INDEX_HI: pcm_target_index[31:16] <= p_reg_read_data;
                    P_REG_ADPCM_PREDICTOR: adpcm_predictor <= p_reg_read_data;

                    P_REG_PCM_INDEX_MID: begin
                        pcm_target_index[36:32] <= p_reg_read_data[4:0];
                        ch_ctrl_p <= p_reg_read_data[5];
                        adpcm_step_index <= p_reg_read_data[14:8];
                    end
                endcase

                if (regs_index_loading_complete) begin
                    regs_index <= 0;
                    state <= STATE_REG_SETUP;
                end
            end
            STATE_REG_SETUP: begin
                // Early exit if channel isn't playing
                if (!ch_ctrl_p[CH_CTRL_P_PLAYING] && !gb_start_current) begin
                    state <= STATE_CH_COMPLETE;
                end

                if (regs_index == (REG_READ_LATENCY - 1)) begin
                    state <= STATE_CTRL_CHECK;
                end

                regs_index <= regs_index + 1;

                gb_playing_current <= ch_ctrl_p[CH_CTRL_P_PLAYING];
            end
            STATE_CTRL_CHECK: begin
                case (output_reg_offset(regs_index))
                    REG_START: begin
                        if (gb_start_current) begin
                            pcm_target_index[11:0] <= 0;
                            pcm_target_index[ADPCM_BLOCK_WIDTH + 12:12] <= 0;
                            pcm_target_index[36:ADPCM_BLOCK_WIDTH + 12 + 1] <= reg_read_data[13:0];

                            ch_ctrl_p[CH_CTRL_P_PLAYING] <= 1;

                            // Early exit if channel just started, regs below aren't used in first pass
                            ctrl_complete <= 1;
                        end
                    end
                    REG_FLAGS: begin
                        loop_check_needed <= reg_read_data[CH_CTRL_LOOP];

                        // Stepping index, used for addressing, must be copied before any pitch adjustment
                        pcm_stepping_index <= pcm_target_index[36:12];
                    end 
                    REG_END: begin
                        end_block <= reg_read_data[13:0];
                    end
                    REG_LOOP: begin
                        loop_block <= reg_read_data[13:0];
                    end
                    REG_PITCH: begin
                        // Carry out must be split due to at 37bit carry chain failing timing
                        pcm_target_index[16:0] <= pcm_target_index[16:0] + {1'b0, reg_read_data};
                        pcm_target_index_16_preadd <= pcm_target_index[16];

                        // The below carry adjust will be handled regardless
                        ctrl_complete <= 1;
                    end
                    REG_PITCH + 1: begin
                        if (pcm_target_index_16_preadd && !pcm_target_index[16]) begin
                            pcm_target_index[36:17] <= pcm_target_index[36:17] + 1;
                        end
                    end
                endcase

                if (gb_stop_shift_current) begin
                    ch_ctrl_p[CH_CTRL_P_PLAYING] <= 0;
                    ch_ended <= 1;
                    ctrl_complete <= 1;
                end

                regs_index <= regs_index + 1;

                if (ctrl_complete) begin
                    regs_index <= REG_VOLUMES;
                    state <= STATE_CTRL_DONE;
                end
            end
            STATE_CTRL_DONE: begin
                if (ch_ctrl_p[CH_CTRL_P_PLAYING]) begin
                    pcm_address_valid <= 1;

                    if (block_starting) begin
                        state <= STATE_ADPCM_WAIT_INIT_PREDICTOR;
                    end else if (pcm_target_address_reached) begin
                        pcm_address_valid <= 0;
                        // No step? Skip straight to volume output
                        // !state_changed is required because an extra cycle is needed for the register read
                        if (!state_changed_to(STATE_CTRL_DONE)) begin
                            state <= STATE_CH_VOLUME;
                        end
                    end else begin
                        state <= STATE_READ_WAIT;
                    end
                end else begin
                    // Channel state is written back as part of this step
                    // This is needed to cover the case of ch_ctrl_p being updated to stop channel
                    state <= STATE_CH_VOLUME;
                end
            end
            STATE_ADPCM_WAIT_INIT_PREDICTOR: begin
                adpcm_predictor <= pcm_read_data_r;

                if (pcm_data_ready_r) begin
                    // Both stepping and target index are advanced when reading ADPCM headers
                    // Needed because header bytes are not factored into the pitch (playback rate)
                    pcm_stepping_index[2] <= 1;
                    pcm_target_index[36:14] <= pcm_target_index[36:14] + 1;

                    // Signal to PCM memory controller that another word is needed
                    pcm_address_valid <= 0;

                    state <= STATE_ADPCM_WAIT_INIT_INDEX;
                end
            end
            STATE_ADPCM_WAIT_INIT_INDEX: begin
                pcm_address_valid <= 1;

                adpcm_step_index <= pcm_read_data_r[6:0];
                
                if (pcm_data_ready_r && !state_changed_to(STATE_ADPCM_WAIT_INIT_INDEX)) begin
                    pcm_stepping_index[3:2] <= 2'b10;
                    pcm_target_index[36:14] <= pcm_target_index[36:14] + 1;

                    pcm_address_valid <= 0;

                    state <= pcm_target_address_reached ? STATE_CH_VOLUME : STATE_READ_WAIT;
                end
            end
            STATE_READ_WAIT: begin
                pcm_address_valid <= 1;

                if (pcm_data_ready_r && !state_changed_to(STATE_READ_WAIT)) begin
                    pcm_address_valid <= 0;
                    state <= STATE_ADPCM_PREPARE_COMPUTE_DIFF;
                end
            end
            STATE_ADPCM_PREPARE_COMPUTE_DIFF: begin
                // Preparaton to update step index:
                // It may be out of bounds here but will be corrected in a later state
                adpcm_step_index <= adpcm_step_index_updated_no_clip;

                state <= STATE_ADPCM_COMPUTE_DIFF;
            end
            STATE_ADPCM_COMPUTE_DIFF: begin
                if (adpcm_diff_compute_complete) begin
                    // Prepare stepping address for check next state (1 sample advanced)
                    pcm_stepping_index <= pcm_stepping_index + 1;
                    pcm_stepping_index_previous_word <= pcm_stepping_index[4:2];

                    state <= STATE_ADPCM_STORE_DIFF;
                end
            end
            STATE_ADPCM_STORE_DIFF: begin
                adpcm_predictor <= adpcm_predictor_nx;

                state <= STATE_ADPCM_COMPLETE_STEP;
            end
            STATE_ADPCM_COMPLETE_STEP: begin
                // Clip step index if it is out of bounds
                if (adpcm_step_index_needs_clipping) begin
                    adpcm_step_index <= p_reg_read_data[6:0];
                end

                dbg_adpcm_valid <= 1;

                // End-state checking and looping if needed:

                if (end_block_reached) begin
                    state <= loop_check_needed ? STATE_CH_LOOP : STATE_CH_ENDED;
                end else if (!pcm_target_address_reached) begin
                    if (block_starting) begin
                        pcm_address_valid <= 1;
                        state <= STATE_ADPCM_WAIT_INIT_PREDICTOR;
                    end else if (pcm_registered_data_valid) begin
                        state <= STATE_ADPCM_PREPARE_COMPUTE_DIFF;
                    end else begin
                        pcm_address_valid <= 1;
                        state <= STATE_READ_WAIT;
                    end
                end else begin
                    state <= STATE_CH_VOLUME;
                end
            end
            STATE_CH_LOOP: begin
                // PCM must catch up to stepping index, so reset in-block index to 0
                // Loop address must always point to start of ADPCM block
                pcm_stepping_index[ADPCM_BLOCK_WIDTH:0] <= 0;
                pcm_stepping_index[24:ADPCM_BLOCK_WIDTH + 1] <= loop_block;

                pcm_target_index[36:ADPCM_BLOCK_WIDTH + 12 + 1] <= loop_block;

                pcm_address_valid <= 1;
                state <= STATE_ADPCM_WAIT_INIT_PREDICTOR;
            end
            STATE_CH_ENDED: begin
                // Finished for case: sample end reached and loop not enabled
                // This case may also be hit even if the channel isn't even playing
                // ...but this has no unwanted side effects and avoids the logic cost of nesting this
                ch_ctrl_p[CH_CTRL_P_PLAYING] <= 0;

                // Only mark it as ended if the channel actually *was* playing
                ch_ended <= ch_ctrl_p[CH_CTRL_P_PLAYING];

                state <= STATE_CH_VOLUME;
            end
            STATE_CH_VOLUME: begin
                // Write back channel state in the meantime
                if (p_regs_write_complete) begin
                    state <= STATE_CH_COMPLETE;
                end
            end
            STATE_CH_COMPLETE: begin
                p_regs_index <= 0;
                ch <= ch + 1;

                state <= ch_last ? STATE_OUTPUT_WAIT : STATE_LOAD_REGS;
            end
            STATE_OUTPUT_WAIT: begin
                ch <= 0;

                // Wait until a sample interval has passed before marking outputs as valid
                if (output_ready) begin
                    state <= STATE_LOAD_REGS;
                    output_valid <= 1;
                end
            end
            default: begin
`ifndef SYNTHESIS
                $display("ADPCM DSP: Unhandled state");
                $stop;
`endif
            end
        endcase

        if (reset) begin
            state <= STATE_LOAD_REGS;
            p_regs_index <= 0;
            regs_index <= 0;
            ch <= 0;
            output_valid <= 0;
            pcm_address_valid <= 0;

            dbg_adpcm_valid <= 0;
        end
    end

    // --- Convenience functions ---

    localparam [1:0]
        OVERFLOW_NONE = 2'b00,
        OVERFLOW_POSITIVE = 2'b10,
        OVERFLOW_NEGATIVE = 2'b11;

    function [1:0] overflow;
        input [1:0] carry_sign;

        case (carry_sign)
            2'b01: overflow = OVERFLOW_POSITIVE;
            2'b10: overflow = OVERFLOW_NEGATIVE;
            default: overflow = OVERFLOW_NONE;
        endcase
    endfunction

    function [2:0] output_reg_offset;
        input [2:0] index;

        output_reg_offset = ((index - REG_READ_LATENCY) & 3'b111);
    endfunction

    function [0:0] state_changed_to;
        input [3:0] new_state;

        state_changed_to = !state_previous_mask[new_state] && (state == new_state);
    endfunction

`ifdef FORMAL

    integer valid_counter = 0;
    wire past_valid = valid_counter != 0;

    initial begin
        assume(reset);
    end

    genvar i;
    for (i = 0; i < 256; i = i + 1) begin
        initial begin
            regs[i] = 0;
        end
    end

    always @(posedge clk) begin
        if (past_valid) begin
            assume(!reset);

            // PCM data doesn't influence the assertions here so remove it from the search space
            assume(pcm_data_ready);
            assume(pcm_read_data == 0);
        end

        valid_counter <= valid_counter + 1;
    end

    always @(posedge clk) begin
        if (past_valid) begin
            assert(output_counter <= OUTPUT_INTERVAL);
        end
    end

    always @(posedge clk) begin
        if (valid_counter > 2) begin
            // If a global reg is written in same cycle as its normally cleared..
            if ($past(output_ready) && $past(gb_write_en_r)) begin
                // ..the written data should persist
                case ($past(ch_write_address[1:0]))
                    0: assert(gb_start == $past(gb_write_data[CHANNEL_MSB:0]));
                    1: assert(gb_stop == $past(gb_write_data[CHANNEL_MSB:0]));
                endcase

                // ..busy flag should be set rather than being cleared in the same cycle
                assert(gb_write_busy);
            end

            // If a global reg is written..
            if ($past(gb_write_en_r)) begin
                // ..busy flag should be set
                assert(gb_write_busy);
            end

            // If there was contention..
            if ($past(regs_has_contention) && $past(ch_write_en_r) && $past(regs_read_en)) begin
                // ..then the write should be deferred

                assert($past(regs[ch_write_address_r]) == regs[$past(ch_write_address_r)]);

                // ..then the ready flag should not be set as the write is being deferred
                assert(!ch_write_ready);
            end

            // If there isn't contention during a write..
            if ($past(!regs_has_contention) && $past(ch_write_en_r) && $past(regs_write_pending)) begin
                // ..then the write shouldn't be deferred
                assert(ch_write_ready);
            end

            // If there was a write, the byte mask should be respected
            if ($past(ch_write_en_r) && $past(!regs_has_contention)) begin
                case ($past(ch_write_byte_mask))
                    2'b00: begin
                        assert($past(regs[ch_write_address_r]) == regs[$past(ch_write_address_r)]);
                    end
                    2'b01: begin
                        assert(($past(regs[ch_write_address_r]) & 16'hff00) == (regs[$past(ch_write_address_r)] & 16'hff00));
                        assert(($past(ch_write_data_r) & 16'h00ff) == (regs[$past(ch_write_address_r)] & 16'h00ff));
                    end
                    2'b10: begin
                        assert(($past(regs[ch_write_address_r]) & 16'h00ff) == (regs[$past(ch_write_address_r)] & 16'h00ff));
                        assert(($past(ch_write_data_r) & 16'hff00) == (regs[$past(ch_write_address_r)] & 16'hff00));
                    end
                    2'b11: begin
                        assert($past(ch_write_data_r) == regs[$past(ch_write_address_r)]);
                    end
                endcase
            end 

            // If there was neither a channel write..
            if ($past(!ch_write_en_r)) begin
                // ..the ready flag should be clear
                assert(!ch_write_ready);
            end

            // If a status read was just requested..
            if ($past(status_read_request) && $past(!status_read_request, 2) && $past(!status_read_request, 3)) begin
                // ..the ready flag should be 0 as it needs to be delayed 2 cycles
                assert(!status_read_ready);
            end

            // If a status read was previously requested..
            if ($past(status_read_request, 2) && $past(!status_read_request, 3) && $past(!status_read_request, 4)) begin
                // ..the ready flag should now be set
                assert(status_read_ready);
            end

            // If...
        end
    end

`endif

endmodule
