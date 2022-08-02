	module reset_and_clock(
		input 		rst_in			,

		input		clk_122m88_p	,
		input		clk_122m88_n	,
		
		input		clk_100m_p 		,
		input		clk_100m_n 		,
		
		output		clk_100m		,
		output		clk_122m88		,
		output		clk_245m76		,
		
		output 		rst_100m		,
		output 		rst_122m88		,
		output 		rst_245m76		,
		
		output 		rst_n_100m		,
		output 		rst_n_122m88	,
		output 		rst_n_245m76		
    );

	wire clk_100m_locked	;
	wire clk_122m88_locked	;	
	wire clk_122m88_o		;
	
	IBUFDS #(
		.DIFF_TERM		( "TRUE"			),	// Differential Termination
		.IBUF_LOW_PWR	( "TRUE"			),	// Low power="TRUE", Highest performance="FALSE" 
		.IOSTANDARD		( "DEFAULT"			)	// Specify the input I/O standard
	) IBUFDS_u0 (
		.O				( clk_122m88_o		),	// Buffer output
		.I				( clk_122m88_p		),	// Diff_p buffer input (connect directly to top-level port)
		.IB				( clk_122m88_n		) 	// Diff_n buffer input (connect directly to top-level port)
	);

	clk_wiz_2 clk_wiz_122m88(
		.clk_in1 		( clk_122m88_o		),
		.clk_out1 		( clk_245m76		),
		.clk_out2 		( clk_122m88		),
		.locked 		( clk_122m88_locked	)		
	);
	
	clk_wiz_0 clk_wiz_100m(
		.clk_in1_p 		( clk_100m_p		),
		.clk_in1_n 		( clk_100m_n		),
		.clk_out1 		( clk_100m			),
		.locked 		( clk_100m_locked	)		
	);
	
	
	rst_ctl ins_rst_100m(
		.rst_in			( rst_in			),
		.clk			( clk_100m			),
		.clk_locked		( clk_100m_locked	),
		.rst			( rst_100m			),
		.rst_n			( rst_n_100m		)
	);
	
	rst_ctl ins_rst_122m88(
		.rst_in			( rst_in			),
		.clk			( clk_122m88		),
		.clk_locked		( clk_122m88_locked	),
		.rst			( rst_122m88		),
		.rst_n			( rst_n_122m88		)
	);
	
	rst_ctl ins_rst_245m76(
		.rst_in			( rst_in			),
		.clk			( clk_245m76		),
		.clk_locked		( clk_122m88_locked	),
		.rst			( rst_245m76		),
		.rst_n			( rst_n_245m76		)
	);
	
	`ifdef CLK_122M_MODULE
	
		/* ila_clk_122m ins_ila_clk_122m(
			.clk		( clk_245m76		),
			.probe0		( clk_122m88_locked	)
		); */
		
	`endif
	
	endmodule

	module rst_ctl(
		input		rst_in			,
		input		clk				,
		input		clk_locked		,
		output reg	rst=1'b1		,
		output reg	rst_n=1'b0			
	);
	
	reg[16-1:0]	rst_reg				;	
	reg[16-1:0] cnt 		= 16'd0	;
	wire reset;

	`ifdef RESET_N_MODULE	
		assign reset = ( rst_reg == {16{1'b0}} )? 1'b0 :1'b1;	
	`else		
		assign reset = ( rst_reg == {16{1'b1}} )? 1'b1 :1'b0;	
	`endif
	
	always@( posedge clk )begin
		rst_reg <= {rst_reg[0+:15],rst_in};
	end
	
	always@(posedge clk or posedge reset)begin
		`ifdef RESET_N_MODULE
		if( reset == 1'b0)begin
		`else
		if( reset == 1'b1)begin
		`endif
			cnt <= 16'd0;
		end
		else if((cnt != 16'hFFFF) && (clk_locked == 1'b1))begin
			cnt <= cnt + 1'd1;
		end
		else begin
			cnt <= cnt;
		end
	end
	
	always@( posedge clk )begin
		if( cnt < 16'h0AFF )begin
			rst 	<= 1'b1;
			rst_n 	<= 1'b0;
		end		
		else begin
			rst 	<= 1'b0;
			rst_n 	<= 1'b1;
		end
	end	
	
	endmodule
