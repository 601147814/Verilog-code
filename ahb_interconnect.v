	module ahb_interconnect#(
		parameter M_NUM = 3'd4	,
		parameter N_NUM = 3'd4	,
		parameter DW 	= 3'd32	,
		parameter AW 	= 3'd32	
	)(
		input						HCLK		,
		input						HRESETN		,
		input		[M_NUM* 1-1:0]	HBUSREQ		,
		output		[M_NUM* 1-1:0]	HGRANT		,
		output		[		4-1:0]	HMASTER		,
		// Master Port
		input		[M_NUM*AW-1:0]	M_HADDR		,
		input		[M_NUM* 2-1:0]	M_HTRANS	,
		input		[M_NUM* 1-1:0]	M_HWRITE	,
		input		[M_NUM* 3-1:0]	M_HSIZE		,
		input		[M_NUM* 3-1:0]	M_HBURST	,
	//	input		[M_NUM* 4-1:0]	M_HPORT		,
		input		[M_NUM*DW/8-1:0]M_HWSTRB	,
		input		[M_NUM*DW-1:0]	M_HWDATA	,
		input		[M_NUM* 1-1:0]	M_HSEL		,
		output reg	[	   DW-1:0]	M_HRDATA	,
		input		[M_NUM* 1-1:0]	M_HREADY_O	,
		output reg	[		1-1:0]	M_HREADY_I	,
		output reg	[		1-1:0]	M_HRESP		,
		input 		[M_NUM* 1-1:0]	M_HLOCK		,
		// Slave Port
		output reg 	[		AW-1:0]	S_HADDR		,
		output reg 	[		 2-1:0]	S_HTRANS	,
		output reg 	[		 1-1:0]	S_HWRITE	,
		output reg 	[		 3-1:0]	S_HSIZE		,
		output reg 	[		 3-1:0]	S_HBURST	,
	//	output reg 	[		 4-1:0]	S_HPORT		,
		output reg 	[		DW/8-1:0]S_HWSTRB	,
		output reg 	[		DW-1:0]	S_HWDATA	,
		output  	[S_NUM* 1-1:0]	S_HSELX		,
		input 		[S_NUM*DW-1:0]	S_HRDATA	,
		output reg	[		1-1:0]	S_HREADY_I	,
		input 		[S_NUM* 1-1:0]	S_HREADY_O	,
		input 		[S_NUM* 1-1:0]	S_HRESP		,
		output reg	[		1-1:0]	S_HLOCK		,
	);
	initial begin 
		if( AW%8 != 0 )begin $display("$s$d DW is suggested to be a multiple of 8.",`__FILE__,`__LINE__);end
		if( DW%8 != 0 )begin $display("$s$d DW is suggested to be a multiple of 8.",`__FILE__,`__LINE__);end
		if( M_NUM > 16 || M_NUM == 0)begin $display("$s$d M_NUM must be smaller than 16",`__FILE__,`__LINE__);end
		if( S_NUM > 16 || S_NUM == 0)begin $display("$s$d M_NUM must be smaller than 16",`__FILE__,`__LINE__);end
	end
	
	wire clk 	= HCLK		;
	wire rstn 	= HRESETN	;
	
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
	
	reg[3:0]master_id;
	assign HMASTER = master_id;
	
	wire[16-1:0] m_select = {{(16-M_NUM){1'b0},(HBUSREQ & HGRANT)}};
	
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			master_id <= 4'd0;
		end
		else begin
			case( m_select )
				16'b0000_0000_0000_0001:begin master_id <= 4'h0; end
				16'b0000_0000_0000_0010:begin master_id <= 4'h1; end
				16'b0000_0000_0000_0100:begin master_id <= 4'h2; end
				16'b0000_0000_0000_1000:begin master_id <= 4'h3; end
				16'b0000_0000_0001_0000:begin master_id <= 4'h4; end
				16'b0000_0000_0010_0000:begin master_id <= 4'h5; end
				16'b0000_0000_0100_0000:begin master_id <= 4'h6; end
				16'b0000_0000_1000_0000:begin master_id <= 4'h7; end
				16'b0000_0001_0000_0000:begin master_id <= 4'h8; end
				16'b0000_0010_0000_0000:begin master_id <= 4'h9; end
				16'b0000_0100_0000_0000:begin master_id <= 4'hA; end
				16'b0000_1000_0000_0000:begin master_id <= 4'hB; end
				16'b0001_0000_0000_0000:begin master_id <= 4'hC; end
				16'b0010_0000_0000_0000:begin master_id <= 4'hD; end
				16'b0100_0000_0000_0000:begin master_id <= 4'hE; end
				16'b1000_0000_0000_0000:begin master_id <= 4'hF; end
				default				   :begin master_id <= 4'h0; end
			endcase
		end
	end
	
	reg [16-1:0]grant;
	wire[16-1:0]busreq = {{(16-M_NUM){1'b0},HBUSREQ};
	wire[16-1:0]lock   = {{(16-M_NUM){1'b0},M_HLOCK};
	assign HGRANT = grant;
	
	always@( negedge rstn or posedge clk )begin
		if( rstn == 1'b0 )begin
			grant <= 16'd0;
		end	else if( (lock & m_select) != 16'd0 )begin
			grant <= grant;
		end	else if( busreq[0] == 1'b1 )begin
			grant <= 16'b0000_0000_0000_0001;
		end	else if( busreq[1] == 1'b1 )begin
			grant <= 16'b0000_0000_0000_0010;
		end	else if( busreq[2] == 1'b1 )begin
			grant <= 16'b0000_0000_0000_0100;
		end	else if( busreq[3] == 1'b1 )begin
			grant <= 16'b0000_0000_0000_1000;
		end	else if( busreq[4] == 1'b1 )begin
			grant <= 16'b0000_0000_0001_0000;
		end	else if( busreq[5] == 1'b1 )begin
			grant <= 16'b0000_0000_0010_0000;
		end	else if( busreq[6] == 1'b1 )begin
			grant <= 16'b0000_0000_0100_0000;
		end	else if( busreq[7] == 1'b1 )begin
			grant <= 16'b0000_0000_1000_0000;
		end	else if( busreq[8] == 1'b1 )begin
			grant <= 16'b0000_0001_0000_0000;
		end	else if( busreq[9] == 1'b1 )begin
			grant <= 16'b0000_0010_0000_0000;
		end	else if( busreq[10] == 1'b1 )begin
			grant <= 16'b0000_0100_0000_0000;
		end	else if( busreq[11] == 1'b1 )begin
			grant <= 16'b0000_1000_0000_0000;
		end	else if( busreq[12] == 1'b1 )begin
			grant <= 16'b0001_0000_0000_0000;
		end	else if( busreq[13] == 1'b1 )begin
			grant <= 16'b0010_0000_0000_0000;
		end	else if( busreq[14] == 1'b1 )begin
			grant <= 16'b0100_0000_0000_0000;
		end	else if( busreq[15] == 1'b1 )begin
			grant <= 16'b1000_0000_0000_0000;
		end	else ;
	end
	
	wire[  AW*4-1:0]addr  = {{((16-M_NUM)*  AW){1'b0}},M_HADDR	};
	wire[   2*4-1:0]trans = {{((16-M_NUM)*   2){1'b0}},M_HTRANS	};
	wire[   1*4-1:0]write = {{((16-M_NUM)*   1){1'b0}},M_HWRITE	};
	wire[   3*4-1:0]size  = {{((16-M_NUM)*   3){1'b0}},M_HSIZE	};
	wire[   3*4-1:0]burst = {{((16-M_NUM)*   3){1'b0}},M_HBURST	};
	wire[DW/8*4-1:0]wstrb = {{((16-M_NUM)*DW/8){1'b0}},M_HWSTRB	};
	wire[  DW*4-1:0]wdata = {{((16-M_NUM)*  DW){1'b0}},M_HWDATA	};
	wire[   1*4-1:0]m_ready = {{((16-M_NUM)*   1){1'b0}},M_HREADY_O	};
	
	always@( * )begin
		case( m_select )
		16'b0000_0000_0000_0001:begin S_HADDR = addr[ 0*AW+:AW]; S_HTRANS = trans[ 0*2+:2]; S_HWRITE = write[ 0]; S_HSIZE = size[ 0*3+:3]; S_HBURST = burst[ 0*3+:3]; S_HWSTRB = wstrb[ 0*DW/8+:DW/8]; S_HWDATA = wdata[ 0*DWD+:DW]; S_HREADY_I = m_ready[ 0]; S_HLOCK =  lock[ 0]; end
		16'b0000_0000_0000_0010:begin S_HADDR = addr[ 1*AW+:AW]; S_HTRANS = trans[ 1*2+:2]; S_HWRITE = write[ 1]; S_HSIZE = size[ 1*3+:3]; S_HBURST = burst[ 1*3+:3]; S_HWSTRB = wstrb[ 1*DW/8+:DW/8]; S_HWDATA = wdata[ 1*DWD+:DW]; S_HREADY_I = m_ready[ 1]; S_HLOCK =  lock[ 1]; end
		16'b0000_0000_0000_0100:begin S_HADDR = addr[ 2*AW+:AW]; S_HTRANS = trans[ 2*2+:2]; S_HWRITE = write[ 2]; S_HSIZE = size[ 2*3+:3]; S_HBURST = burst[ 2*3+:3]; S_HWSTRB = wstrb[ 2*DW/8+:DW/8]; S_HWDATA = wdata[ 2*DWD+:DW]; S_HREADY_I = m_ready[ 2]; S_HLOCK =  lock[ 2]; end
		16'b0000_0000_0000_1000:begin S_HADDR = addr[ 3*AW+:AW]; S_HTRANS = trans[ 3*2+:2]; S_HWRITE = write[ 3]; S_HSIZE = size[ 3*3+:3]; S_HBURST = burst[ 3*3+:3]; S_HWSTRB = wstrb[ 3*DW/8+:DW/8]; S_HWDATA = wdata[ 3*DWD+:DW]; S_HREADY_I = m_ready[ 3]; S_HLOCK =  lock[ 3]; end
		16'b0000_0000_0001_0000:begin S_HADDR = addr[ 4*AW+:AW]; S_HTRANS = trans[ 4*2+:2]; S_HWRITE = write[ 4]; S_HSIZE = size[ 4*3+:3]; S_HBURST = burst[ 4*3+:3]; S_HWSTRB = wstrb[ 4*DW/8+:DW/8]; S_HWDATA = wdata[ 4*DWD+:DW]; S_HREADY_I = m_ready[ 4]; S_HLOCK =  lock[ 4]; end
		16'b0000_0000_0010_0000:begin S_HADDR = addr[ 5*AW+:AW]; S_HTRANS = trans[ 5*2+:2]; S_HWRITE = write[ 5]; S_HSIZE = size[ 5*3+:3]; S_HBURST = burst[ 5*3+:3]; S_HWSTRB = wstrb[ 5*DW/8+:DW/8]; S_HWDATA = wdata[ 5*DWD+:DW]; S_HREADY_I = m_ready[ 5]; S_HLOCK =  lock[ 5]; end
		16'b0000_0000_0100_0000:begin S_HADDR = addr[ 6*AW+:AW]; S_HTRANS = trans[ 6*2+:2]; S_HWRITE = write[ 6]; S_HSIZE = size[ 6*3+:3]; S_HBURST = burst[ 6*3+:3]; S_HWSTRB = wstrb[ 6*DW/8+:DW/8]; S_HWDATA = wdata[ 6*DWD+:DW]; S_HREADY_I = m_ready[ 6]; S_HLOCK =  lock[ 6]; end
		16'b0000_0000_1000_0000:begin S_HADDR = addr[ 7*AW+:AW]; S_HTRANS = trans[ 7*2+:2]; S_HWRITE = write[ 7]; S_HSIZE = size[ 7*3+:3]; S_HBURST = burst[ 7*3+:3]; S_HWSTRB = wstrb[ 7*DW/8+:DW/8]; S_HWDATA = wdata[ 7*DWD+:DW]; S_HREADY_I = m_ready[ 7]; S_HLOCK =  lock[ 7]; end
		16'b0000_0001_0000_0000:begin S_HADDR = addr[ 8*AW+:AW]; S_HTRANS = trans[ 8*2+:2]; S_HWRITE = write[ 8]; S_HSIZE = size[ 8*3+:3]; S_HBURST = burst[ 8*3+:3]; S_HWSTRB = wstrb[ 8*DW/8+:DW/8]; S_HWDATA = wdata[ 8*DWD+:DW]; S_HREADY_I = m_ready[ 8]; S_HLOCK =  lock[ 8]; end
		16'b0000_0010_0000_0000:begin S_HADDR = addr[ 9*AW+:AW]; S_HTRANS = trans[ 9*2+:2]; S_HWRITE = write[ 9]; S_HSIZE = size[ 9*3+:3]; S_HBURST = burst[ 9*3+:3]; S_HWSTRB = wstrb[ 9*DW/8+:DW/8]; S_HWDATA = wdata[ 9*DWD+:DW]; S_HREADY_I = m_ready[ 9]; S_HLOCK =  lock[ 9]; end
		16'b0000_0100_0000_0000:begin S_HADDR = addr[10*AW+:AW]; S_HTRANS = trans[10*2+:2]; S_HWRITE = write[10]; S_HSIZE = size[10*3+:3]; S_HBURST = burst[10*3+:3]; S_HWSTRB = wstrb[10*DW/8+:DW/8]; S_HWDATA = wdata[10*DWD+:DW]; S_HREADY_I = m_ready[10]; S_HLOCK =  lock[10]; end
		16'b0000_1000_0000_0000:begin S_HADDR = addr[11*AW+:AW]; S_HTRANS = trans[11*2+:2]; S_HWRITE = write[11]; S_HSIZE = size[11*3+:3]; S_HBURST = burst[11*3+:3]; S_HWSTRB = wstrb[11*DW/8+:DW/8]; S_HWDATA = wdata[11*DWD+:DW]; S_HREADY_I = m_ready[11]; S_HLOCK =  lock[11]; end	
        16'b0001_0000_0000_0000:begin S_HADDR = addr[12*AW+:AW]; S_HTRANS = trans[12*2+:2]; S_HWRITE = write[12]; S_HSIZE = size[12*3+:3]; S_HBURST = burst[12*3+:3]; S_HWSTRB = wstrb[12*DW/8+:DW/8]; S_HWDATA = wdata[12*DWD+:DW]; S_HREADY_I = m_ready[12]; S_HLOCK =  lock[12]; end
        16'b0010_0000_0000_0000:begin S_HADDR = addr[13*AW+:AW]; S_HTRANS = trans[13*2+:2]; S_HWRITE = write[13]; S_HSIZE = size[13*3+:3]; S_HBURST = burst[13*3+:3]; S_HWSTRB = wstrb[13*DW/8+:DW/8]; S_HWDATA = wdata[13*DWD+:DW]; S_HREADY_I = m_ready[13]; S_HLOCK =  lock[13]; end
        16'b0100_0000_0000_0000:begin S_HADDR = addr[14*AW+:AW]; S_HTRANS = trans[14*2+:2]; S_HWRITE = write[14]; S_HSIZE = size[14*3+:3]; S_HBURST = burst[14*3+:3]; S_HWSTRB = wstrb[14*DW/8+:DW/8]; S_HWDATA = wdata[14*DWD+:DW]; S_HREADY_I = m_ready[14]; S_HLOCK =  lock[14]; end
        16'b1000_0000_0000_0000:begin S_HADDR = addr[15*AW+:AW]; S_HTRANS = trans[15*2+:2]; S_HWRITE = write[15]; S_HSIZE = size[15*3+:3]; S_HBURST = burst[15*3+:3]; S_HWSTRB = wstrb[15*DW/8+:DW/8]; S_HWDATA = wdata[15*DWD+:DW]; S_HREADY_I = m_ready[15]; S_HLOCK =  lock[15]; end
		default				   :begin S_HADDR = {AW{1'b0}}; S_HTRANS = IDLE; S_HWRITE = READ; S_HSIZE = 3'b010; S_HBURST = SINGLE; S_HWSTRB = {(DW/8){1'b1}]; S_HWDATA = wdata[ 0*DWD+:DW]; S_HREADY_I = 1'b0; S_HLOCK =  1'b0; end
		endcase
	end
	
	reg[32-1:0]hsel;
	always@( * )begin
		if( HBUSREQ == {M_NUM{1'b0}})begin
			hsel = 32'd0;
		end
		else begin
			case( S_HADDR[AW-1-:4] )
				4'd 0:begin hsel = 32'b0000_0000_0000_0000_0000_0000_0000_0001; end
				4'd 1:begin hsel = 32'b0000_0000_0000_0000_0000_0000_0000_0010; end
				4'd 2:begin hsel = 32'b0000_0000_0000_0000_0000_0000_0000_0100; end
				4'd 3:begin hsel = 32'b0000_0000_0000_0000_0000_0000_0000_1000; end
				4'd 4:begin hsel = 32'b0000_0000_0000_0000_0000_0000_0001_0000; end
				4'd 5:begin hsel = 32'b0000_0000_0000_0000_0000_0000_0010_0000; end
				4'd 6:begin hsel = 32'b0000_0000_0000_0000_0000_0000_0100_0000; end
				4'd 7:begin hsel = 32'b0000_0000_0000_0000_0000_0000_1000_0000; end
				4'd 8:begin hsel = 32'b0000_0000_0000_0000_0000_0001_0000_0000; end
				4'd 9:begin hsel = 32'b0000_0000_0000_0000_0000_0010_0000_0000; end
				4'd10:begin hsel = 32'b0000_0000_0000_0000_0000_0100_0000_0000; end
				4'd11:begin hsel = 32'b0000_0000_0000_0000_0000_1000_0000_0000; end
	            4'd12:begin hsel = 32'b0000_0000_0000_0000_0001_0000_0000_0000; end
                4'd13:begin hsel = 32'b0000_0000_0000_0000_0010_0000_0000_0000; end
                4'd14:begin hsel = 32'b0000_0000_0000_0000_0100_0000_0000_0000; end
                4'd15:begin hsel = 32'b0000_0000_0000_0000_1000_0000_0000_0000; end
			//	5'd16:begin hsel = 32'b0000_0000_0000_0001_0000_0000_0000_0000; end
            //  5'd17:begin hsel = 32'b0000_0000_0000_0010_0000_0000_0000_0000; end
            //  5'd18:begin hsel = 32'b0000_0000_0000_0100_0000_0000_0000_0000; end
            //  5'd19:begin hsel = 32'b0000_0000_0000_1000_0000_0000_0000_0000; end
            //  5'd20:begin hsel = 32'b0000_0000_0001_0000_0000_0000_0000_0000; end
            //  5'd21:begin hsel = 32'b0000_0000_0010_0000_0000_0000_0000_0000; end
            //  5'd22:begin hsel = 32'b0000_0000_0100_0000_0000_0000_0000_0000; end
            //  5'd23:begin hsel = 32'b0000_0000_1000_0000_0000_0000_0000_0000; end
            //  5'd24:begin hsel = 32'b0000_0001_0000_0000_0000_0000_0000_0000; end
            //  5'd25:begin hsel = 32'b0000_0010_0000_0000_0000_0000_0000_0000; end
            //  5'd26:begin hsel = 32'b0000_0100_0000_0000_0000_0000_0000_0000; end
            //  5'd27:begin hsel = 32'b0000_1000_0000_0000_0000_0000_0000_0000; end
            //  5'd28:begin hsel = 32'b0001_0000_0000_0000_0000_0000_0000_0000; end
            //  5'd29:begin hsel = 32'b0010_0000_0000_0000_0000_0000_0000_0000; end
            //  5'd30:begin hsel = 32'b0100_0000_0000_0000_0000_0000_0000_0000; end
            //  5'd31:begin hsel = 32'b1000_0000_0000_0000_0000_0000_0000_0000; end
				default:;
			endcase
		end
	end
	
	assign S_HSELX = hsel[S_NUM-1:0];
	wire[16*DW-1:0] s_rdata = {{((16-S_NUM)*DW){1'b0}},S_HRDATA};
	wire[16* 1-1:0] s_resp  = {{(16-S_NUM){OKAY}},S_HRESP};
	wire[16* 1-1:0] s_ready = {{(16-S_NUM){1'b1}},S_HREADY_O};
	
	integer i;
	always@( * )begin
		case( S_HADDR[AW-1-:4] )
			4'd 0	:begin M_HRDATA = s_rdata[ 0*DW+:DW] ; M_HRESP = s_resp[ 0]; M_HREADY_I = s_ready[ 0];end
			4'd 1	:begin M_HRDATA = s_rdata[ 1*DW+:DW] ; M_HRESP = s_resp[ 1]; M_HREADY_I = s_ready[ 1];end
			4'd 2	:begin M_HRDATA = s_rdata[ 2*DW+:DW] ; M_HRESP = s_resp[ 2]; M_HREADY_I = s_ready[ 2];end
			4'd 3	:begin M_HRDATA = s_rdata[ 3*DW+:DW] ; M_HRESP = s_resp[ 3]; M_HREADY_I = s_ready[ 3];end
			4'd 4	:begin M_HRDATA = s_rdata[ 4*DW+:DW] ; M_HRESP = s_resp[ 4]; M_HREADY_I = s_ready[ 4];end
			4'd 5	:begin M_HRDATA = s_rdata[ 5*DW+:DW] ; M_HRESP = s_resp[ 5]; M_HREADY_I = s_ready[ 5];end
			4'd 6	:begin M_HRDATA = s_rdata[ 6*DW+:DW] ; M_HRESP = s_resp[ 6]; M_HREADY_I = s_ready[ 6];end
			4'd 7	:begin M_HRDATA = s_rdata[ 7*DW+:DW] ; M_HRESP = s_resp[ 7]; M_HREADY_I = s_ready[ 7];end
			4'd 8	:begin M_HRDATA = s_rdata[ 8*DW+:DW] ; M_HRESP = s_resp[ 8]; M_HREADY_I = s_ready[ 8];end
			4'd 9	:begin M_HRDATA = s_rdata[ 9*DW+:DW] ; M_HRESP = s_resp[ 9]; M_HREADY_I = s_ready[ 9];end
			4'd10	:begin M_HRDATA = s_rdata[10*DW+:DW] ; M_HRESP = s_resp[10]; M_HREADY_I = s_ready[10];end
			4'd11	:begin M_HRDATA = s_rdata[11*DW+:DW] ; M_HRESP = s_resp[11]; M_HREADY_I = s_ready[11];end
			4'd12	:begin M_HRDATA = s_rdata[12*DW+:DW] ; M_HRESP = s_resp[12]; M_HREADY_I = s_ready[12];end
			4'd13	:begin M_HRDATA = s_rdata[13*DW+:DW] ; M_HRESP = s_resp[13]; M_HREADY_I = s_ready[13];end
			4'd14	:begin M_HRDATA = s_rdata[14*DW+:DW] ; M_HRESP = s_resp[14]; M_HREADY_I = s_ready[14];end
			4'd15	:begin M_HRDATA = s_rdata[15*DW+:DW] ; M_HRESP = s_resp[15]; M_HREADY_I = s_ready[15];end
			default	:begin M_HRDATA = {DW{1'b0}}         ; M_HRESP = OKAY 	   ; M_HREADY_I = 1'b0		 ;end
		endcase
	end
	
	
	endmodule
