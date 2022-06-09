
	module ahb_dma_master#(
		parameter AW 			= 32	,	//	Address width
		parameter DW 			= 32	,	//	Data width
		parameter REG_RW_NUM	= 32	,	//	
		parameter REG_RD_NUM	= 3			//	
	)(
		input						HCLK			,
		input						HRESETN			,

		output						HBUSREQ			,
		output						HLOCK			,
		input						HGRANT			,
		input	[3-1:0]				HMASTER			,

		output	[AW-1:0]			HADDR			,
		output	[1:0]				HTRANS			,
		output						HWRITE			,
		output	[2:0]				HSIZE			,
		output	[2:0]				HBURST			,
	//	output						HPORT			,
		output	[DW/8-1:0]			HWSTRB			,
		output	[DW-1:0]			HWDATA			,
		output						HSEL			,
		input	[DW-1:0]			HRDATA			,
		output	reg					HREADY_O		,
		input						HREADY_I		,
		input						HRESP			,
		
		input	[DW-1:0]			txdata			,
		input						txdata_vld		,
		output						txdata_full		,
		output						txdata_alfull	,
		
		output	[DW-1:0]			rxdata			,
		input						rxdata_vld		,
		output						rxdata_empty	,
		output						rxdata_alempty	,
		
		output						irpt			,
		input	[DW*REG_RW_NUM-1:0]	din				,
		output	[DW*REG_RD_NUM-1:0]	dout			
	);
	
	localparam OKAY				= 1'b0	;
	localparam ERROR			= 1'b1	;
	
	localparam HWRITE_WRITE		= 1'b1	;
	localparam HWRITE_READ		= 1'b0	;
	
	localparam HTRANS_IDLE		= 2'b00	;
	localparam HTRANS_BUSY		= 2'b01	;
	localparam HTRANS_NONSEQ	= 2'b10	;
	localparam HTRANS_SEQ		= 2'b11	;
	
	localparam SINGLE			= 3'b000;
	localparam INCR				= 3'b001;
	localparam WRAP4			= 3'b010;
	localparam INCR4			= 3'b011;
	localparam WRAP8			= 3'b100;
	localparam INCR8			= 3'b101;
	localparam WRAP16			= 3'b110;
	localparam INCR16			= 3'b111;	
	
	localparam CMD_IDLE			= 3'd0	;
	localparam CMD_WRITE		= 3'd1	;
	localparam CMD_READ			= 3'd2	;
	localparam CMD_WR			= 3'd3	; // Write before read operation
	localparam CMD_RW			= 3'd4	; // Read before write operation
	
	wire[DW*REG_RW_NUM-1:0]rw_reg = din;
	
	wire clk 	= HCLK		;
	wire rstn 	= HRESETN	;

	/////////////////////////////////////////////////
	//
	// register mapping
	//
	/////////////////////////////////////////////////
	wire[DW-1:0]reg_0 = rw_reg[0*DW+:DW];
	wire[DW-1:0]reg_1 = rw_reg[1*DW+:DW];
	wire[DW-1:0]reg_2 = rw_reg[2*DW+:DW];
	wire[DW-1:0]reg_3 = rw_reg[3*DW+:DW];
	wire[DW-1:0]reg_4 = rw_reg[4*DW+:DW];
	
	wire[2:0]master_config_id = reg_0[0+:3];
	wire[2:0]slaver_config_id = reg_0[4+:3];
	wire	 s_rst 			  = reg_0[31];
	wire[15;0]irpt_status;
	
	wire[AW-1:0]addr = reg_1;
	reg [DW-1:0]data;
	
	wire[2:0]burst	= reg_3[0+:3];
	wire[2:0]size	= reg_3[4+:3];
	wire[3:0]wstrb	= reg_3[8+:4];
	wire[9:0]cnt_cfg= reg_3[12+:10];
	wire[9:0]cmd	= reg_3[30:28];
	wire	 lock	= reg_3[31];
	
	reg  done;
	wire response;
	reg  bus_req;
	reg  rdata_vld;
	reg[DW-1:0]  rdata;
	
	assign response = HRESP;
	wire[8:0]master_arbiter_id = {5'd0,HMASTER};
	
	assign dout[0*DW+:DW] = {{(DW-16){1'd0}},irpt_status};
	assign dout[1*DW+:DW] = {{(DW-4){1'd0}},rdata_vld,bus_req,done,response};
	assign dout[2*DW+:DW] = rdata;
	
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			bus_req <= 1'b0;
		end
		else if((cmd != CMD_IDLE ) && (done == 1'b0))begin
			bus_req <= 1'b1;
		end
		else if((HBUSREQ == 1'b1 ) && (lock == 1'b1))begin
			bus_req <= 1'b1;
		end
		else begin
			bus_req <= 1'b0;
		end
	end
	
	assign HBUSREQ = bus_req;
	assign HBURST = burst;
	
	reg[10:0]count;
	always@( * )begin
		if( (cmd == CMD_WR) || ( cmd == CMD_RW))begin
			count = 11'd2;
		end
		else begin
			case( burst )
				SINGLE	:begin count = {1'b0,10'd1};	end
				INCR	:begin count = {1'b0,cnt_cfg};	end
				WRAP4	:begin count = {1'b0,10'd4};	end
				INCR4	:begin count = {1'b0,10'd4};	end
				WRAP8	:begin count = {1'b0,10'd8};	end
				INCR8	:begin count = {1'b0,10'd8};	end
				WRAP16	:begin count = {1'b0,10'd16};	end
				INCR16	:begin count = {1'b0,10'd16};	end
				default:;
			endcase
		end
	end
	
	reg[AW-1:0]diff;
	always@( * )begin
		if( burst == SINGLE )begin
			diff = 32'd0;
		end
		else begin
			case( size )
				3'b000:begin diff = 32'h01;end
				3'b001:begin diff = 32'h02;end
				3'b010:begin diff = 32'h04;end
				3'b011:begin diff = 32'h08;end
				3'b100:begin diff = 32'h10;end
				3'b101:begin diff = 32'h20;end
				3'b110:begin diff = 32'h40;end
				3'b111:begin diff = 32'h80;end
				default:;
			endcase
		end
	end
	
	//				wrap4 		wrap8 		wrap16
	//	size 000 	100			1000		1_0000
	//	size 001 	1000		1_0000		10_0000
	//	size 010 	1_0000		10_0000		100_0000
	//	size 011 	10_0000		100_0000	1000_0000
	//	size 100 
	//	size 101 
	//	size 110 
	//	size 111 
	
	reg[AW-1:0]wrap_addr;
	always@( * )begin
		case( size )
			3'b000:begin if( burst == WRAP4 ) wrap_addr = {{(AW-2){1'b0}},{2{1'b1}}}; else if( burst == WRAP8 ) wrap_addr = {{(AW- 3){1'b0}},{ 3{1'b1}}}; else wrap_addr = {{(AW- 4){1'b0}},{ 4{1'b1}}};end
			3'b001:begin if( burst == WRAP4 ) wrap_addr = {{(AW-3){1'b0}},{3{1'b1}}}; else if( burst == WRAP8 ) wrap_addr = {{(AW- 4){1'b0}},{ 4{1'b1}}}; else wrap_addr = {{(AW- 5){1'b0}},{ 5{1'b1}}};end
			3'b010:begin if( burst == WRAP4 ) wrap_addr = {{(AW-4){1'b0}},{4{1'b1}}}; else if( burst == WRAP8 ) wrap_addr = {{(AW- 5){1'b0}},{ 5{1'b1}}}; else wrap_addr = {{(AW- 6){1'b0}},{ 6{1'b1}}};end
			3'b011:begin if( burst == WRAP4 ) wrap_addr = {{(AW-5){1'b0}},{5{1'b1}}}; else if( burst == WRAP8 ) wrap_addr = {{(AW- 6){1'b0}},{ 6{1'b1}}}; else wrap_addr = {{(AW- 7){1'b0}},{ 7{1'b1}}};end
			3'b100:begin if( burst == WRAP4 ) wrap_addr = {{(AW-6){1'b0}},{6{1'b1}}}; else if( burst == WRAP8 ) wrap_addr = {{(AW- 7){1'b0}},{ 7{1'b1}}}; else wrap_addr = {{(AW- 8){1'b0}},{ 8{1'b1}}};end
			3'b101:begin if( burst == WRAP4 ) wrap_addr = {{(AW-7){1'b0}},{7{1'b1}}}; else if( burst == WRAP8 ) wrap_addr = {{(AW- 8){1'b0}},{ 8{1'b1}}}; else wrap_addr = {{(AW- 9){1'b0}},{ 9{1'b1}}};end
			3'b110:begin if( burst == WRAP4 ) wrap_addr = {{(AW-8){1'b0}},{8{1'b1}}}; else if( burst == WRAP8 ) wrap_addr = {{(AW- 9){1'b0}},{ 9{1'b1}}}; else wrap_addr = {{(AW-10){1'b0}},{10{1'b1}}};end
			3'b111:begin if( burst == WRAP4 ) wrap_addr = {{(AW-9){1'b0}},{9{1'b1}}}; else if( burst == WRAP8 ) wrap_addr = {{(AW-10){1'b0}},{10{1'b1}}}; else wrap_addr = {{(AW-11){1'b0}},{11{1'b1}}};end
			default:;
		endcase
	end
	
	integer i;
	reg[10:0]cnt;
	reg[AW-1:0]addr_temp;
	
	wire ready = HREADY_I & HREADY_O;
	
	localparam[12*4-1:0]K = {
		4'd14,
		4'd13,
		4'd12,
		4'd11,
		4'd10,
		4'd9 ,
		4'd8 ,
		4'd7 ,
		4'd6 ,
		4'd5 ,
		4'd4 ,
		4'd3
	};
	
	assign HADDR = addr_temp;
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			addr_temp <= {AW{1'b0}};
		end
		else if((HBUSREQ == 1'b0) || (HGRANT == 1'b0) || (cmd == CMD_WR) || (cmd == CMD_RW))begin
			addr_temp <= addr;
		end
		else if((burst != WRAP4) && (burst != WRAP8) && (burst != WRAP16) && ((ready & HTRANS[1]) ==1'b1 ))begin
			addr_temp <= addr_temp + diff;
		end
		else if( (ready & HTRANS[1]) ==1'b1 )begin
			if(((addr_temp + diff ) & wrap_addr ) == 0 )begin
				addr_temp <= addr_temp & (~wrap_addr);
			end
			else begin
				addr_temp <= addr_temp + diff;
			end
		end
		else ;
	end
	
	wire rdata_full;
	wire rdata_alfull;
	wire rdata_profull;
	wire [DW-1:0]wdata;
	wire 		 wdata_rd;
	wire 		 wdata_empty;
	wire 		 wdata_alempty;
	
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			HREADY_O <= 1'b0;
		end
		else if( ((cnt == count) && (ready == 1'b1)) || (done == 1'b1) )begin
			HREADY_O <= 1'b0;
		end
		else if( (HBUSREQ == 1'b1) && (HGRANT == 1'b1) )begin
			HREADY_O <= 1'b1;
		end
		else ;
	end
	
	reg[1:0]trnas;
	
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			cnt <= 11'd0;
		end
		else if((cmd == CMD_IDLE) || (done == 1'b1))begin
			cnt <= 11'd0;
		end
		else if((cnt == count) || (ready == 1'b1))begin
			cnt <= 11'd0;
		end
		else if((ready == 1'b1) || (trnas[1] == 1'b1))begin
			cnt <= cnt + 1'd1;
		end
		else if((ready == 1'b1) || (cnt == count - 1'b1))begin
			cnt <= cnt + 1'd1;
		end
		else ;
	end
	
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			trnas <= HTRANS_IDLE;
		end
		else if( (cmd == CMD_IDLE) || (done == 1'b1) )begin
			trnas <= HTRANS_IDLE;
		end
		else if( ((HWRITE == HWRITE_READ) && (rdata_profull == 1'b1)) || ((HWRITE == HWRITE_WRITE) && (wdata_empty == 1'b1)) )begin
			trnas <= HTRANS_BUSY;
		end
		else if( (cnt == count - 1'b1) &&  ((ready & HTRANS[1]) ==1'b1 ))begin
			trnas <= HTRANS_IDLE;
		end
		else if( (cnt == 11'd0) && ( ready == 1'b1 ))begin
			trnas <= HTRANS_SEQ;
		end
		else if( cnt == 11'd0 ) begin
			trnas <= HTRANS_NONSEQ;
		end
		else if( cnt < count ) begin
			trnas <= HTRANS_SEQ;
		end
		else;
	end
	
	assign HTRANS = trnas;
	
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			write <= HWRITE_READ;
		end
		else if( cmd == CMD_WRITE )begin
			if((cnt >= count - 1'b1) && (ready == 1'b1))begin
				write <= HWRITE_READ;
			end
			else begin
				write <= HWRITE_WRITE;
			end
		end
		else if((cmd == CMD_WR) && ((ready & HTRANS[1]) ==1'b1 ))begin
			write <= HWRITE_WRITE;
		end
		else if((cmd == CMD_RW) && (ready == 1'b1 ) && ( cnt == 11'd0 ))begin
			write <= HWRITE_WRITE;
		end
		else begin
			write <= HWRITE_READ;
		end
	end
	
	assign HWRITE = write;
	
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			done <= 1'b0;
		end
		else if( cmd == CMD_IDLE )begin
			done <= 1'b0;
		end
		else if( (cnt == count) && (ready == 1'b1) )begin
			done <= 1'b1;
		end
		else if( done == 1'b1 )begin
			done <= 1'b1;
		end
		else begin
			done <= 1'b0;
		end
	end
	
	reg  ready_r;
	reg  respose_r;
	reg  hwrite_r;
	reg [1:0] trans_r;
	reg [AW-1:0] addr_r;
	
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			trans_r <= 2'b00;
			addr_r  <= {AW{1'b0}};
			hwrite_r<= 1'b0;
		end
		else if( (ready & HSEL) == 1'b1)begin
			trans_r <= HTRANS;
			addr_r  <= addr;
			hwrite_r<= HWRITE;
		end
		else ;
	end
	
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			rdata <= {DW{1'b0}};
			rdata_vld <= 1'b0;
		end
		else if( ((ready & trans_r[1] & ~HRESP) == 1'b1 ) && (hwrite_r == HWRITE_READ) )begin
			rdata <= HRDATA;
			rdata_vld <= 1'b1;
		end
		else begin
			rdata_vld <= 1'b0;
		end
	end
	
	wire wdata_rd_ture = ( ready & HTRANS[1] & HWRITE);
	
	assign wdata_rd = ~wdata_empty & wdata_rd_ture;
	
	assign HLOCK  = lock;
	assign HSIZE  = size;
	assign HWSTRB = wstrb;
	assign HSEL   = 1'b1;
	
	
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			data <= {DW{1'b0}};
		end
		else begin
			data <= wdata;
		end
	end
	
	
	fifo_sync#(
		.DW 			( DW				),
		.AW 			( 6					)
	)fifo_wdata(		
		.clk			( clk				),
		.rst			( ~rstn	| s_rst		),
		.din			( txdata			),
		.wr_en			( txdata_vld		),
		.rd_en			( wdata_rd			),
		.dout			( wdata				),
		.empty			( wdata_empty		),
		.alempty		( wdata_alempty		),
		.progempty		( 					),
		.full			( txdata_full		),
		.alfull			( txdata_alfull		),
		.progfull	    ( 					)
	);
	
	fifo_sync#(
		.DW 			( DW				),
		.AW 			( 5					)
	)fifo_rdata(		
		.clk			( clk				),
		.rst			( ~rstn	| s_rst		),
		.din			( rdata				),
		.wr_en			( rdata_vld			),
		.rd_en			( rxdata_vld		),
		.dout			( rxdata			),
		.empty			( rxdata_empty		),
		.alempty		( rxdata_alempty	),
		.progempty		( 					),
		.full			( rdata_full		),
		.alfull			( rdata_alfull		),
		.progfull	    ( rdata_profull		)
	);
	
	assign irpt = |irpt_status;
	
	reg[1:0]irpt_r;
	always@( posedge clk )begin
		irpt_r <= {irpt_r[0],irpt};
	end
	
	always@( posedge clk )begin
		if( (irpt_r[0] & ~irpt_r[1]) == 1'b1 )$display("%t interrupt occurred !" , $realtime );
	end	
	
	reg irpt_timeout		;
	reg irpt_txfifo_rd_empty;
	reg irpt_txfifo_wr_full	;
	reg irpt_rxfifo_rd_empty;
	reg irpt_rxfifo_wr_full	;
	reg irpt_resposne_error	;
	
	assign irpt_status = {
		{10{1'b0}}			,
		irpt_timeout		,
		irpt_txfifo_rd_empty,
		irpt_txfifo_wr_full	,
		irpt_rxfifo_rd_empty,
		irpt_rxfifo_wr_full	,
		irpt_resposne_error	
	};

	localparam COUNT_IRPT = 16'h00FF;
	reg [15:0]cnt_timeout;
	
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			cnt_timeout <= 16'd0;
		end
		else if( (cmd == CMD_IDLE) || ( s_rst == 1'b1 ))begin
			cnt_timeout <= 16'd0;
		end
		else if( cnt_timeout == COUNT_IRPT )begin
			cnt_timeout <= cnt_timeout;
		end
		else if( (cmd != CMD_IDLE) && (ready == 1'b1) && ( HTRANS == HTRANS_BUSY))begin
			cnt_timeout <= cnt_timeout + 1'b1;
		end
		else;
	end
	
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			irpt_timeout <= 1'd0;
		end
		else if( s_rst == 1'b1 )begin
			irpt_timeout <= 1'd0;
		end
		else if( cnt_timeout == COUNT_IRPT )begin
			irpt_timeout <= 1'b1;
		end
		else begin
			irpt_timeout <= 1'b0;
		end
	end
	
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			irpt_txfifo_rd_empty  <= 1'b0;
			irpt_txfifo_wr_full	  <= 1'b0;
			irpt_rxfifo_rd_empty  <= 1'b0;
			irpt_rxfifo_wr_full	  <= 1'b0;
		end
		else if( s_rst == 1'b1 )begin
			irpt_txfifo_rd_empty  <= 1'b0;
			irpt_txfifo_wr_full	  <= 1'b0;
			irpt_rxfifo_rd_empty  <= 1'b0;
			irpt_rxfifo_wr_full	  <= 1'b0;
		end
		else if( (txdata_vld == 1'b1) && (txdata_full == 1'b1))begin
			irpt_txfifo_wr_full	  <= 1'b1;
		end
		else if( (rxdata_vld == 1'b1) && (rxdata_full == 1'b1))begin
			irpt_rxfifo_wr_full	  <= 1'b1;
		end
		else if( (wdata_rd == 1'b1) && (wdata_empty == 1'b1))begin
			irpt_txfifo_rd_empty	  <= 1'b1;
		end
		else if( (rdata_vld == 1'b1) && (rxdata_empty == 1'b1))begin
			irpt_rxfifo_rd_empty	  <= 1'b1;
		end
		else;
	end
	
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			irpt_resposne_error <= 1'b0;
		end
		else if( s_rst == 1'b1 )begin
			irpt_resposne_error <= 1'b0;
		end
		else if( (ready == 1'b1) && (HRESP == ERROR))begin
			irpt_resposne_error <= 1'b1;
		end
		else ;
	end
	
	endmodule
