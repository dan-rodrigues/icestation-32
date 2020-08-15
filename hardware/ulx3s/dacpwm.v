// This module is originally from this repo:
// https://github.com/emard/ulx3s-misc/tree/master/examples/audio/hdl

// combines resistor DAC and PWM
// upper bits using DAC, lower bit using PWM

module dacpwm
#(
  parameter C_pcm_bits = 12, // input: how many bits PCM (including sign bit)
  parameter C_dac_bits = 4  // output: how many bits DAC output, unsigned
)
(
  input clk, // required to run PWM
  input signed [C_pcm_bits-1:0] pcm, // 12-bit signed PCM input
  output [C_dac_bits-1:0] dac // 4-bit unsigned DAC output
);
    parameter C_pwm_bits = C_pcm_bits-C_dac_bits; // how many bits for PWM that increases DAC resolution

    // generate 2 DAC output optional values: PCM+0 and PCM+1
    reg [C_dac_bits-1:0] R_dac0, R_dac1;
    reg [C_pwm_bits-1:0] R_pcm_low;
    always @(posedge clk)
    begin
      R_dac0 <= { ~pcm[C_pcm_bits-1], pcm[C_pcm_bits-2:C_pcm_bits-C_dac_bits]};
      R_dac1 <= { ~pcm[C_pcm_bits-1], pcm[C_pcm_bits-2:C_pcm_bits-C_dac_bits]} + 1;
      R_pcm_low <= pcm[C_pwm_bits-1:0];
    end
    
    // constantly running PWM counter
    reg [C_pwm_bits-1:0] R_pwm_counter;
    always @(posedge clk)
      R_pwm_counter <= R_pwm_counter + 1; // constantly running

    // the comparator
    // using PWM to switch between dac0 and dac1
    reg [C_dac_bits-1:0] R_dac_output;
    always @(posedge clk)
    begin
      R_dac_output <= R_pwm_counter >= R_pcm_low ? R_dac0 : R_dac1;
    end

    assign dac = R_dac_output;
endmodule

