//
// VGA output demo
// by Tomek Szczesny 2023
//
// Capable of displaying four different test patterns,
// to be selected with BUT63. 
// Configured for 1024x768 60Hz using VESA timings.
//
`include "../ice40_lib/fifo.v"
`include "../ice40_lib/vga_tx.v"
`include "../ice40_lib/video_test.v"
`include "../ice40_lib/ddr_io.v"

module top(
	input wire EXTOSC,
	input wire BUT63,
	
	output wire LED78,
	output wire LED79,
	output wire LED80,
	output wire LED81,
	output wire LED82,
	output wire LED83,
	output wire LED84,
	output wire R7,
	output wire R6,
	output wire R5,
	output wire R4,
	output wire R3,
	output wire G7,
	output wire G6,
	output wire G5,
	output wire G4,
	output wire G3,
	output wire G2,
	output wire B7,
	output wire B6,
	output wire B5,
	output wire B4,
	output wire B3,
	output wire HS,
	output wire VS
);

// Generating VGA clock at 65MHz
// The PLL module is defined at the end of this file because it's
// generated exclusively for this purpose.
wire clkvga;
pll pll25M175 (
	.clock_in(EXTOSC),
	.clock_out(clkvga),
	.locked(LED78)
);


// Use BUT63 to cycle through 4 possible test patterns
// Show selected pattern on LEDs 79, 80.
reg [1:0] test_p = 0;
always@(negedge BUT63) test_p <= test_p + 1;
assign {LED79, LED80} = test_p;

// Video test pattern generator
wire [4:0] r;
wire [5:0] g;
wire [4:0] b;
video_test #(
	.v(768),
	.h(512),
	.r(5),
	.g(6),
	.b(5))
	vt (
	.clk(clkvga),
	.cke(~fifo_status[3]),
	.pattern(test_p),
	.rst(0),
	.rd(r),
	.gd(g),
	.bd(b),
	.clk_o(fifo_in_clk)
);

// Short visual data FIFO, between visual data generator and transmitter.
// we hope to generate visual data at least as fast as it's sent, so for now
// we don't need a full frame buffer.
// Technically it is not strictly necessary..
// FIFO size is 16 bits wide and 1024 bits long.
// FIFO status will be displayed on 4 LEDs as well.
wire [15:0] fifo_in;
assign fifo_in = {r, g, b};
wire [3:0] fifo_status;
wire fifo_in_clk;
fifo #(	.n(16),
	.m(256))
	vga_fifo (
	.clk(fifo_in_clk),
	.data(fifo_in),
	.clk_o(fifo_out_clk),
	.data_o(fifo_out),
	.status(fifo_status)
);
assign {LED81, LED82} = {fifo_status[3], fifo_status[0]};

wire [15:0] fifo_out;
wire fifo_out_clk;

// VGA_TX driver, that dumps correct pattern through GPIO pins
// This module assumes that data is always ready in FIFO.
// The parameters are VGA horizontal and vertical timings, 
// measured in pixel clock cycles.
// Taken from: http://tinyvga.com/vga-timing
vga_tx_ddr #(
	.hva(1024),
	.hfp(24),
	.hsp(136),
	.hbp(160),
	.vva(768),
	.vfp(3),
	.vsp(6),
	.vbp(29),
	.hpp(0),	// Pulse Polarity
	.vpp(0),
	.rd(5),
	.gd(6),
	.bd(5))
	the_vga_tx (
	.clk(clkvga),
	.data({fifo_out,fifo_out}),
	.fetch(fifo_out_clk),
	.R({vga_data[35:31], vga_data[17:13]}),
	.G({vga_data[30:25], vga_data[12:7]}),
	.B({vga_data[24:20], vga_data[6:2]}),
	.HSync({vga_data[19], vga_data[1]}),
	.VSync({vga_data[18], vga_data[0]})
);
assign {LED83, LED84} = {fifo_out_clk, vga_data[1]};

wire [36-1:0] vga_data;

ddr_out #(18) vga_ddr_out(
	.clk(clkvga),
	.data_p(vga_data[18-1:0]),
	.data_n(vga_data[36-1:18]),
	.data_o({R7, R6, R5, R4, R3, G7, G6, G5, G4, G3, G2, B7, B6, B5, B4, B3, HS, VS})
);

endmodule

/**
 * PLL configuration
 *
 * This Verilog module was generated automatically
 * using the icepll tool from the IceStorm project.
 * Use at your own risk.
 *
 * Given input frequency:       100.000 MHz
 * Requested output frequency:   73.125 MHz
 * Achieved output frequency:    73.214 MHz
 */

module pll(
	input  clock_in,
	output clock_out,
	output locked
	);

SB_PLL40_PAD #(
		.FEEDBACK_PATH("SIMPLE"),
		.DIVR(4'b0100),		// DIVR =  6
		.DIVF(7'b0110011),	// DIVF = 40
		.DIVQ(3'b101),		// DIVQ =  3
		.FILTER_RANGE(3'b010)	// FILTER_RANGE = 1
	) uut (
		.LOCK(locked),
		.RESETB(1'b1),
		.BYPASS(1'b0),
		.PACKAGEPIN(clock_in),
		.PLLOUTGLOBAL(clock_out)
		);

endmodule

