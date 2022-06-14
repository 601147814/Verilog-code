	/////////////////////////////////////////////////////
	//	Gray code to binary number 
	//	格雷码转2进制数
	//	quote ex:	
	//	Gray2Binary #(
	//		.DW		( 4'd4	)
	//	)g0(
	//		.din	(		),
	//		.dout	(		)
	//	);
	/////////////////////////////////////////////////////
	module Gray2Binary#(
		parameter DW = 4'd4,
	)(
		input  [DW-1:0] din	,
		output [DW-1:0] dout
	); 
	
		assign dout[DW-1] = din[DW-1];
	
		integer i;	
		generate for(i=DW-2;i>=0;i=i-1)	begin loop		
			assign dout[i] = dout[i+1] ^ din[i];
		end
	
	endmodule
