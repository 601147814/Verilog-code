  	/////////////////////////////////////////////////////
	//	Binary number to gray code
	//	2进制数转格雷码
	//	quote E.g:	
	//
	//	Binary2Gray #(
	//		.DW		( 4		)
	//	)g0(
	//		.din	( 		),
	//		.dout	( 		)
	//	);
	/////////////////////////////////////////////////////
	module Binary2Gray#(
		parameter DW = 4'd4,
	)(
		input  [DW-1:0] din	,
		output [DW-1:0] dout
	); 
		
	assign dout = din ^ {1'b0,din[DW-1:1]};
	
	//	assign dout[DW-1] = din[DW-1] ^ {1'b0,din[DW-1:1]};
	//
	//	integer i;	
	//	generate for(i=0;i<=DW-1;i=i+1)	begin loop		
	//		assign dout[i] = din[i+1] ^ din[i];
	//	end
	
	endmodule
