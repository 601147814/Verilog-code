////////////////////////////////////////////////////////////////////////////////////////////////
//  This module is suitable for FIFO data buffering in a single clock domain. Features:
//  Support variable data bit width.
//  Supports variable FIFO depth, limited to a power of 2 depth.
//  Support FIFO full state watermark setting.
//  The FIFO read interface is in FWFT (first word fall through) mode.	
////////////////////////////////////////////////////////////////////////////////////////////////
//----------------------------------------------------------------------------------------------------
//               __     ___     ___     ___     ___     ___     ___ 	___		___		___
//   clk_wr        |___|   |___|   |___|   |___|   |___|   |___|   |___|   |___|   |___|
//                      _______________ 
//   wr_en       ______|       |       |_____________________________________________________
//                      _______ ______
//   din         XXXXXX|___D0__|__D1__| XXX
//
//   full        _____________________________________________________________________________
//               __    __    __    __    __    __    __    __    __    __    __    __    __   
//   clk_rd        |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__
//               _______________________                    __________________________________
//   empty                     		    |__________________|        
//               ______________________________       ________________________________________
//   alempty                     		       |_____|
//                                              ___________
//   rd_en       ______________________________|     |     |__________________________________
//                                      	    ___________
//   dout        XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX|__D0_|_D1__|XXXXXXXXXXXXXXXXXXXXXXXXXXXXX
//
//----------------------------------------------------------------------------------------------------
	
	module fifo_async#(
		parameter DW 			= 8'd8		,
		parameter AW 			= 8'd8		,
		parameter FULL_HOLD 	= 8'd2		,
		parameter EMPTY_HOLD 	= 8'd2		
	)(
		input				clk_wr		,
		input				clk_rd		,
		input				rst			,
		input	[DW-1:0]	din			,
		input				wr_en		,
		input				rd_en		,
		output	[DW-1:0]	dout		,
		output	reg			empty		,
		output	reg			alempty		,
		output	reg			progempty	,
		output	reg			full		,
		output	reg			alfull		,
		output	reg			progfull	
	);
	
	initial begin
		if( AW==0 )begin $display("$s$d AW must be bigger than 0",`__FILE__,`__LINE__);$finish;end
	//	if( DW%8 != 0 )begin $display("$s$d DW is suggested to be a multiple of 8.",`__FILE__,`__LINE__);end
		if( FULL_HOLD > (2**AW - 1) )begin $display("$s$d FULL_HOLD must be smaller than %d.",`__FILE__,`__LINE__,(2**AW - 1));$finish;end
		if( EMPTY_HOLD > (2**AW - 1) )begin $display("$s$d EMPTY_HOLD must be smaller than %d.",`__FILE__,`__LINE__,(2**AW - 1));$finish;end
	end
	
