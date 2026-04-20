	///////////////////////////////////////////////////////////////////////
	//	Module		: uart_tx
	//	Description	: A parameterized UART transmitter supporting configurable baud rate and data width
	//	             Implements standard UART protocol with start bit, data bits, and stop bit
	//	Developer	: Based on SPI 4-wire design pattern by qianwen.Not yet verified on the board !!!
	//	Date		: 2026
	//	Version		: 1.0
	///////////////////////////////////////////////////////////////////////

	module uart_tx#(	
		parameter CLK_FREQ		= 32'd50_000_000	,	// System clock frequency in Hz (default: 50MHz)
		parameter BAUD_RATE		= 32'd115200			// UART baud rate (default: 115200)
	)(
		input							rst_n		,	// System reset, active low
		input							clk			,	// System clock
		input 							en			,	// Transmit enable signal
		input 		[8-1:0]				data		,	// Data to transmit (fixed 8-bit width)
		output reg						busy		,	// Transmission busy flag
		output reg						done		,	// Transmission completion flag
		output 							TxD		=1'b1	// UART transmit data line
	);

	// Calculate required clock cycles per bit based on system clock and baud rate
	localparam CLK_PER_BIT = CLK_FREQ / BAUD_RATE;

	// Internal registers
	reg [10-1:0] data_reg;	// Data register for transmitting data (10-bit width: start + 8 data + stop)
	reg [ 4-1:0] bit_cnt;	// Counter for tracking transmitted bits (4-bit width, enough for 10 bits)
	reg [16-1:0] clk_cnt;	// Counter for timing each bit (fixed 16-bit width)

	// Update data register when transmission starts
	always@(posedge clk) begin
		if(en == 1'b1 && busy == 1'b0) begin
			data_reg <= {1'b1, data, 1'b1};
		end
		else if( busy == 1'b0 )begin
			data_reg <= {1'b1, 8'hFF, 1'b1};
		end
		else if(busy == 1'b1 && clk_cnt == CLK_PER_BIT - 1'b1) begin
			// Shift right to send next bit (MSB goes out first after start bit)
			data_reg <= {1'b1, data_reg[9:1]};
		end
		else begin
			// Hold current value
		end
	end

	// Bit counter to track which bit we're currently transmitting
	always@(posedge clk) begin
		if(busy == 1'b1 && clk_cnt == CLK_PER_BIT - 1'b1) begin
			if(bit_cnt == 4'd9) begin
				bit_cnt <= 4'd0;  // Reset after completing transmission (10 bits total)
			end
			else begin
				bit_cnt <= bit_cnt + 1'b1;
			end
		end
		else if(busy == 1'b0) begin
			// Start counting from the beginning when starting new transmission
			bit_cnt <= 4'd0;
		end
		else begin
			// Hold current value
		end
	end

	// Clock counter for timing each bit
	always@(posedge clk) begin
		if(busy == 1'b1) begin
			if(clk_cnt == CLK_PER_BIT - 1'b1) begin
				clk_cnt <= 16'd0;  // Reset after completing one bit period
			end
			else begin
				clk_cnt <= clk_cnt + 1'b1;
			end
		end
		else begin
			clk_cnt <= 16'd0;  // Reset when not busy
		end
	end

	// Control busy signal
	always@(posedge clk) begin
		if(rst_n == 1'b0) begin
			busy <= 1'b0;
		end
		else if(en == 1'b1 && busy == 1'b0) begin
			busy <= 1'b1;  // Set busy when transmission starts
		end
		else if(busy == 1'b1 && bit_cnt == 4'd9 && clk_cnt == CLK_PER_BIT - 1'b1) begin
			busy <= 1'b0;  // Clear busy when transmission completes (after 10 bits)
		end
		else begin
			// Hold current value
		end
	end

	// Control done signal
	always@(posedge clk) begin
		if(busy == 1'b1 && bit_cnt == 4'd9 && clk_cnt == CLK_PER_BIT - 1'b1) begin
			done <= 1'b1;  // Set done when transmission completes (after 10 bits)
		end
		else begin
			done <= 1'b0;  // Clear done at other times
		end
	end

	// Output TxD signal 
	
	assign TxD = data_reg[9];
	

	endmodule
