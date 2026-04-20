	
	
	module i2c_driver #(
		parameter DATA_WIDTH	= 8'd16				
		)(
		input							clk					,
		input							rst_n				,
		input		[DATA_WIDTH-1:0]  	i2c_wr_data			,
		input							i2c_start			,
		input		[7:0]				i2c_wr_frame_n		,
		input		[7:0] 				i2c_rd_frame_n		,
	
		input		[15:0]				cnt_clk_n			,
	
		output 	reg	[DATA_WIDTH-1:0]	i2c_rd_data			,
		output 	reg						i2c_rd_data_vld		,
		output 	reg 					i2c_end 			,
		output							i2c_busy			,
		output	reg						i2c_send_error		,
		output	reg						i2c_scl				,
		inout							i2c_sda
	);

	localparam	STP_IDLE			= 3'd00	;
	localparam	STP_START_CONF		= 3'd01	;
	localparam	STP_WRITE_BYTE		= 3'd02	;
	localparam	STP_READ_BYTE		= 3'd03	;
	localparam	STP_STOP_CONF		= 3'd04	;
	
	localparam	CNT_BIT_N			= 4'd9	;

	reg 	[DATA_WIDTH-1:0]  	rd_data_reg 	;
	reg		[15:0]				cnt_clk			;
	reg 	[3:0]				cnt_bit			;
	reg		[2:0]				wr_frame_cnt	;
	reg		[2:0]				rd_frame_cnt	;
	reg		[2:0]				state			;
	reg		[2:0]				state_n			;
	reg 						ack				;
	reg 						i2c_sda_reg		;
	reg		[DATA_WIDTH-1:0]  	i2c_wr_data_d	;
	reg		[7:0]				i2c_wr_frame_n_d;
	reg		[7:0] 				i2c_rd_frame_n_d;	
	reg		[15:0]				cnt_clk_n_d		;	
	wire 						sda_en 			;
	wire 						sda_in 			;
	
	always @(posedge clk) begin 
		if (rst_n == 1'b0) begin 
			i2c_wr_data_d <= 32'd0;
		end 
		else if (i2c_start == 1'b1) begin 
			i2c_wr_data_d <= i2c_wr_data;
		end 
		else begin 
			i2c_wr_data_d <= i2c_wr_data_d;
		end 
	end 
	
	always @(posedge clk) begin 
		if (rst_n == 1'b0) begin 
			i2c_wr_frame_n_d <= 8'd0; 		
			i2c_rd_frame_n_d <= 8'd0;
		end 
		else if (i2c_start == 1'b1) begin 
			i2c_wr_frame_n_d <= i2c_wr_frame_n; 		
			i2c_rd_frame_n_d <= i2c_rd_frame_n;
		end 
		else ;
	end
	
	always @(posedge clk) begin 
		if (rst_n == 1'b0) begin 
			cnt_clk_n_d <= 16'd0;
		end 
		else if (i2c_start == 1'b1) begin 
			cnt_clk_n_d <= cnt_clk_n;
		end 
		else;
	end
	
// state design 
	always @(posedge clk) begin 
		if (rst_n == 1'b0) begin 
			state <= STP_IDLE;
		end 
		else begin 
			state <= state_n;
		end 
	end 

	always @(*) begin  
		if (rst_n == 1'b0) begin 
			state_n <= STP_IDLE;
		end
		else begin 
			case (state)
				STP_IDLE:begin 
					if (i2c_start == 1'b1) begin 
						state_n <= STP_START_CONF;
					end 
					else begin 
						state_n <= STP_IDLE;
					end 
				end 
				STP_START_CONF:begin 
					if (cnt_clk == cnt_clk_n_d*2 - 1'b1) begin 
						state_n <= STP_WRITE_BYTE;
					end 
					else begin 
						state_n <= STP_START_CONF;
					end 
				end 
				STP_WRITE_BYTE:begin 		
					if ((cnt_bit == CNT_BIT_N - 1'b1) && (cnt_clk == cnt_clk_n_d - 1'b1) && (wr_frame_cnt == i2c_wr_frame_n_d - 1'b1)) begin 
						if (i2c_rd_frame_n_d != 8'b0) begin 
							state_n <= STP_READ_BYTE;
						end 
						else begin 
							state_n <= STP_STOP_CONF;
						end 
					end 
					else begin 
						state_n <= STP_WRITE_BYTE;
					end 
				end 
				STP_READ_BYTE:begin 
					if ((cnt_bit == CNT_BIT_N - 1'b1) && (cnt_clk == cnt_clk_n_d - 1'b1) && (rd_frame_cnt == i2c_rd_frame_n_d - 1'b1)) begin 
						state_n <= STP_STOP_CONF;
					end 
					else begin 
						state_n <= STP_READ_BYTE;
					end
				end 
				STP_STOP_CONF:begin 
					if (cnt_clk == cnt_clk_n_d*2 - 1'b1) begin 
						state_n <= STP_IDLE;
					end 
					else begin 
						state_n <= STP_STOP_CONF;
					end
				end 
				default:begin 
					state_n <= STP_IDLE;
				end
			endcase 
		end
	end
	
	always @(posedge clk) begin 
		if (rst_n == 1'b0) begin 
			cnt_clk <= 1'd0;
		end
		else if ((state == STP_STOP_CONF) || (state == STP_START_CONF)) begin 
			if (cnt_clk == cnt_clk_n_d*2 - 1'b1) begin 
				cnt_clk <= 1'd0;
			end 
			else begin 
				cnt_clk <= cnt_clk + 1'b1;
			end 
		end  
		else if (state != STP_IDLE) begin 
			if (cnt_clk == cnt_clk_n_d - 1'b1) begin 
				cnt_clk <= 1'd0;
			end
			else begin 
				cnt_clk <= cnt_clk + 1'b1;
			end 
		end 
		else begin 
			cnt_clk <= 1'd0;
		end 
	end 
	
	always @(posedge clk) begin 
		if (rst_n == 1'b0) begin 
			cnt_bit <= 4'd0;
		end 
		else if ((state == STP_WRITE_BYTE) || (state == STP_READ_BYTE)) begin 
			if ((cnt_bit == CNT_BIT_N - 1'b1) && (cnt_clk == cnt_clk_n_d - 1'b1)) begin 
				cnt_bit <= 4'd0;
			end
			else if (cnt_clk == cnt_clk_n_d - 1'b1) begin 
				cnt_bit <= cnt_bit + 4'd1;	
			end 
			else begin 
				cnt_bit <= cnt_bit;
			end 
		end 
		else begin 
			cnt_bit <= 4'd0;
		end 
	end 
	
	always @(posedge clk) begin 
		if (rst_n == 1'b0) begin 
			i2c_scl <= 1'b1;
		end 
		else begin 
			case (state)
				STP_START_CONF:begin 
					if (cnt_clk >= cnt_clk_n_d*3/2 - 1'b1) begin 
						i2c_scl <= 1'b0;
					end 
					else begin 
						i2c_scl <= 1'b1;
					end 
				end 
				STP_WRITE_BYTE,STP_READ_BYTE:begin 
					if (cnt_clk == cnt_clk_n_d/2 - 1'b1 ) begin 
						i2c_scl <= 1'b1; 
					end
					else if (cnt_clk == cnt_clk_n_d - 1'b1) begin 
						i2c_scl <= 1'b0;
					end 
					else begin 
						i2c_scl <= i2c_scl;
					end 
				end 
				STP_STOP_CONF:begin 
					if (cnt_clk <= cnt_clk_n_d/2 - 1'b1) begin 
						i2c_scl <= 1'b0;
					end 
					else begin 
						i2c_scl <= 1'b1;
					end 
				end 
				default:begin 
					i2c_scl <= 1'b1;
				end 
			endcase
		end 
	end
	
	wire [3-1:0] wr_byte_n = i2c_wr_frame_n_d - wr_frame_cnt - 1'b1;
	
	always @( * ) begin 
		if (rst_n == 1'b0) begin 
			i2c_sda_reg <= 1'b1;
		end 
		else if (state == STP_START_CONF) begin 
			if (cnt_clk >= cnt_clk_n_d/2 - 1'b1) begin 
				i2c_sda_reg <= 1'b0;
			end 
			else begin 
				i2c_sda_reg <= 1'b1;
			end
		end 
		else if (state == STP_WRITE_BYTE) begin 
			case ({wr_byte_n,cnt_bit}) 
				{3'd0,4'd8}:begin i2c_sda_reg <= 1'b1				; end  
				{3'd0,4'd7}:begin i2c_sda_reg <= i2c_wr_data_d[0] 	; end
				{3'd0,4'd6}:begin i2c_sda_reg <= i2c_wr_data_d[1] 	; end
				{3'd0,4'd5}:begin i2c_sda_reg <= i2c_wr_data_d[2] 	; end
				{3'd0,4'd4}:begin i2c_sda_reg <= i2c_wr_data_d[3] 	; end
				{3'd0,4'd3}:begin i2c_sda_reg <= i2c_wr_data_d[4] 	; end
				{3'd0,4'd2}:begin i2c_sda_reg <= i2c_wr_data_d[5] 	; end
				{3'd0,4'd1}:begin i2c_sda_reg <= i2c_wr_data_d[6] 	; end
				{3'd0,4'd0}:begin i2c_sda_reg <= i2c_wr_data_d[7] 	; end
				{3'd1,4'd8}:begin i2c_sda_reg <= 1'b1				; end                   
				{3'd1,4'd7}:begin i2c_sda_reg <= i2c_wr_data_d[8] 	; end
				{3'd1,4'd6}:begin i2c_sda_reg <= i2c_wr_data_d[9] 	; end
				{3'd1,4'd5}:begin i2c_sda_reg <= i2c_wr_data_d[10]	; end
				{3'd1,4'd4}:begin i2c_sda_reg <= i2c_wr_data_d[11]	; end
				{3'd1,4'd3}:begin i2c_sda_reg <= i2c_wr_data_d[12]	; end
				{3'd1,4'd2}:begin i2c_sda_reg <= i2c_wr_data_d[13]	; end
				{3'd1,4'd1}:begin i2c_sda_reg <= i2c_wr_data_d[14]	; end
				{3'd1,4'd0}:begin i2c_sda_reg <= i2c_wr_data_d[15]	; end
				{3'd2,4'd8}:begin i2c_sda_reg <= 1'b1				; end
				{3'd2,4'd7}:begin i2c_sda_reg <= i2c_wr_data_d[16]	; end
				{3'd2,4'd6}:begin i2c_sda_reg <= i2c_wr_data_d[17]	; end
				{3'd2,4'd5}:begin i2c_sda_reg <= i2c_wr_data_d[18]	; end
				{3'd2,4'd4}:begin i2c_sda_reg <= i2c_wr_data_d[19]	; end
				{3'd2,4'd3}:begin i2c_sda_reg <= i2c_wr_data_d[20]	; end
				{3'd2,4'd2}:begin i2c_sda_reg <= i2c_wr_data_d[21]	; end
				{3'd2,4'd1}:begin i2c_sda_reg <= i2c_wr_data_d[22]	; end
				{3'd2,4'd0}:begin i2c_sda_reg <= i2c_wr_data_d[23]	; end
				{3'd3,4'd8}:begin i2c_sda_reg <= 1'b1				; end
				{3'd3,4'd7}:begin i2c_sda_reg <= i2c_wr_data_d[24]	; end
				{3'd3,4'd6}:begin i2c_sda_reg <= i2c_wr_data_d[25]	; end
				{3'd3,4'd5}:begin i2c_sda_reg <= i2c_wr_data_d[26]	; end
				{3'd3,4'd4}:begin i2c_sda_reg <= i2c_wr_data_d[27]	; end
				{3'd3,4'd3}:begin i2c_sda_reg <= i2c_wr_data_d[28]	; end
				{3'd3,4'd2}:begin i2c_sda_reg <= i2c_wr_data_d[29]	; end
				{3'd3,4'd1}:begin i2c_sda_reg <= i2c_wr_data_d[30]	; end
				{3'd3,4'd0}:begin i2c_sda_reg <= i2c_wr_data_d[31]	; end		
				default: begin 
					i2c_sda_reg <= 1'b0	;
				end 
			endcase
		end 
		else if (state == STP_READ_BYTE) begin 
			if ((rd_frame_cnt == i2c_rd_frame_n_d - 1'b1) && (cnt_bit == CNT_BIT_N - 1'b1)) begin 
				i2c_sda_reg <= 1'b1	;
			end 
			else begin 
				i2c_sda_reg <= 1'b0	;
			end 			
		end 
		else if (state == STP_STOP_CONF) begin 
			if (cnt_clk <= cnt_clk_n_d*3/2 - 1'b1) begin 
				i2c_sda_reg <= 1'b0;
			end 
			else begin 
				i2c_sda_reg <= 1'b1;
			end 	
		end 
		else begin 
			i2c_sda_reg <= 1'b1;
		end 
	end 
	
	wire [3-1:0] rd_byte_n = i2c_rd_frame_n_d - rd_frame_cnt - 1'b1;
	
	always @(posedge clk) begin 
		if (rst_n == 1'b0) begin 
			rd_data_reg <= 32'd0;
		end 
		else if (state == STP_START_CONF) begin 
			rd_data_reg <= 32'd0;
		end 
		else if ((state == STP_READ_BYTE) && (cnt_clk == cnt_clk_n_d/2 - 1'b1)) begin
			case ({rd_byte_n,cnt_bit})
				{3'd0,4'd7}:begin rd_data_reg[0]  <= sda_in; end
				{3'd0,4'd6}:begin rd_data_reg[1]  <= sda_in; end
				{3'd0,4'd5}:begin rd_data_reg[2]  <= sda_in; end
				{3'd0,4'd4}:begin rd_data_reg[3]  <= sda_in; end
				{3'd0,4'd3}:begin rd_data_reg[4]  <= sda_in; end
				{3'd0,4'd2}:begin rd_data_reg[5]  <= sda_in; end
				{3'd0,4'd1}:begin rd_data_reg[6]  <= sda_in; end
				{3'd0,4'd0}:begin rd_data_reg[7]  <= sda_in; end

				{3'd1,4'd7}:begin rd_data_reg[8]  <= sda_in; end  
				{3'd1,4'd6}:begin rd_data_reg[9]  <= sda_in; end  
				{3'd1,4'd5}:begin rd_data_reg[10] <= sda_in; end  
				{3'd1,4'd4}:begin rd_data_reg[11] <= sda_in; end  
				{3'd1,4'd3}:begin rd_data_reg[12] <= sda_in; end  
				{3'd1,4'd2}:begin rd_data_reg[13] <= sda_in; end  
				{3'd1,4'd1}:begin rd_data_reg[14] <= sda_in; end  
				{3'd1,4'd0}:begin rd_data_reg[15] <= sda_in; end  

				{3'd2,4'd7}:begin rd_data_reg[16] <= sda_in; end  
				{3'd2,4'd6}:begin rd_data_reg[17] <= sda_in; end  
				{3'd2,4'd5}:begin rd_data_reg[18] <= sda_in; end  
				{3'd2,4'd4}:begin rd_data_reg[19] <= sda_in; end  
				{3'd2,4'd3}:begin rd_data_reg[20] <= sda_in; end  
				{3'd2,4'd2}:begin rd_data_reg[21] <= sda_in; end  
				{3'd2,4'd1}:begin rd_data_reg[22] <= sda_in; end  
				{3'd2,4'd0}:begin rd_data_reg[23] <= sda_in; end  

				{3'd3,4'd7}:begin rd_data_reg[24] <= sda_in; end  
				{3'd3,4'd6}:begin rd_data_reg[25] <= sda_in; end  
				{3'd3,4'd5}:begin rd_data_reg[26] <= sda_in; end  
				{3'd3,4'd4}:begin rd_data_reg[27] <= sda_in; end  
				{3'd3,4'd3}:begin rd_data_reg[28] <= sda_in; end  
				{3'd3,4'd2}:begin rd_data_reg[29] <= sda_in; end  
				{3'd3,4'd1}:begin rd_data_reg[30] <= sda_in; end  
				{3'd3,4'd0}:begin rd_data_reg[31] <= sda_in; end  
				default:begin 
					rd_data_reg <= rd_data_reg;
				end 
			endcase
		end 
		else begin 
			rd_data_reg <= rd_data_reg;
		end 
	end 	
		
	always @(posedge clk) begin      
		if (rst_n == 1'b0) begin 
			rd_frame_cnt <= 3'd0;
		end 
		else if (i2c_start == 1'b1)begin 
			rd_frame_cnt <= 3'd0;
		end  
		else if ((state == STP_READ_BYTE) && (cnt_bit == CNT_BIT_N - 1'b1) && (cnt_clk == cnt_clk_n_d - 1'b1)) begin 
			rd_frame_cnt <= rd_frame_cnt + 1'b1;
		end 
		else begin 
			rd_frame_cnt <= rd_frame_cnt;
		end 
	end 
	
	always @(posedge clk) begin 
		if (rst_n == 1'b0) begin 
			wr_frame_cnt <= 3'd0;
		end 
		else if (i2c_start == 1'b1) begin 
			wr_frame_cnt <= 3'd0;
		end 
		else if ((state == STP_WRITE_BYTE) && (cnt_bit == CNT_BIT_N - 1'b1) && (cnt_clk == cnt_clk_n_d - 1'b1)) begin 
			wr_frame_cnt <= wr_frame_cnt + 1'b1;
		end
		else begin 
			wr_frame_cnt <= wr_frame_cnt;
		end 
	end 
	 	
	always @(posedge clk) begin 
		if (rst_n == 1'b0) begin 
			ack <= 1'b1;
		end 
		else begin 
			case (state) 
				STP_WRITE_BYTE:begin 
					if (cnt_bit == CNT_BIT_N - 1'b1) begin 
						ack <= sda_in;
					end
					else begin 
						ack <= ack;
					end 
				end 
				default:begin 
					ack <= 1'b1;
				end 
			endcase
		end 
	end	 
	
	always @(posedge clk) begin 
		if (rst_n == 1'b0) begin 
			i2c_send_error <= 1'b0;
		end 
		else if (i2c_start == 1'b1) begin 
			i2c_send_error <= 1'b0;
		end
		else if ((state == STP_WRITE_BYTE) && (cnt_bit == CNT_BIT_N - 1'b1) && (cnt_clk == cnt_clk_n_d/2)) begin 
			if (ack != 1'b0) begin 
				i2c_send_error <= 1'b1;
			end 
			else begin 
				i2c_send_error <= 1'b0;
			end 
		end 
		else begin 
			i2c_send_error <= i2c_send_error;
		end 
	end
	 
	always @(posedge clk) begin 
		if (rst_n == 1'b0) begin 
			i2c_rd_data <= 16'd0;
		end 
		else if (i2c_start == 1'b1) begin 
			i2c_rd_data <= 16'd0;
		end 
		else if (i2c_end == 1'b1) begin 
			i2c_rd_data <= rd_data_reg;
		end 
		else begin 
			i2c_rd_data <= i2c_rd_data;
		end 
	end
	
	
	always@(posedge clk) begin 
		if(rst_n == 1'b0) begin 
			i2c_rd_data_vld <= 1'b0;
		end
		else if((state == STP_STOP_CONF) && (cnt_clk == cnt_clk_n_d - 1'b1) && (i2c_rd_frame_n_d > 8'd0)) begin 
			i2c_rd_data_vld <= 1'b1;
		end
		else begin 
			i2c_rd_data_vld <= 1'b0;
		end
	end
	
	
	
	always@(posedge clk) begin 
		if(rst_n == 1'b0) begin 
			i2c_end <= 1'b0;
		end
		else if((state == STP_STOP_CONF) && (cnt_clk == cnt_clk_n_d - 1'b1)) begin 
			i2c_end <= 1'b1;
		end
		else begin 
			i2c_end <= 1'b0;
		end
	end
	
	assign i2c_busy = ( state == STP_IDLE )? 1'b0 : 1'b1;

	assign sda_en = (((state == STP_WRITE_BYTE) && (cnt_bit == CNT_BIT_N - 1'b1)) || ((state == STP_READ_BYTE) && (cnt_bit != CNT_BIT_N - 1'b1))) ? 1'b0 : 1'b1;
	
	assign sda_in = i2c_sda;
	
	assign i2c_sda = (sda_en == 1'b1) ? i2c_sda_reg : 1'bz;	
	
	localparam ILA_AFE_MODULE = 0;
	
	generate if( ILA_AFE_MODULE == 1'b1 )begin:ILA	
		
		ila_i2c_driver u_ila_i2c_driver (
			.clk	( clk				), // input wire clk
			.probe0 ( i2c_start			), // input wire [0:0]  probe0  
			.probe1 ( i2c_busy			), // input wire [0:0]  probe1 
			.probe2 ( i2c_send_error	), // input wire [0:0]  probe2 
			.probe3 ( i2c_scl			), // input wire [0:0]  probe3 
			.probe4 ( i2c_end			), // input wire [0:0]  probe4 i2c_sda
			.probe5 ( ack				), // input wire [0:0]  probe5 
			.probe6 ( i2c_sda_reg		), // input wire [0:0]  probe6 
			.probe7 ( sda_en 			), // input wire [0:0]  probe7 
			.probe8 ( sda_in 			), // input wire [0:0]  probe8 
			.probe9 ( wr_frame_cnt		), // input wire [2:0]  probe9 
			.probe10( rd_frame_cnt		), // input wire [2:0]  probe10 
			.probe11( state				), // input wire [2:0]  probe11 
			.probe12( cnt_bit			), // input wire [3:0]  probe12 
			.probe13( i2c_wr_frame_n_d	), // input wire [7:0]  probe13 
			.probe14( i2c_rd_frame_n_d	), // input wire [7:0]  probe14 
			.probe15( cnt_clk_n_d		), // input wire [15:0]  probe15 
			.probe16( cnt_clk			), // input wire [15:0]  probe16 
			.probe17( i2c_wr_data_d		), // input wire [31:0]  probe17 
			.probe18( i2c_rd_data		), // input wire [31:0]  probe18 
			.probe19( wr_byte_n			), // input wire [2:0]  probe19 
			.probe20( rd_byte_n			)  // input wire [2:0]  probe20
		);
		
	end
	endgenerate

endmodule 
