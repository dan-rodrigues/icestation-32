`undef debug
`undef stop

`ifndef SYNTHESIS
	`define debug(debug_command) debug_command
	`define stop(debug_command) debug_command; $stop;
`else
	`define debug(debug_command)
	`define stop(debug_command)
`endif
