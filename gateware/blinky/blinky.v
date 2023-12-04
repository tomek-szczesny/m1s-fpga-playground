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
// from the library. 7142857 is a divisor we're after.
// If meeting clock speed constraints is troublesome, consider chaining two
// dividers, with the smaller one being first. Bigger logical networks support
// lower clock frequencies.
// Divisors can be obtained through prime factorization.

wire clk1, clk14;
clkdiv #(23)     m_clk1 (EXTOSC, clk1);
clkdiv #(310559) m_clk2 (clk1,   clk14);

// Create a Johnson counter with bit width of 7, and wire its output
// diectly to LEDs. Use 14Hz clock as input, and use "63" button as reset.
// Keep in mind released button has value "1", so it has to be inverted.
johnson #(7) m_cntr (
	.clk(clk14),
	.clr(~BUT63),
	.out({LED78, LED79, LED80, LED81, LED82, LED83, LED84})
);

endmodule