//	always@( posedge clk_wr )begin
//		if( ( wr_en == 1'b1 ) && ( full == 1'b1 ) )begin			
//			$display("&s&d write data to full fifo ",`__FILE__,`__LINE__);		
//		end
//		else;
//	end
//	
//	always@( posedge clk_rd )begin
//		if(( rd_en == 1'b1 ) && ( empty == 1'b1 ))begin
//			$display("&s&d read data from empty fifo ",`__FILE__,`__LINE__);
//		end
//		else;
//	end

	localparam DEPTH = 2 ** AW;
	integer i;

	
	reg[(AW+1)-1:0]wr_p;
	reg[(AW+1)-1:0]rd_p;
	
	wire[(AW+1)-1:0]wr_p_gray;
	wire[(AW+1)-1:0]rd_p_gray;
	
	localparam N = 2;
	
	reg[(AW+1)*N-1:0]wr_p_gray_reg;
	reg[(AW+1)*N-1:0]rd_p_gray_reg;
	
	wire[(AW+1)-1:0]wr_p_temp;	// = wr_p_gray_reg[(AW+1)*N-1-:(AW+1)];
	wire[(AW+1)-1:0]rd_p_temp;	// = rd_p_gray_reg[(AW+1)*N-1-:(AW+1)];
	
	
	always@( posedge rst or posedge clk_rd )begin
		if( rst == 1'b1 )begin
			wr_p_gray_reg <= {((AW+1)*N){1'b0}};
		end
		else begin
			wr_p_gray_reg <= {wr_p_gray_reg[0+:((N-1)*(AW+1))],wr_p_gray};
		end
	end
	
	always@( posedge rst or posedge clk_wr )begin
		if( rst == 1'b1 )begin
	        rd_p_gray_reg <= {((AW+1)*N){1'b0}};
		end
		else begin
	        rd_p_gray_reg <= {rd_p_gray_reg[0+:((N-1)*(AW+1))],rd_p_gray};
		end
	end
	
	reg[DW-1:0]mem [DEPTH-1:0];	

	always@( posedge rst or posedge clk_wr )begin
		if( rst == 1'b1 )begin
			wr_p <= {(AW+1){1'b0}};
		end
		else if((full == 1'b0) && (wr_en == 1'b1))begin
			wr_p <= wr_p + 1'b1;
		end
		else;
	end
	
	always@( posedge rst or posedge clk_rd )begin
		if( rst == 1'b1 )begin
			rd_p <= {(AW+1){1'b0}};
		end
		else if((empty == 1'b0) && (rd_en == 1'b1))begin
			rd_p <= rd_p + 1'b1;
		end
		else;
	end
	
	always@( posedge rst or posedge clk_wr )begin
		if( rst == 1'b1 )begin
			for(i=0;i<DEPTH;i=i+1)begin
				mem[i] <= {DW{1'b0}};
			end
		end
		else if((full == 1'b0) && (wr_en == 1'b1))begin
			mem[wr_p[AW-1:0]] <= din;
		end
		else;
	end
	
	assign dout <= (empty == 1'b1)? {DW{1'b0}} : mem[rd_p[AW-1:0]];
	
	reg[AW:0]rd_space;
	reg[AW:0]wr_space;
	
	always@( posedge rst or posedge clk_rd )begin
		if( rst == 1'b1 )begin
			rd_space <= {(AW+1){1'b0}};
		end
		else if(( empty == 1'b0 ) && ( rd_en == 1'b1 ))begin
			rd_space <= wr_p_temp - rd_p - 1'b1;
		end
		else begin
			rd_space <= wr_p_temp - rd_p;
		end
	end	
	
	always@( posedge rst or posedge clk_wr )begin
		if( rst == 1'b1 )begin
			wr_space <= {1'b1,{AW{1'b0}}};
		end
		else if(( empty == 1'b0 ) && ( rd_en == 1'b1 ))begin
			wr_space <= rp_p_temp - wr_p - DEPTH - 1'b1;
		end
		else begin
			wr_space <= rp_p_temp - wr_p - DEPTH;
		end
	end
	
	always@( posedge rst or posedge clk_rd )begin
		if( rst == 1'b1 )begin
			empty <= 1'b1;
		end
		else if( wr_p_temp == rd_p )begin
			empty <= 1'b1;
		end
		else if( rd_space == 1'b1 )begin
			if( rd_en == 1'b1 )begin
				empty <= 1'b1;
			end
			else begin
				empty <= 1'b0;
			end
		end
		else begin
			empty <= 1'b0;
		end
	end

	always@( posedge rst or posedge clk_wr )begin
		if( rst == 1'b1 )begin
			full <= 1'b1;
		end
		else if( (wr_p[AW] != rd_p_temp[AW]) && (wr_p[0+:AW] == rd_p_temp[0+:AW]))begin
			full <= 1'b1;
		end
		else if( wr_space == 1'b1 )begin
			if( wr_en == 1'b1 )begin
				full <= 1'b1;
			end
			else begin
				full <= 1'b0;
			end
		end
		else begin
			full <= 1'b0;
		end
	end	
		
	always@( posedge rst or posedge clk_rd )begin
		if( rst == 1'b1 )begin
			alempty <= 1'b1;
		end
		else if( rd_space <= 2 )begin
			alempty <= 1'b1;
		end
		else if( rd_space == 2'd2 )begin
			if( rd_en == 1'b1 )begin
				alempty <= 1'b1;
			end
			else begin
				alempty <= 1'b0;
			end
		end
		else begin
			alempty <= 1'b0;
		end
	end

	always@( posedge rst or posedge clk_rd )begin
		if( rst == 1'b1 )begin
			progempty <= 1'b1;
		end
		else if( rd_space <= (EMPTY_HOLD + 1'b1) )begin
			progempty <= 1'b1;
		end
		else if( rd_space == (EMPTY_HOLD + 1'b1) )begin
			if( rd_en == 1'b1 )begin
				progempty <= 1'b1;
			end
			else begin
				progempty <= 1'b0;
			end
		end
		else begin
			progempty <= 1'b0;
		end
	end

	always@( posedge rst or posedge clk_wr )begin
		if( rst == 1'b1 )begin
			alfull <= 1'b1;
		end
		else if( wr_space < 2'd2 )begin
			alfull <= 1'b1;
		end
		else if( wr_space == 2'd2 )begin
			if( wr_en == 1'b1 )begin
				alfull <= 1'b1;
			end
			else begin
				alfull <= 1'b0;
			end
		end
		else begin
			alfull <= 1'b0;
		end
	end
	
	always@( posedge rst or posedge clk_wr )begin
		if( rst == 1'b1 )begin
			progfull <= 1'b1;
		end
		else if( wr_space < (FULL_HOLD + 1'b1) )begin
			progfull <= 1'b1;
		end
		else if( wr_space == (FULL_HOLD + 1'b1) )begin
			if( wr_en == 1'b1 )begin
				progfull <= 1'b1;
			end
			else begin
				progfull <= 1'b0;
			end
		end
		else begin
			progfull <= 1'b0;
		end
	end
		
	Binary2Gray #(
		.DW		( AW+1		)
	)b0_wr_p_gray(
		.din	( wr_p		),
		.dout	( wr_p_gray	)
    );
	
	Binary2Gray #(
		.DW		( AW+1		)
	)b1_rd_p_gray(
		.din	( rd_p		),
		.dout	( rd_p_gray	)
    );
	
	Gray2Binary #(
		.DW		( AW+1	)
	)g0_wr_p_binary(
		.din	( wr_p_gray_reg[(AW+1)*N-1-:(AW+1)]	),
		.dout	( wr_p_temp							)
	);
	
	Gray2Binary #(
		.DW		( AW+1	)
	)g0_rd_p_binary(
		.din	( rd_p_gray_reg[(AW+1)*N-1-:(AW+1)]	),
		.dout	( rd_p_temp							)
	);
	
	endmodule
