	///////////////////////////////////////////////////////////////////////
	//	Module		: spi_4_wire
	//	Description	: A parameterized SPI 4-wire interface controller supporting both read and write operations
	//	             Compatible with standard SPI protocol with configurable address and data widths
	//	Developer	: liang.zheng
	//	Date		: 2026.04
	//	Version		: 1.0
	///////////////////////////////////////////////////////////////////////


	module spi_4_wire#(	
		parameter ADDR_WIDTH		= 8'd16			,	// Address width
		parameter DATA_WIDTH		= 8'd16				// Data width	
	)(
		input							rst_n		,
		input							clk			,
		input		[8-1:0]				CLK_DIV		,
		input 							wr_en		,
		input 							rd_en		,
		input 		[ADDR_WIDTH-1:0]	addr		,
		input 		[DATA_WIDTH-1:0]	dwr			,
		output reg	[DATA_WIDTH-1:0]	drd		=0	,
		output reg						done		,
		output reg						busy		,
		// SPI interface
		output 							CS_N		,
		output 							SCLK		,
		output 							SDO			,
		input  							SDI	
    );
	
	reg wr_flag;
	reg rd_flag;
	
	
	reg[8-1:0]cnt			;		
	reg[8-1:0]cnt_bit		;		
	reg[8-1:0]CNT_N = 8'd2	;
	
	always@( posedge clk )begin
		if( wr_en == 1'b1 )begin 
			CNT_N <= CLK_DIV;
		end
		else if( rd_en == 1'b1 )begin
			CNT_N <= CLK_DIV;
		end
		else ;
	end
	
	localparam CNT_BIT_N = ADDR_WIDTH + DATA_WIDTH + 8'd2;	

	always@( posedge clk )begin
		if( rst_n == 1'b0 )	begin 
			busy <= 1'b0;
		end
		else if( cnt_bit == CNT_BIT_N - 1'b1 && cnt == CNT_N - 1'b1 )begin
			busy <= 1'b0;
		end
		else if( busy == 1'b0 && ( wr_en == 1'b1 || rd_en == 1'b1) )begin
			busy <= 1'b1;
		end
		else;
	end
	
	always@( posedge clk )begin
		if( rst_n == 1'b0 )begin
			wr_flag <= 1'b0;
		end
		else if( cnt_bit == CNT_BIT_N - 1'b1 && cnt == CNT_N - 1'b1 && wr_flag == 1'b1 )begin
			wr_flag <= 1'b0;
		end
		else if( wr_en == 1'b1 )begin
			wr_flag <= 1'b1;
		end
		else;
	end
	
	always@( posedge clk )begin
		if( rst_n == 1'b0 )begin
			rd_flag <= 1'b0;
		end
		else if( cnt_bit == CNT_BIT_N - 1'b1 && cnt == CNT_N - 1'b1 && rd_flag == 1'b1 )begin
			rd_flag <= 1'b0;
		end
		else if( rd_en == 1'b1 )begin
			rd_flag <= 1'b1;
		end
		else;
	end
	
	always@( posedge clk )begin
		if( busy == 1'b1 )begin
			if( cnt == CNT_N - 1'b1 )begin
				cnt <= 8'd0;
			end
			else begin
				cnt <= cnt + 1'b1;
			end
		end
		else begin
			cnt <= 8'd0;
		end
	end
	
	always@( posedge clk )begin
		if( busy == 1'b1 )begin
			if( cnt_bit == CNT_BIT_N - 1'b1 && cnt == CNT_N - 1'b1 )begin
				cnt_bit <= 8'd0;
			end
			else if( cnt == CNT_N - 1'b1 )begin
				cnt_bit <= cnt_bit + 1'b1;
			end
			else;
		end
		else begin
			cnt_bit <= 8'd0;
		end
	end

	reg[DATA_WIDTH-1:0] drd_reg 	= 8'b0;
	
	reg[ADDR_WIDTH+DATA_WIDTH-1:0]data_reg;
	
	always@( posedge clk )begin
		if( wr_en == 1'b1 || rd_en == 1'b1 )begin
			data_reg <= {addr,dwr};
		end
		else if( busy == 1'b1 && cnt == CNT_N - 1'b1 && cnt_bit > 8'd0 )begin
			data_reg <= {data_reg[0+:ADDR_WIDTH+DATA_WIDTH-1],1'b0};
		end
		else;
	end

	
	always@( posedge clk )begin
		if( busy == 1'b1 && rd_flag == 1'b1 )begin
			if((cnt == CLK_DIV/2 - 1'b1) && (cnt_bit > ADDR_WIDTH) && (cnt_bit < ADDR_WIDTH + DATA_WIDTH + 8'd1))begin
				drd_reg <= {drd_reg[0+:DATA_WIDTH-1],SDI};			
			end
			else;
		end
		else ;
	end
	
	reg cs_n_o;
	
	
	always@( posedge clk )begin
		if( busy == 1'b0 )begin
			cs_n_o <= 1'b1;
		end
		else if( cnt_bit == CNT_BIT_N - 8'd2 && cnt == CNT_N - 1'b1)begin
			cs_n_o <= 1'b1;
		end
		else if( cnt_bit == 8'd0 && cnt == CNT_N - 1'b1 )begin
			cs_n_o <= 1'b0;
		end
		else;
	end
	
	reg sclk_o;
	
	always@( posedge clk )begin
		if( busy == 1'b1  )begin
			if( cnt == CNT_N/2 - 1'b1 )begin
				sclk_o <= ~sclk_o;
			end
			else if( cnt == CNT_N - 1'b1 )begin
				sclk_o <= ~sclk_o;
			end
			else;
		end
		else if( busy == 1'b0 )begin
			sclk_o <= 1'b0;
		end
		else;
	end
	
	always@( posedge clk )begin
		if( rst_n == 1'b0 )begin
			done <= 1'b0;
		end
		else if( busy == 1'b1 && cnt_bit == CNT_BIT_N - 8'd2 && cnt == CNT_N - 1'b1 && rd_flag == 1'b1 )begin
			done <= 1'b1;
		end
		else begin
			done <= 1'b0;
		end
	end
	
	always@( posedge clk )begin
		if( busy == 1'b1 && cnt_bit == CNT_BIT_N - 8'd2 && rd_flag == 1'b1 )begin
			drd  <= drd_reg;
		end
		else;
	end
	
	assign SDO = data_reg[ADDR_WIDTH+DATA_WIDTH-1];
	assign CS_N	= cs_n_o;
	assign SCLK = sclk_o;
	
	endmodule
	
	
	
	
	
	
