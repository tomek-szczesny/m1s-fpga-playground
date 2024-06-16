//
// UART loopback
// by Tomek Szczesny 2024
//
// A receiver and a transmitter joined together by a buffer.
// Connected to RX/TX pins of M1S' ttyS0.
// Configured for 1MHz transmissions.
//
`include "../ice40_lib/clkdiv.v"
`include "../ice40_lib/fifo.v"
`include "../ice40_lib/uart_tx.v"
`include "../ice40_lib/uart_rx.v"

module top(
	input wire EXTOSC,
	input wire BUT63,

	input wire GPIO_8,
	output wire GPIO_10,
	
	output wire LED78,
	output wire LED79,
	output wire LED80,
	output wire LED81,
	output wire LED82,
	output wire LED83,
	output wire LED84
);

// Creating 5MHz clock (rx with 5x oversampling) and 1MHz clock (tx).

wire clk1, clk5;
clkdiv #(20) m_clk5 (EXTOSC, clk5);
clkdiv #(5)  m_clk1 (clk5,   clk1);

wire [3:0] fifo_status;
wire [7:0] fifo_in;
wire [7:0] fifo_out;
wire fifo_in_clk;
wire fifo_out_clk;

assign LED78 = fifo_status[0];
assign LED79 = fifo_status[1];
assign LED80 = fifo_status[2];
assign LED81 = fifo_status[3];
assign LED81 = GPIO_8;
assign LED82 = GPIO_10;


fifo    #(8, 2048) debug_fifo (
	.clk(fifo_in_clk),
	.clk_o(fifo_out_clk),
	.data(fifo_in),
	.data_o(fifo_out),
	.status(fifo_status)
);

uart_rx #(5) debug_rx (
	.clk(clk5), 
	.in(GPIO_8),
	.out(fifo_in),
	.clk_out(fifo_in_clk)
);

uart_tx debug_tx (
	.clk(clk1), 
	.data_rdy(fifo_status[0]),
	.data(fifo_out),
	.out(GPIO_10),
	.fetch(fifo_out_clk)
);

endmodule
