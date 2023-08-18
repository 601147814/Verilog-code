	///////////////////////////////////////////////////
	// 
	// sync_dff is for data register to filp folp in clock regin
	//
	//	sync_dff#(
	//		.WIDTH	( 1		),
	//		.DFF 	( 2		),
	//		.LOGIC	( 2		)
	//	)(
	//		.rst	(		),
	//		.clk	(		),
	//		.din	(		),
	//		.dout   (		)
	//	)
	//
	//////////////////////////////////////////////////
	
	module sync_dff#(
		parameter WIDTH = 1	,
		parameter DFF 	= 2	,
		parameter LOGIC = 2		//0: or; 1: and; 2: nothing
	)(
		input 					rst		,
		input 					clk		,
		input	[WIDTH-1:0] 	din		,
		output	[WIDTH-1:0]		dout
	);
	
	reg[WIDTH*DFF-1:0] data_reg;
	
	always@(posedge clk or posedge rst)begin
		if(rst == 1'b1)begin 
			data_reg <= {(WIDTH*DFF)1'b0};
		end
		else begin	
			data_reg <= {data_reg[0+:WIDTH*(DFF-1)],din};
		end
	end
	
	generate if(WIDTH == 1)begin: bit1_op
		generate if(LOGIC == 0)begin: or_op
			assign	dout = |data_reg;
		end
		else if (LOGIC == 1)begin: and_op
			assign	dout = &data_reg;
		end
		else if(LOGIC == 2)begin: no_op
			assign	dout = data_reg[DFF-1];
		end
	end
	else if(WIDTH > 1)begin: 
		assign dout = data_reg[WIDTH*DFF-1-:WIDTH];
	end
	endgenerate	
	
	endmodule
