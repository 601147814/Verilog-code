	module ahb_slave#(
		parameter DW 			= 8'd32							,
		parameter AW 			= 8'd32							,
		parameter OFFSET	 	= 32'h0000_0000					,

		parameter SOF_RW_REG 	= 32'h0000_0000					,		
		parameter EOF_RW_REG 	= 32'h0000_00FF					,		
		parameter SOF_RD_REG 	= 32'h0000_0100					,		
		parameter EOF_RD_REG 	= 32'h0000_0103					,
		
		parameter REG_RD_NUM 	= EOF_RD_REG - SOF_RD_REG + 1	,
		parameter REG_RW_NUM 	= EOF_RW_REG - SOF_RW_REG + 1	,
		
		parameter FIFO_MODULE	= 1'b1							,
		parameter TX_FIFO_ADDR	= 32'h0000_0300					,
		parameter RX_FIFO_ADDR	= 32'h0000_0301					,
		
		parameter SRAM_MODULE	= 1'b1							,
		parameter SRAM_DW		= 32							,
		parameter SRAM_AW		= 7								,
		parameter SOF_SRAM_ADDR	= 32'h0000_4000					,
		parameter EOF_SRAM_ADDR	= SOF_SRAM_ADDR + 2**SRAM_AW - 1					
	)(
		input				HCLK			,
		input				HRESETN			,
		input	[AW-1:0]	HADDR			,
		input	[1:0]		HTRANS			,
		input				HWRITE			,
		input	[2:0]		HSIZE			,
		input	[2:0]		HBURST			,
	//	input				HPORT			,
		input	[DW/8-1:0]	HWSTRB			,
		input	[DW-1:0]	HWDATA			,
		input				HSEL			,
		output	[DW-1:0]	HRDATA			,
		input				HREADY_I		,
		output	reg			HREADY_O		,
		output				HRESP			,
	//	input				HNONSEC			,	// supported if AHB5 secure_transfers property is true
	//	input				HEXCL			,	// supported if AHB5 secure_transfers property is true
	//	input				HMASTER			,	// supported if AHB5 secure_transfers property is true
	
		output	[REG_RW_NUM*DW-1:0]reg_dout	,
		input	[REG_RD_NUM*DW-1:0]reg_din	,
		
		input	[DW-1:0]	rxdata			,
		input				rxdata_vld		,
		output				rxdata_full		,
		output				rxdata_alfull	,
		
		output				txdata			,
		input				txdata_vld		,
		output				txdata_empty	,
		output				txdata_alempty	
	);
	
	initial begin
		if( AW%8 != 0 )begin $display("$s$d DW is suggested to be a multiple of 8.",`__FILE__,`__LINE__);end
		if( DW%8 != 0 )begin $display("$s$d DW is suggested to be a multiple of 8.",`__FILE__,`__LINE__);end
	end
	
	wire clk 	= HCLK		;
	wire rstn 	= HRESETN;	
	
	wire[AW-1:0]addr = HADDR - OFFSET;
	wire[DW-1:0]ram_out;
	
	integer i;
	
	localparam OKAY		= 1'b0	;
	localparam ERROR	= 1'b1	;
	
	localparam IDLE		= 2'b00	;
	localparam BUSY		= 2'b01	;
	localparam NONSEQ	= 2'b10	;
	localparam SEQ		= 2'b11	;
	
	localparam WRITE	= 1'b1	;
	localparam READ		= 1'b0	;
	
	localparam SINGLE	= 3'b000;
	localparam INCR		= 3'b001;
	localparam WRAP4	= 3'b010;
	localparam INCR4	= 3'b011;
	localparam WRAP8	= 3'b100;
	localparam INCR8	= 3'b101;
	localparam WRAP16	= 3'b110;
	localparam INCR16	= 3'b111;
	
	wire ready = HREADY_I & HREADY_O;
	
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
	
	wire[DW-1:0]rdata_fifo;
	reg			rdata_fifo_vld;

	reg [1:0]		trans_r	;
	reg [AW-1:0]	addr_r	;
	reg 			hwrite_r;
	reg [DW/8-1:0]	hwstrb_r;
	
	reg [DW-1:0]rdata;
	
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			rdata <= {DW{1'b0}};
		end
		else if((( HTRANS[1] & ready & HSEL) == 1'b1) && (HWRITE == READ))begin
			if( (addr >= SOF_RW_REG ) && ( addr <= EOF_RW_REG))begin
				rdata <= rw_reg[addr-SOF_RW_REG];
			end
			else if( (addr >= SOF_RD_REG ) && ( addr <= EOF_RD_REG))begin
				rdata <= rw_reg[addr-SOF_RD_REG];
			end
			else if( (addr == RX_FIFO_ADDR ) && ( HWRITE == READ) && (HBURST!=WRAP4) && (HBURST!=WRAP8) && (HBURST!=WRAP16))begin
				rdata <= rdata_fifo;
			end
			else;
		end
		else ;
	end
	
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			trans_r	<= 2'b00;
			addr_r	<= {AW{1'b0}};
			hwrite_r<= 1'b0;
			hwstrb_r<= {DW/8{1'b1}};
		end
		else if( (ready & HSEL) == 1'b1)begin
			trans_r	<= trans	;
			addr_r	<= addr	    ;
			hwrite_r<= hwrite   ;
			hwstrb_r<= hwstrb   ;
		end
		else;
	end
	
	reg 				wdata_sram_vld	;
	reg 				wdata_fifo_vld	;
	reg [DW-1:0]		wdata_fifo		;
	reg [DW-1:0]		wdata_sram		;
	reg [SRAM_AW-1:0]	addr_sram		;
	
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			wdata_sram_vld 	<= 1'b0;
			wdata_sram 		<= {DW{1'b0}};
			addr_sram		<= {SRAM_AW{1'b0}};
			wdata_fifo		<= {DW{1'b0}};
			wdata_fifo_vld	<= 1'b0;
			for(i=0;i<REG_RW_NUM;I=I+1)begin
				rw_reg[i] <= {DW{1'b0}};
			end
		end
		else if((( trans_r[1] & ready & HSEL) == 1'b1) && (hwrite_r == WRITE))begin
			if((addr_r >= SOF_RW_REG) && (addr_r <= EOF_RW_REG))begin
				for(i=0;i<DW/8;i=i+1)begin:Wstrb_loop
					if(hwstrb_r[i] == 1'b1)begin
						rw_reg[addr_r-SOF_RW_REG][i*8+:8] <= HWDATA[i*8+:8];
					end
					else;
				end
				wdata_fifo_vld <= 1'b0;
				wdata_sram_vld <= 1'b0;
			end
			else if((addr_r >= SOF_SRAM_ADDR) && (addr_r <= EOF_SRAM_ADDR))begin
				wdata_sram <= HWDATA[SRAM_DW-1:0];
				wdata_sram_vld <= 1'b1;
				addr_sram <= addr_r - SOF_SRAM_ADDR;
				wdata_fifo_vld <= 1'b0;
			end
			else if((addr_r == TX_FIFO_ADDR) && (addr_r == RX_FIFO_ADDR))begin
				wdata_fifo <= HWDATA;
				wdata_fifo_vld <= 1'b1;
				wdata_sram_vld <= 1'b0;
			end
			else begin
				wdata_fifo_vld <= 1'b0;
				wdata_sram_vld <= 1'b0;
			end
		else begin
			wdata_fifo_vld <= 1'b0;
			wdata_sram_vld <= 1'b0;
		end
	end
	
	reg[AW-1:0]size;
	always@( * )begin
		case( HSIZE )
			3'b000:begin size = 32'h00;	end
	        3'b001:begin size = 32'h01;	end
            3'b010:begin size = 32'h03;	end
            3'b011:begin size = 32'h07;	end
            3'b100:begin size = 32'h0F;	end
            3'b101:begin size = 32'h1F;	end
            3'b110:begin size = 32'h2F;	end
            3'b111:begin size = 32'h3F;	end
			default:;
		endcase
	end
	
	wire wdata_fifo_full	;
	wire wdata_fifo_alfull	;
	wire rdata_fifo_empty	;
	
	reg response;
	
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			response <= OKAY;
			HREADY_O <= 1'b1;
		end
		else if( 2**HSIZE > DW/8 )begin
			response <= ERROR;
			HREADY_O <= 1'b0;
		end
		else if( (( trans_r[1] & ready & HSEL) == 1'b1) && (hwrite_r == WRITE) && (HWRITE == READ)&& (addr == addr_r))begin
			response <= OKAY;
			HREADY_O <= 1'b0;
		end
		else if( ( HTRANS[1] & ready & HSEL) == 1'b1)begin
		
			if((addr == TX_FIFO_ADDR) && ( wdata_fifo_full == 1'b0) && (HWRITE == WRITE) && (HBURST != WRAP16) && (HBURST != WRAP8) && (HBURST != WRAP4) && (FIFO_MODULE == 1'b1))begin
				response <= OKAY;
				HREADY_O <= 1'b1;
			end
			else if((addr == RX_FIFO_ADDR) && ( rdata_fifo_empty == 1'b0) && (HWRITE == READ) && (HBURST != WRAP16) && (HBURST != WRAP8) && (HBURST != WRAP4) && (FIFO_MODULE == 1'b1))begin
				response <= OKAY;
				HREADY_O <= 1'b1;
			end
			else if((addr >= SOF_RW_REG) && (addr <= EOF_RW_REG) && (HWRITE == READ) && ((addr & size) == {AW{1'b0}}))begin
				response <= OKAY;
				HREADY_O <= 1'b1;
			end
			else if((addr >= SOF_SRAM_ADDR) && (addr <= EOF_SRAM_ADDR) && (SRAM_MODULE == 1'b1) && ((addr & size) == {AW{1'b0}}))begin
				response <= OKAY;
				HREADY_O <= 1'b1;
			end
			else begin
				response <= ERROR;
				HREADY_O <= 1'b0;
			end
		end
		else if(HSEL == 1'b1)begin
			response <= response;
			HREADY_O <= 1'b1;
		end
		else begin
			response <= OKAY;
			HREADY_O <= 1'b1;
		end
	end
	
	generate if(FIFO_MODULE == 1'b1)begin:inst_fifo
		
	fifo_sync#(
		.DW 			( DW				),
		.AW 			( 3					)
	)fifo_tx(		
		.clk			( clk				),
		.rst			( ~rstn				),
		.din			( wdata_fifo		),
		.wr_en			( wdata_fifo_vld	),
		.rd_en			( txdata_vld		),
		.dout			( txdata			),
		.empty			( txdata_empty		),
		.alempty		( txdata_alempty	),
		.progempty		( 					),
		.full			( wdata_fifo_full	),
		.alfull			( wdata_fifo_alfull	),
		.progfull	    ( 					)
	);
	
	fifo_sync#(
		.DW 			( DW				),
		.AW 			( 3					)
	)fifo_rx(		
		.clk			( clk				),
		.rst			( ~rstn				),
		.din			( rdata_fifo		),
		.wr_en			( rdata_fifo_vld	),
		.rd_en			( rxdata_vld		),
		.dout			( rxdata			),
		.empty			( rxdata_empty		),
		.alempty		( rxdata_alempty	),
		.progempty		( 					),
		.full			( rdata_fifo_full	),
		.alfull			( rdata_fifo_alfull	),
		.progfull	    ( 					)
	);
	
	end
	else begin
		assign rxdata_full  	= 1'b1;
		assign rxdata_alfull  	= 1'b1;
		assign txdata_empty  	= 1'b1;
		assign txdata_alempty  	= 1'b1;
		assign txdata		  	= {DW{1'b0}};
	end
	
	endgenerate
	
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			rdata_fifo_vld <= 1'b0;
		end
		else if( rdata_fifo_vld == 1'b1 )begin
			rdata_fifo_vld <= 1'b0;
		end
		else if( (( HTRANS[1] & ready & HSEL) == 1'b1) && (HWRITE == READ) && (addr == RX_FIFO_ADDR) && ( HBURST != WRAP16) && ( HBURST != WRAP8) && ( HBURST != WRAP4))begin
			rdata_fifo_vld <= 1'b1;
		end
		else;
	end
	
	assign HRESP = response;
	assign HRDATA = ((addr_r >= SOF_SRAM_ADDR) && (addr_r <= EOF_SRAM_ADDR) && (SRAM_MODULE == 1'b1)) ? ram_out : rdata;
	
	generate if(SRAM_MODULE == 1'b1 )begin:inst_sram
	
		wire [SRAM_AW-1:0]	ram_addr = wdata_sram_vld == 1'b1 ? addr_sram : (addr - SOF_SRAM_ADDR);
		
		wire				ram_cen = ~HSEL;
		wire				ram_wen = ~wdata_sram_vld;
		
		wire [SRAM_AW-1:0]	ram_bist_addr = 0;
		wire				ram_bist_wen  = 1;
		wire				ram_bist_en   = 0;
		wire [DW-1:0]		ram_bist_data;
		
		wire 				test_mode = 1'b1;
		
		spsram_128x32 #(
			.HSEN		( 0			),
			.GC			( 1			),
			.PGMEN		( 0			),
			.TFF		( 0			)		
		)u_mem_32k(       			
			.PD 		( 2'b00		),
			.Q	 		( ram_out	),
			.A	 		( ram_addr	),
			.D	 		( wdata_sram),
			.WEN 		( ram_wen	),
			.CEN 		( ram_cen	),
			.CLK 		( clk		),

			.test_mode 	( test_mode 		),
			.bist_en 	( bist_en 			),
			.bist_addr 	( bist_addr[6:0]	),
			.bist_data 	( bist_data[31:0]	),
			.bist_web 	( bist_web 			),
		);
		
	end
	endgenerate
	
endmodule
