	module slave_spi#(
		parameter AHOL 			= 1'b1			,	// 
		parameter ADDR_WIDTH	= 8'd16			,	// 
		parameter DATA_WIDTH	= 8'd16			,	// 
		parameter WRITE 		= 1'b0			,
		parameter READ 			= 1'b1				
	)(	
		//   				
		input 							CS_N		,
		input 							SCLK		,
		`ifdef SPI_3LINE						
		inout  							SDIO		,
		`else			
		input 							SDI			,	
		output 	reg						SDO			,
		`endif	
		input 							clk			,
		input 							rst			,
		//	
		output reg						cs			,
		output reg[ADDR_WIDTH-1:0]		addr		,
		output reg						wr_en		,
		output reg						rd_en		,
		output reg[DATA_WIDTH-1:0]		data_wr		,
		input	  [DATA_WIDTH-1:0]		data_rd		,
		input	  						rdy
	);
	
	reg     			operation;
	reg[DATA_WIDTH-1:0] data_rd_reg;
	reg[DATA_WIDTH-1:0] data_wr_reg;	
	reg[ADDR_WIDTH-1:0] addr_reg;	
	

	reg[7:0]cnt_bit;	// 

	reg[1:0]sclk_reg;
	
	always@(posedge clk or posedge rst)begin
		if( rst == 1'b1 )	begin sclk_reg <= 2'd0;		 			end
		else				begin sclk_reg <= {sclk_reg[0],SCLK} ; 	end
	end
	
	wire sclk_nege = sclk_reg[0] & ~sclk_reg[1];	//sclk 
	wire sclk_pose = ~sclk_reg[0] & sclk_reg[1];	//sclk 
	
	wire update = (AHOL == 1'b0)? sclk_nege : sclk_pose;	
	wire sample = (AHOL == 1'b1)? sclk_nege : sclk_pose;		
	

	always@( posedge clk or posedge rst)begin
		if( rst == 1'b1 )begin
			cs <= 1'b0;
		end
		else if( CS_N == 1'b1)begin
			cs <= 1'b0;
		end
		else if( (sample == 1'b1) && (cnt_bit == ADDR_WIDTH + DATA_WIDTH ) && (operation == WRITE))begin
			cs <= 1'b1;
		end
		else if( (sample == 1'b1) && ( cnt_bit == ADDR_WIDTH )&& (operation == READ))begin
			cs <= 1'b1;
		end
		else if( rdy == 1'b1 )begin
			cs <= 1'b0;
		end
		else begin
		
		end
	end	

	always@( posedge clk or posedge rst)begin
		if( rst == 1'b1 )begin
			cnt_bit <= 8'b0;
		end
		else if( CS_N == 1'b0 )begin
			if(cnt_bit == 8'd0)begin
				if( update == 1'b1)begin
					cnt_bit <= cnt_bit + 1'b1;
				end
				else if(sample == 1'b1)begin
					cnt_bit <= cnt_bit + 1'b1;
				end
				else begin
				end
			end
			else begin
				if( update == 1'b1)begin
					cnt_bit <= cnt_bit + 1'b1;
				end
				else begin
				end
			end
		end
		else begin
			cnt_bit <= 8'b0;
		end
	end

	always@( posedge clk or posedge rst)begin
		if( rst == 1'b1 )begin
			rd_en <= 1'b0;
		end
		else if( CS_N == 1'b1)begin
			rd_en <= 1'b0;
		end
		else if( (sample == 1'b1) && (cnt_bit == ADDR_WIDTH ) && (operation == READ))begin
			rd_en <= 1'b1;
		end
		else if( rdy == 1'b1 )begin
			rd_en <= 1'b0;
		end
		else begin
		
		end
	end

	always@( posedge clk or posedge rst)begin
		if( rst == 1'b1 )begin
			wr_en <= 1'b0;
		end
		else if( CS_N == 1'b1)begin
			wr_en <= 1'b0;
		end
		else if( (sample == 1'b1) && ( cnt_bit == ADDR_WIDTH + DATA_WIDTH )&& (operation == WRITE))begin
			wr_en <= 1'b1;
		end
		else if( rdy == 1'b1 )begin
			wr_en <= 1'b0;
		end
		else begin
		
		end
	end
	
	always@( posedge clk or posedge rst)begin
		if( rst == 1'b1 )begin
			data_rd_reg <= {DATA_WIDTH{1'b0}};
		end
		else if ( (cs == 1'b1) && (rdy == 1'b1) && (rd_en == 1'b1) )begin
			data_rd_reg <= data_rd;
		end
		else if( (cnt_bit > ADDR_WIDTH) && (update == 1'b1 ))begin
			data_rd_reg <= {data_rd_reg[DATA_WIDTH-2:0],1'b1};
		end
		else ;
	end
	
	always@( posedge clk or posedge rst)begin
		if( rst == 1'b1 )begin
			operation <= 1'b0;
		end
		else if( ( update == 1'b1 ) && ( cnt_bit == 8'd1) && (CS_N == 1'b0) )begin
			operation <= addr_reg[0];
		end
		else if (CS_N == 1'b1)  begin
			operation <= READ;
		end
		else begin
		end
	end
	
	`ifdef SPI_3LINE	
		
		always@( posedge clk or posedge rst)begin
			if( rst == 1'b1 )begin
				addr <= {ADDR_WIDTH{1'b0}};
			end
			else if( (cnt_bit==ADDR_WIDTH) && (sample == 1'b1))begin
				addr <= {addr_reg[ADDR_WIDTH-2:0],SDIO};
			end
			else begin
			end
		end
		
		reg	SDIO_out		;		
		
		always@( posedge clk or posedge rst)begin
			if( rst==1'b1 )begin 
				SDIO_out <= 1'b0;
			end
			else if((cnt_bit > ADDR_WIDTH)&& (operation == READ))begin
				SDIO_out <=  data_rd_reg[DATA_WIDTH-1];	
			end
			else if(CS_N ==1'b1)begin
				SDIO_out <= 1'b0;
			end
			else begin
			end
		end
	
		assign SDIO = ((cnt_bit > ADDR_WIDTH)&& (operation == READ)&& (CS_N == 1'b0))? SDIO_out :1'hz;
	
		always@( posedge clk or posedge rst)begin
			if( rst==1'b1 )begin
				addr_reg <={ADDR_WIDTH{1'b0}};
			end
			else if((CS_N == 1'b0)&& (cnt_bit <= ADDR_WIDTH )&& (sample == 1'b1))begin
				addr_reg <= {addr_reg[ADDR_WIDTH-2:0],SDIO};	
			end
			else if(CS_N == 1'b1)begin
				addr_reg <={ADDR_WIDTH{1'b0}};
			end
			else begin
			end
		end
	
		always@(posedge clk or posedge rst)begin
			if(rst==1'b1)begin 
				data_wr_reg <= {DATA_WIDTH{1'b0}};
			end
			else if( (sample==1'b1) && (cnt_bit > ADDR_WIDTH ) && (CS_N == 1'b0))begin
				data_wr_reg <= {data_wr_reg[DATA_WIDTH-2:0],SDIO};
			end
			else begin
			end
		end
		
		always@( posedge clk or posedge rst)begin
			if( rst == 1'b1 )begin
				data_wr <= {DATA_WIDTH{1'b0}};
			end
			else if( (cnt_bit == ADDR_WIDTH + DATA_WIDTH) && (operation == WRITE) && (sample == 1'b1))begin
				data_wr <= {data_wr_reg[DATA_WIDTH-2:0],SDIO};
			end
			else begin
			
			end
		end
	
	`else	
		
		always@( posedge clk or posedge rst)begin
			if( rst == 1'b1 )begin
				addr <= {ADDR_WIDTH{1'b0}};
			end
			else if( (cnt_bit==ADDR_WIDTH) && (sample == 1'b1))begin
				addr <= {addr_reg[ADDR_WIDTH-2:0],SDI};
			end
			else begin
			end
		end
	
		always@( posedge clk or posedge rst)begin
			if( rst==1'b1 )begin 
				SDO <= 1'b0;
			end
			else if((cnt_bit > ADDR_WIDTH)&& (operation == READ)&& (CS_N == 1'b0))begin
				SDO <=  data_rd_reg[DATA_WIDTH-1];	
			end
			else if(CS_N ==1'b1)begin
				SDO <= 1'b0;
			end
			else begin
			end
		end
		
		always@( posedge clk or posedge rst)begin														
			if( rst==1'b1 )begin
				addr_reg <={ADDR_WIDTH{1'b0}};
			end
			else if((CS_N == 1'b0)&&(cnt_bit <= ADDR_WIDTH )&& (sample == 1'b1))begin
				addr_reg <= {addr_reg[ADDR_WIDTH-2:0],SDI};	
			end
			else if(CS_N == 1'b1)begin
				addr_reg <={ADDR_WIDTH{1'b0}};
			end
			else begin
			end
		end
		
		always@(posedge clk or posedge rst)begin
			if(rst==1'b1)begin 
				data_wr_reg <= {DATA_WIDTH{1'b0}};
			end
			else if( (sample==1'b1) && (cnt_bit > ADDR_WIDTH ) && (CS_N == 1'b0))begin
				data_wr_reg <= {data_wr_reg[DATA_WIDTH-2:0],SDI};
			end
			else begin
			end
		end
		
		always@( posedge clk or posedge rst)begin
			if( rst == 1'b1 )begin
				data_wr <= {DATA_WIDTH{1'b0}};
			end
			else if( (cnt_bit == ADDR_WIDTH + DATA_WIDTH) && (operation == WRITE) && (sample == 1'b1))begin
				data_wr <= {data_wr_reg[DATA_WIDTH-2:0],SDI};
			end
			else begin
			
			end
		end
		
	`endif
	
	`ifdef ILA_SPI_SLAVE_MODULE
		
		ila_slave_spi U0_slave_spi(
			.clk		( clk			),
			.probe0		( cnt_bit		),
			.probe1		( CS_N			),
			.probe2		( SCLK			),
			.probe3		( SDI			),
			.probe4		( SDO			),		
			.probe5		( addr_reg		),		
			.probe6		( operation		),		
			.probe7		( cs			),		
			.probe8		( rdy			),		
			.probe9		( data_wr		),		
			.probe10	( data_rd		),		
			.probe11	( addr			)		
		);
	
	`endif
	
endmodule
