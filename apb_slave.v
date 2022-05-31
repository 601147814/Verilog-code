	//	Not emulated
	module apb_slave#(
		parameter DW 			= 32							,
		parameter AW 			= 32							,
		parameter OFFSET	 	= 32'h0000_0000					,

		parameter SOF_RW_REG 	= 32'h0000_0000					,		
		parameter EOF_RW_REG 	= 32'h0000_00FF					,		
		parameter SOF_RD_REG 	= 32'h0000_0100					,		
		parameter EOF_RD_REG 	= 32'h0000_0103					,
		
		parameter REG_RD_NUM 	= EOF_RD_REG - SOF_RD_REG + 1	,
		parameter REG_RW_NUM 	= EOF_RW_REG - SOF_RW_REG + 1	
	)(
		input						PCLK		,
		input						PRESETN		,
		input						PSEL		,
		input						PENABLE		,
		input	[AW-1:0]			PADDR		,
		input						PWRITE		,
	//	input	[ 2-1:0]			PPROT		,
	//	input	[ 9-1:0]			PUSER		,
		input	[DW-1:0]			PWDATA		,
		output	[DW-1:0]			PRDATA		,
		output						PREADY		,
		output						PSLVERR		,
		
		output	[REG_RW_NUM*DW-1:0]	reg_dout	,
		input	[REG_RD_NUM*DW-1:0]	reg_din		
	);
	
	wire clk 	= PCLK		;
	wire rstn 	= PRESETN	;
	
	localparam WRITE	= 1'b1	;
	localparam READ		= 1'b0	;
	
	localparam OKAY		= 1'b0	;
	localparam ERROR	= 1'b1	;	
	
	wire[AW-1:0]addr = HADDR - OFFSET;	
	
	reg [DW-1:0]rw_reg[REG_RW_NUM-1:0];
	wire[DW-1:0]rd_reg[REG_RD_NUM-1:0];
	
	genvar j;
	generate for ( j=0;j<REG_RW_NUM;j=j+1)begin:Rw_reg
		assign reg_dout[j*DW+:DW] = rw_reg[j];
	end
	endgenerate
	
	generate for ( j=0;j<REG_RD_NUM;j=j+1)begin:Rd_reg
		assign rd_reg[j] = reg_din[j*DW+:DW];
	end
	endgenerate
	
	reg [DW-1:0]rdata;
	
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			rdata <= {DW{1'b0}};
		end
		else if(( PSEL == 1'b1 ) && ( PWRITE == READ ))begin
			if( (addr >= SOF_RW_REG ) && ( addr <= EOF_RW_REG))begin
				rdata <= rw_reg[addr-SOF_RW_REG];
			end
			else if( (addr >= SOF_RD_REG ) && ( addr <= EOF_RD_REG))begin
				rdata <= rd_reg[addr-SOF_RD_REG];
			end
			else;
		end
		else ;
	end
	
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			for(i=0;i<REG_RW_NUM;I=I+1)begin
				rw_reg[i] <= {DW{1'b0}};
			end
		end
		else if((( PSEL & PENABLE & PREADY) == 1'b1 ) && ( PWRITE == WRITE ) && (addr >= SOF_RW_REG) && (addr <= EOF_RW_REG))begin
			for(i=0;i<DW/8;I=I+1)begin:Wstrb_loop
				if(hwstrb_r[i] == 1'b1)begin
					rw_reg[addr-SOF_RW_REG][i*8+:8] <= PWDATA[i*8+:8];
				end
				else;
			end
		end
		else;
	end
	
	reg response;
	reg ready	;
	
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			ready <= 1'b0;
		end
		else if( ( PSEL & PENABLE & PREADY ) == 1'b1 )begin
			ready <= 1'b0;
		end
		else if( PSEL == 1'b1 )begin
			ready <= 1'b1;
		end
		else;
	end
	
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			response <= OKAY;
		end
		else if( ( PSEL == 1'b1 ) && ( ( addr <= SOF_RD_REG ) || ( addr >= EOF_RD_REG ) || ( PWRITE == WRITE )) )begin
			response <= ERROR;
		end
		else if( ( PSEL == 1'b1 ) && ( ( addr <= SOF_RW_REG ) || ( addr >= EOF_RW_REG ) ) )begin
			response <= ERROR;
		end
		else begin
			response <= OKAY;
		end
	end
	
	assign PREADY 	= ready;
	assign PSLVERR 	= response;
	assign PRDATA 	= rdata;
	
	endmodule
