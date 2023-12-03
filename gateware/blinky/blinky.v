//
// Blinking LEDs demo
// by Tomek Szczesny 2023
//
// A Johnson counter on 7 LEDs
//
`include "../ice40_lib/clkdiv.v"
`include "../ice40_lib/johnson.v"

module top(
	input wire EXTOSC,
	input wire BUT63,
	
	output wire LED78,
	output wire LED79,
	output wire LED80,
	output wire LED81,
	output wire LED82,
	output wire LED83,
	output wire LED84
);

// Dividing 100MHz oscillator clock into ~14Hz, using a clock divider 
// from the library. Its numerical parameter is a divisor.
wire clk14;
clkdiv #(7142857) m_clk4 (EXTOSC, clk14);

// Create a Johnson counter with bit width of 7, and wire its output
// diectly to LEDs. Use 14Hz clock as input, and use "63" button as reset.
// Keep in mind released button has value "1", so it has to be inverted.
johnson #(7) m_cntr (
	.clk(clk14),
	.clr(~BUT63),
	.out({LED78, LED79, LED80, LED81, LED82, LED83, LED84})
);

endmodule
