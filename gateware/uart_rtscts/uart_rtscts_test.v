//
// UART with RTS/CTS capability
//
// by Tomek Szczesny 2024
//
// Two complete UART transceivers.
//
// #1 is connected to FT2232HL
// Working at 1Mbps, available as ttyUSB0
//
// #2 is connected to the standard pins 8 and 10.
// At 500kbps, available as /dev/ttyS0
// Since RTS/CTS signals are not routed to FPGA,
// CTS is emulated on BUT64.
//
// RTS/CTS can be verified in two ways:
// - By sending data from #1 to #2 and letting it through manully
// - By sending data from #1 to #2 and letting the FIFO become full 
//
`include "../ice40_lib/clkdiv.v"
`include "../ice40_lib/fifo.v"
`include "../ice40_lib/uart_rtscts.v"
`include "../ice40_lib/debounce.v"

module top(
	input wire EXTOSC,
	
	input wire BUT64,

	input wire GPIO_8,
	output wire GPIO_10,

	input wire D0,	// RX
	output wire D1, // TX
	input wire D2,  // CTS
	output wire D3, // RTS

	output wire LED78,
	output wire LED79,
	output wire LED80,
	output wire LED81,
	output wire LED82,
	output wire LED83,
	output wire LED84
);

// Creating 5MHz and 2.5MHz clocks
// (Both interfaces 5x oversalmpled)

wire clk2p5, clk5;
clkdiv #(20) m_clk5 (EXTOSC, clk5);
clkdiv #(40)  m_clk2p5 (EXTOSC,   clk2p5);

wire [3:0] fifo12_status;
wire [7:0] fifo12_in;
wire [7:0] fifo12_out;
wire fifo12_in_clk;
wire fifo12_out_clk;

wire [3:0] fifo21_status;
wire [7:0] fifo21_in;
wire [7:0] fifo21_out;
wire fifo21_in_clk;
wire fifo21_out_clk;

assign LED78 = fifo21_status[0];
assign LED79 = fifo21_status[3];
assign LED80 = fifo12_status[0];
assign LED81 = fifo12_status[3];
assign LED82 = GPIO_8;
assign LED83 = GPIO_10;

wire b64;
debounce #(8192) db64 (
	.in(BUT64),
	.clk(clk2p5),
	.out(b64)
);

fifo    #(8, 512) fifo12 (
	.clk(fifo12_in_clk),
	.clk_o(fifo12_out_clk),
	.data(fifo12_in),
	.data_o(fifo12_out),
	.status(fifo12_status)
);

fifo    #(8, 512) fifo21 (
	.clk(fifo21_in_clk),
	.clk_o(fifo21_out_clk),
	.data(fifo21_in),
	.data_o(fifo21_out),
	.status(fifo21_status)
);

uart_rtscts #(5) uart_1 (
	.clk(clk5),
	.rx(D0),
	.tx(D1),
	.rts(D3),
	.cts(D2),
	.tx_data(fifo21_out),
	.rx_data(fifo12_in),
	.rtscts_en(1'b1),
	.tx_rdy(fifo21_status[0]),
	.rx_rdy(~fifo12_status[3]),
	.tx_pop(fifo21_out_clk),
	.rx_push(fifo12_in_clk)
);

uart_rtscts #(5) uart_2 (
	.clk(clk2p5),
	.rx(GPIO_8),
	.tx(GPIO_10),
	.rts(LED84),
	.cts(b64),
	.tx_data(fifo12_out),
	.rx_data(fifo21_in),
	.rtscts_en(1'b1),
	.tx_rdy(fifo12_status[0]),
	.rx_rdy(~fifo21_status[3]),
	.tx_pop(fifo12_out_clk),
	.rx_push(fifo21_in_clk)
);

endmodule
