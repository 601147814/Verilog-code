module data_delay#(
		parameter DW 	= 8'd8		,
		parameter N 	= 8'd8		
	)(
		input				clk		,
		input				rst		,
		input[DW-1:0]		din		,
		output[DW-1:0]		dout	
	);

	generate if( N == 0 )begin:No_Delay

		assign dout = din;

	end
	else begin:Delay


		reg[N*DW-1:0]data_reg;

		always@(posedge clk or posedge rst )begin
			if( rst == 1'b1 )begin
				data_reg <= {(N*DW){1'b1}};
			end
			else begin
				data_reg <= {data_reg[0+:((N-1)*DW)],din};
			end
		end

		assign dout = data_reg[N*DW-1-:DW];

	end

	endmodule
