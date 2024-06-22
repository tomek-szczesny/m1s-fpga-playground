//
// SPI + UART Demo
// by Tomek Szczesny 2024
//
// SPI Slave and UART RX/TX pair configured as a translator between the two.
//
// UART connected to RX/TX pins of M1S' ttyS0.
// UART configured for 1MHz transmissions.
//
`include "../ice40_lib/clkdiv.v"
`include "../ice40_lib/fifo.v"
`include "../ice40_lib/uart_tx.v"
`include "../ice40_lib/uart_rx.v"
`include "../ice40_lib/spi_slave.v"

module top(
	input wire EXTOSC,
	input wire BUT63,

	input wire GPIO_8,
	output wire GPIO_10,
	
	input wire GPIO_36,
	input wire GPIO_35,
	input wire GPIO_33,
	output wire GPIO_32,

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

wire [3:0] fifo_us_status;
wire [7:0] fifo_us_in;
wire [7:0] fifo_us_out;
wire fifo_us_in_clk;
wire fifo_us_out_clk;

wire [3:0] fifo_su_status;
wire [7:0] fifo_su_in;
wire [7:0] fifo_su_out;
wire fifo_su_in_clk;
wire fifo_su_out_clk;

assign LED78 = fifo_us_status[0];
assign LED79 = fifo_us_status[1];
assign LED80 = fifo_su_status[0];
assign LED81 = fifo_su_status[1];
assign LED82 = GPIO_8;
assign LED83 = GPIO_10;
assign LED84 = GPIO_33;

// Fifo from SPI to UART
fifo     #(8, 1024) su_fifo (
	.clk(fifo_su_in_clk),
	.clk_o(fifo_su_out_clk),
	.data(fifo_su_in),
	.data_o(fifo_su_out),
	.status(fifo_su_status)
);
// FIFO from UART to SPI
fifo     #(8, 1024) us_fifo (
	.clk(fifo_us_in_clk),
	.clk_o(~fifo_su_in_clk),
	.data(fifo_us_in),
	.data_o(fifo_us_out),
	.status(fifo_us_status)
);

uart_rx #(5) debug_rx (
	.clk(clk5), 
	.in(GPIO_8),
	.out(fifo_us_in),
	.clk_out(fifo_us_in_clk)
);

uart_tx debug_tx (
	.clk(clk1), 
	.data_rdy(fifo_su_status[0]),
	.data(fifo_su_out),
	.out(GPIO_10),
	.fetch(fifo_su_out_clk)
);

spi_slave spi_slave(
	.MOSI(GPIO_33),
	.SCLK(GPIO_35),
	.nCS(GPIO_36),
	.MISO(GPIO_32),
	.out(fifo_su_in),
	.clko(fifo_su_in_clk),
	.zo(~fifo_us_status[0]),
	.in(fifo_us_out)
);

endmodule
