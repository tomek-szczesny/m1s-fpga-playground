//
// VGA output demo
// with DDR output
// by Tomek Szczesny 2023
//
// Capable of displaying four different test patterns,
// to be selected with BUT63. 
// Configured 1080p@60Hz using VESA timings.
//
// Uses both PLLs in order to generate precise frequency.
// 100MHz -> 55MHz -> 74.25MHz
//
`include "../ice40_lib/fifo.v"
`include "../ice40_lib/vga_tx.v"
`include "../ice40_lib/video_test.v"
`include "../ice40_lib/ddr_io.v"
`include "../ice40_lib/debounce.v"
`include "../ice40_lib/rgb_to_gray.v"
`include "../ice40_lib/dither.v"

module top(
	input wire EXTOSC,
	input wire BUT63,
	input wire BUT64,
	
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

// Generating VGA clock in two stages.
// One stage is not sufficient to generate clock with required 0.5% precision.
// The PLL modules are defined at the end of this file because they're
// generated exclusively for this purpose.
wire clkpll, clkvga;
pll pll55M (
	.clock_in(EXTOSC),
	.clock_out(clkpll),
	.locked(LED78)
);
pll2 pll74M25 (
	.clock_in(clkpll),
	.clock_out(clkvga),
	.locked(LED79)
);


// Use BUT63 to cycle through 4 possible test patterns
// Show selected pattern on LEDs.
debounce #(2**20) b63_db (
	.clk(clkpll),
	.in(BUT63),
	.out(BUT63_db)
);
wire BUT63_db;
reg [1:0] test_p = 0;
always@(negedge BUT63_db) test_p <= test_p + 1;
assign {LED80, LED81} = test_p;

// Video test pattern generator
wire [4:0] re, ro;
wire [5:0] ge, go;
wire [4:0] be, bo;
video_test_ddr #(
	.v(1080),
	.h(1920),
	.r(5),
	.g(6),
	.b(5))
	vt (
	.clk(clkvga),
	.cke(~fifo_status[3]),
	.pattern(test_p),
	.rst(0),
	.rde(re),
	.gde(ge),
	.bde(be),
	.rdo(ro),
	.gdo(go),
	.bdo(bo),
	.clk_o(fifo_in_clk)
);

// Hacky x-y coordinate counters for dither
reg [10:0] x_ctr = 0;
reg [10:0] y_ctr = 0;

always @ (posedge fifo_in_clk)
begin
	x_ctr <= (x_ctr==1918 ? 0 : x_ctr + 2);
	y_ctr <= (x_ctr==1918 ? (y_ctr==1079 ? 0 : y_ctr + 1) : y_ctr);
end


// BUT64 functionality - convert to mono on the fly
wire [7:0] bwo, bwe;
rgb_g_ntsc#(
	.n(6),
	.m(8),
	.fidelity(3))
	r2go (
	.r({ro, 1'b0}),
	.g(go),
	.b({bo, 1'b0}),
	.y(bwo)
);
rgb_g_ntsc#(
	.n(6),
	.m(8),
	.fidelity(3))
	r2ge (
	.r({re, 1'b0}),
	.g(ge),
	.b({be, 1'b0}),
	.y(bwe)
);

wire mno, mne;

blue_mono #(64)
	dithero (
	.in(bwo),
	.x(x_ctr[5:0]+1),
	.y(y_ctr[5:0]),
	.clk(fifo_in_clk),
	.out(mno)
);
blue_mono #(64)
	dithere (
	.in(bwe),
	.x(x_ctr[5:0]),
	.y(y_ctr[5:0]),
	.clk(fifo_in_clk),
	.out(mne)
);

always @ (BUT64, ro,go,bo,re,ge,be,mno,mne) begin
	if (BUT64) fifo_in = {ro, go, bo, re, ge, be};
	else fifo_in = {{16{mno}}, {16{mne}}} ;
end

// Short visual data FIFO, between visual data generator and transmitter.
// we hope to generate visual data at least as fast as it's sent, so for now
// we don't need a full frame buffer.
// Technically it is not strictly necessary..
// FIFO size is 32 bits wide and 256 bits long.
wire [31:0] fifo_in;
wire [3:0] fifo_status;
wire fifo_in_clk;
fifo #(	.n(32),
	.m(256))
	vga_fifo (
	.clk(fifo_in_clk),
	.data(fifo_in),
	.clk_o(fifo_out_clk),
	.data_o(fifo_out),
	.status(fifo_status)
);
assign LED82 = fifo_status[3];

wire [31:0] fifo_out;
wire fifo_out_clk;

// VGA_TX driver, that dumps correct pattern through GPIO pins
// This module assumes that data is always ready in FIFO.
// The parameters are VGA horizontal and vertical timings, 
// measured in pixel clock cycles.
// Taken from VESA Display Monitor Timing Standard V1.0 rev. 12
vga_tx_ddr #(
	.hva(1920),
	.hfp(22),
	.hsp(33),
	.hbp(37),
	.vva(1080),
	.vfp(4),
	.vsp(5),
	.vbp(36),
	.hpp(1),	// Pulse Polarity
	.vpp(1),
	.rd(5),
	.gd(6),
	.bd(5))
	the_vga_tx (
	.clk(clkvga),
	.data(fifo_out),
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
 * Requested output frequency:   55.000 MHz
 * Achieved output frequency:    55.000 MHz
 */

module pll(
	input  clock_in,
	output clock_out,
	output locked
	);

SB_PLL40_PAD #(
		.FEEDBACK_PATH("SIMPLE"),
		.DIVR(4'b0100),		// DIVR =  4
		.DIVF(7'b0101011),	// DIVF = 43
		.DIVQ(3'b100),		// DIVQ =  4
		.FILTER_RANGE(3'b010)	// FILTER_RANGE = 2
	) uut (
		.LOCK(locked),
		.RESETB(1'b1),
		.BYPASS(1'b0),
		.PACKAGEPIN(clock_in),
		.PLLOUTCORE(clock_out)
		);

endmodule


/**
 * PLL configuration
 *
 * This Verilog module was generated automatically
 * using the icepll tool from the IceStorm project.
 * Use at your own risk.
 *
 * Given input frequency:        55.000 MHz
 * Requested output frequency:   74.250 MHz
 * Achieved output frequency:    74.250 MHz
 */

module pll2(
	input  clock_in,
	output clock_out,
	output locked
	);

SB_PLL40_CORE #(
		.FEEDBACK_PATH("SIMPLE"),
		.DIVR(4'b0100),		// DIVR =  4
		.DIVF(7'b0110101),	// DIVF = 53
		.DIVQ(3'b011),		// DIVQ =  3
		.FILTER_RANGE(3'b001)	// FILTER_RANGE = 1
	) uut (
		.LOCK(locked),
		.RESETB(1'b1),
		.BYPASS(1'b0),
		.REFERENCECLK(clock_in),
		.PLLOUTGLOBAL(clock_out)
		);

endmodule
