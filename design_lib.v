//***********************************************************************
//  this file copy form usb deisgn,incould moduels:
//
//  1.  async_fifo_avail
//  2.  async_fifo
//  3.  crg_reset_sync
//  4.  level_sync
//  5.  usb_lru_arbiter
//  6.  lru_prio_arbiter
//  7.  mem2fifo
//  8.  multi_bit_sync
//  9.  pulse_fb_sync
//  10. pulse_sync
//  11. sync_fifo_avail
//  12. sync_fifo
//  13. two_ports_async_mem
//  14. two_ports_sync_mem
//  15. icg_cell_posedge
//  16. crg_scanmux

//***********************************************************************
//    Copyright (c) 2016 Corigine, Inc.
//    All Rights Reserved.
//***********************************************************************
//-----------------------------------------------------------------------
// File:        async_fifo.v
// Created:     14:58:02, Feb 01, 2016
//-----------------------------------------------------------------------
// Abstract:    This file implements a asynchronous FIFO based on register
//              array. The FIFO will ignore the write operation in full
//              condition and the read operation in empty condition.
//              Compared with async_fifo, this FIFO can provide available
//              entry info for write end
// Naming convention:   
//    r_* represents register  
//    w_* represents wire 
//    x_* and y_* represent signal in clock domain x and y in sync module
//-----------------------------------------------------------------------
module async_fifo_avail(
       //write clock domain
       wr_clk,
       wr_reset_n,
       wr_en,
       wr_data,
       wr_full,
       wr_avail_entry,
       //read clock domain
       rd_clk,
       rd_reset_n,
       rd_en,
       rd_data,
       rd_empty
       );
parameter FIFO_WIDTH = 64;
parameter FIFO_DEPTH_INDEX = 4;
parameter FIFO_DEPTH = 1<<FIFO_DEPTH_INDEX;
parameter FIFO_DEPTH_INDEX_PLUS1 = FIFO_DEPTH_INDEX +1;

input   wr_clk;
input   wr_reset_n;
input   wr_en;
input  [FIFO_WIDTH-1:0] wr_data;
output  wr_full;
output [FIFO_DEPTH_INDEX:0] wr_avail_entry;//available entry number


input   rd_clk;
input   rd_reset_n;
input   rd_en;
output  rd_empty;
output [FIFO_WIDTH-1:0] rd_data;

//variable definition
//write clock domain
reg [FIFO_WIDTH-1:0] wr_r_array [FIFO_DEPTH-1:0];//register array
reg [FIFO_DEPTH_INDEX:0] wr_wpointer;//write pointer
wire [FIFO_DEPTH_INDEX:0] wr_wpointer_add1;//write pointer plus 1
reg [FIFO_DEPTH_INDEX:0] wr_wpointer_gray;//write pointer in gray code
reg [FIFO_DEPTH_INDEX:0] wr_wpointer_gray_next;//next write pointer in gray code
reg [FIFO_DEPTH_INDEX:0] wr_rpointer;//synced read pointer
reg [FIFO_DEPTH_INDEX:0] wr_rpointer_sync1;//synchronizer, level 1
reg [FIFO_DEPTH_INDEX:0] wr_rpointer_sync2;//synchronizer, level 2
wire [FIFO_DEPTH_INDEX-1:0] wr_wpointer_index;//write pointer, exclude the extra bit
reg [FIFO_DEPTH_INDEX:0] wr_avail_entry;//available entry number
wire [FIFO_DEPTH_INDEX-1:0] wr_avail_entry_lsb;
//read clock domain
reg [FIFO_DEPTH_INDEX:0] rd_rpointer;//read pointer
wire [FIFO_DEPTH_INDEX:0] rd_rpointer_add1;//read pointer plus 1
reg [FIFO_DEPTH_INDEX:0] rd_rpointer_gray;//read pointer in gray code
reg [FIFO_DEPTH_INDEX:0] rd_rpointer_gray_next;//next read pointer in gray code
reg [FIFO_DEPTH_INDEX:0] rd_wpointer;//synced write pointer
reg [FIFO_DEPTH_INDEX:0] rd_wpointer_sync1;//synchronizer, level 1
reg [FIFO_DEPTH_INDEX:0] rd_wpointer_sync2;//synchronizer, level 2
wire [FIFO_DEPTH_INDEX:0] rd_rpointer_index;//read pointer, exclude the extra bit

/**********write clock domain logic*******************************/
assign wr_wpointer_index = wr_wpointer[FIFO_DEPTH_INDEX-1:0];
integer i;
always @(posedge wr_clk or negedge wr_reset_n)
begin
  if(!wr_reset_n)
  begin
    wr_wpointer_gray <= {FIFO_DEPTH_INDEX_PLUS1{1'b0}};
    for(i=0;i<FIFO_DEPTH;i=i+1) 
    begin
      wr_r_array[i] <= {FIFO_WIDTH{1'b0}};
    end
  end
  else if(wr_en&&!wr_full)
  //igore the write operation if the FIFO is already full
  begin
    wr_r_array[wr_wpointer_index]<=wr_data;
    wr_wpointer_gray<=wr_wpointer_gray_next;
  end
end

//gray code to binary code
always @(wr_wpointer_gray)
begin
  wr_wpointer[FIFO_DEPTH_INDEX] = wr_wpointer_gray[FIFO_DEPTH_INDEX];
  for(i=FIFO_DEPTH_INDEX-1;i>=0;i=i-1)
  begin
    wr_wpointer[i]=wr_wpointer_gray[i]^wr_wpointer[i+1];
  end
end
assign wr_wpointer_add1 = wr_wpointer + 'd1;
//binary code to gray code
always @(wr_wpointer_add1)
begin
  wr_wpointer_gray_next[FIFO_DEPTH_INDEX] = wr_wpointer_add1[FIFO_DEPTH_INDEX];
  for(i=0;i<FIFO_DEPTH_INDEX;i=i+1)
  begin  
    wr_wpointer_gray_next[i]= wr_wpointer_add1[i+1]^wr_wpointer_add1[i];
  end
end


//Sync gray read pointer to write clock domain
always @(posedge wr_clk or negedge wr_reset_n)
begin
  if(!wr_reset_n)
  begin
    wr_rpointer_sync1 <= {FIFO_DEPTH_INDEX{1'b0}};
    wr_rpointer_sync2 <= {FIFO_DEPTH_INDEX{1'b0}};
  end
  else
  begin
    wr_rpointer_sync1 <= rd_rpointer_gray;
    wr_rpointer_sync2 <= wr_rpointer_sync1;
  end
end

//gray code to binary code
always @(wr_rpointer_sync2)
begin
  wr_rpointer[FIFO_DEPTH_INDEX] = wr_rpointer_sync2[FIFO_DEPTH_INDEX];
  for(i=FIFO_DEPTH_INDEX-1;i>=0;i=i-1)
  begin
    wr_rpointer[i]=wr_rpointer_sync2[i]^wr_rpointer[i+1];
  end
end

assign wr_full = (wr_wpointer[FIFO_DEPTH_INDEX]!=wr_rpointer[FIFO_DEPTH_INDEX])&&
          (wr_wpointer[FIFO_DEPTH_INDEX-1:0]==wr_rpointer[FIFO_DEPTH_INDEX-1:0]); 

assign wr_avail_entry_lsb=(wr_rpointer[FIFO_DEPTH_INDEX-1:0]-wr_wpointer[FIFO_DEPTH_INDEX-1:0]);
always@(*)
begin
  if(wr_wpointer==wr_rpointer)//fifo empty
    wr_avail_entry=1<<FIFO_DEPTH_INDEX;
  else 
    wr_avail_entry={1'b0,wr_avail_entry_lsb};
end
    

/**********read clock domain logic*******************************/
assign rd_rpointer_index = rd_rpointer[FIFO_DEPTH_INDEX-1:0];
always @(posedge rd_clk or negedge rd_reset_n)
begin
  if(!rd_reset_n)
    rd_rpointer_gray <= {FIFO_DEPTH_INDEX_PLUS1{1'b0}};
  else if(rd_en&&!rd_empty)
    rd_rpointer_gray <= rd_rpointer_gray_next;
end

assign rd_rpointer_add1 = rd_rpointer + 'd1;
//binary code to gray code
always @(rd_rpointer_add1)
begin
  rd_rpointer_gray_next[FIFO_DEPTH_INDEX] = rd_rpointer_add1[FIFO_DEPTH_INDEX];
  for(i=0;i<FIFO_DEPTH_INDEX;i=i+1)
  begin  
    rd_rpointer_gray_next[i]= rd_rpointer_add1[i+1]^rd_rpointer_add1[i];
  end
end

//gray code to binary code
always @(rd_rpointer_gray)
begin
  rd_rpointer[FIFO_DEPTH_INDEX] = rd_rpointer_gray[FIFO_DEPTH_INDEX];
  for(i=FIFO_DEPTH_INDEX-1;i>=0;i=i-1)
  begin
    rd_rpointer[i]=rd_rpointer_gray[i]^rd_rpointer[i+1];
  end
end


//Sync gray write pointer to read clock domain
always @(posedge rd_clk or negedge rd_reset_n)
begin
  if(!rd_reset_n)
  begin
    rd_wpointer_sync1 <= {FIFO_DEPTH_INDEX{1'b0}};
    rd_wpointer_sync2 <= {FIFO_DEPTH_INDEX{1'b0}};
  end
  else
  begin
    rd_wpointer_sync1 <= wr_wpointer_gray;
    rd_wpointer_sync2 <= rd_wpointer_sync1;
  end
end

//gray code to binary code
always @(rd_wpointer_sync2)
begin
  rd_wpointer[FIFO_DEPTH_INDEX] = rd_wpointer_sync2[FIFO_DEPTH_INDEX];
  for(i=FIFO_DEPTH_INDEX-1;i>=0;i=i-1)
  begin
    rd_wpointer[i]=rd_wpointer_sync2[i]^rd_wpointer[i+1];
  end
end

assign rd_empty = (rd_wpointer==rd_rpointer);
assign rd_data = wr_r_array[rd_rpointer_index];
endmodule

//***********************************************************************
//    Copyright (c) 2016 Corigine, Inc.
//    All Rights Reserved.
//***********************************************************************
//-----------------------------------------------------------------------
// File:        async_fifo.v
// Created:     14:58:02, Feb 01, 2016
//-----------------------------------------------------------------------
// Abstract:    This file implements a asynchronous FIFO based on register
//              array. The FIFO will ignore the write operation in full
//              condition and the read operation in empty condition.
//
// Naming convention:   
//    r_* represents register  
//    w_* represents wire 
//    x_* and y_* represent signal in clock domain x and y in sync module
//-----------------------------------------------------------------------
module async_fifo(
       //write clock domain
       wr_clk,
       wr_reset_n,
       wr_en,
       wr_data,
       wr_full,
       //read clock domain
       rd_clk,
       rd_reset_n,
       rd_en,
       rd_data,
       rd_empty
       );
parameter FIFO_WIDTH = 64;
parameter FIFO_DEPTH_INDEX = 4;
parameter FIFO_DEPTH = 1<<FIFO_DEPTH_INDEX;
parameter FIFO_DEPTH_INDEX_PLUS1 = FIFO_DEPTH_INDEX +1;

input   wr_clk;
input   wr_reset_n;
input   wr_en;
input  [FIFO_WIDTH-1:0] wr_data;
output  wr_full;

input   rd_clk;
input   rd_reset_n;
input   rd_en;
output  rd_empty;
output [FIFO_WIDTH-1:0] rd_data;

//1 depth FIFO is a little special, you don't really need pointers
generate if ( FIFO_DEPTH_INDEX == 0 ) begin: gen_fifo_depth1
reg [FIFO_WIDTH-1:0]    wr_r_array;
reg [FIFO_WIDTH-1:0]    rd_r_array_sync;
reg                     wr_state;
reg                     rd_state;
reg                     wr_state_sync1;
reg                     wr_state_sync2;
reg                     wr_state_sync3;
reg                     rd_state_sync1;
reg                     rd_state_sync2;
wire                    wr_state_sync;
wire                    rd_state_sync;

//write data
always @( posedge wr_clk or negedge wr_reset_n ) begin
    if ( ~wr_reset_n ) begin
        wr_r_array      <= {FIFO_WIDTH{1'b0}};
    end
    else if ( wr_en && ~wr_full ) begin
        wr_r_array      <= wr_data;
    end
end

//toggle write state
always @( posedge wr_clk or negedge wr_reset_n ) begin
    if ( ~wr_reset_n ) begin
        wr_state        <= 1'b0;
    end
    else if ( wr_en && ~wr_full ) begin
        wr_state        <= ~wr_state;
    end
end

//sync read state back
always @( posedge wr_clk or negedge wr_reset_n ) begin
    if ( ~wr_reset_n ) begin
        rd_state_sync1  <= 1'b0;
        rd_state_sync2  <= 1'b0;
    end
    else begin
        rd_state_sync1  <= rd_state;
        rd_state_sync2  <= rd_state_sync1;
    end
end
assign  rd_state_sync = rd_state_sync2;
assign  wr_full = wr_state != rd_state_sync;

//maintain the read state
always @( posedge rd_clk or negedge rd_reset_n ) begin
    if ( ~rd_reset_n ) begin
        rd_state        <= 1'b0;
    end
    else if ( rd_en && ~rd_empty ) begin
        rd_state        <= ~rd_state;
    end
end

always @( posedge rd_clk or negedge rd_reset_n ) begin
    if ( ~rd_reset_n ) begin
      rd_r_array_sync<={FIFO_WIDTH{1'b0}};
    end
    else if (wr_state_sync2!=wr_state_sync3) begin
      rd_r_array_sync<=wr_r_array;
    end
end

//sync write state
always @( posedge rd_clk or negedge rd_reset_n ) begin
    if ( ~rd_reset_n ) begin
        wr_state_sync1  <= 1'b0;
        wr_state_sync2  <= 1'b0;
        wr_state_sync3  <= 1'b0;
    end
    else begin
        wr_state_sync1  <= wr_state;
        wr_state_sync2  <= wr_state_sync1;
        wr_state_sync3  <= wr_state_sync2;
    end
end
assign  wr_state_sync = wr_state_sync3;

assign  rd_empty = rd_state == wr_state_sync;
assign  rd_data = rd_r_array_sync;

end
else begin: gen_fifo_other_depth
//variable definition
//write clock domain
reg [FIFO_WIDTH-1:0] wr_r_array [FIFO_DEPTH-1:0];//register array
reg [FIFO_DEPTH_INDEX:0] wr_wpointer;//write pointer
wire [FIFO_DEPTH_INDEX:0] wr_wpointer_add1;//write pointer
reg [FIFO_DEPTH_INDEX:0] wr_wpointer_gray;//write pointer in gray code
reg [FIFO_DEPTH_INDEX:0] wr_wpointer_gray_next;//write pointer in gray code
reg [FIFO_DEPTH_INDEX:0] wr_rpointer;//synced read pointer
reg [FIFO_DEPTH_INDEX:0] wr_rpointer_sync1;//synchronizer, level 1
reg [FIFO_DEPTH_INDEX:0] wr_rpointer_sync2;//synchronizer, level 2
wire [FIFO_DEPTH_INDEX-1:0] wr_wpointer_index;//write pointer, exclude the extra bit

//read clock domain
reg [FIFO_DEPTH_INDEX:0] rd_rpointer;//read pointer
wire [FIFO_DEPTH_INDEX:0] rd_rpointer_add1;//read pointer
reg [FIFO_DEPTH_INDEX:0] rd_rpointer_gray;//read pointer in gray code
reg [FIFO_DEPTH_INDEX:0] rd_rpointer_gray_next;//read pointer in gray code
reg [FIFO_DEPTH_INDEX:0] rd_wpointer;//synced write pointer
reg [FIFO_DEPTH_INDEX:0] rd_wpointer_sync1;//synchronizer, level 1
reg [FIFO_DEPTH_INDEX:0] rd_wpointer_sync2;//synchronizer, level 2
wire [FIFO_DEPTH_INDEX-1:0] rd_rpointer_index;//read pointer, exclude the extra bit

/**********write clock domain logic*******************************/
assign wr_wpointer_index = wr_wpointer[FIFO_DEPTH_INDEX-1:0];
integer i;
always @(posedge wr_clk or negedge wr_reset_n)
begin
  if(!wr_reset_n)
  begin
    wr_wpointer_gray <= {FIFO_DEPTH_INDEX_PLUS1{1'b0}};
    for(i=0;i<FIFO_DEPTH;i=i+1) 
    begin
      wr_r_array[i] <= {FIFO_WIDTH{1'b0}};
    end
  end
  else if(wr_en&&!wr_full)
  //igore the write operation if the FIFO is already full
  begin
    wr_r_array[wr_wpointer_index]<=wr_data;
    wr_wpointer_gray<=wr_wpointer_gray_next;
  end
end

//binary code to gray code
always @(wr_wpointer_add1)
begin
  wr_wpointer_gray_next[FIFO_DEPTH_INDEX] = wr_wpointer_add1[FIFO_DEPTH_INDEX];
  for(i=0;i<FIFO_DEPTH_INDEX;i=i+1)
  begin  
    wr_wpointer_gray_next[i]= wr_wpointer_add1[i+1]^wr_wpointer_add1[i];
  end
end

//gray code to binary code
always @(wr_wpointer_gray)
begin
  wr_wpointer[FIFO_DEPTH_INDEX] = wr_wpointer_gray[FIFO_DEPTH_INDEX];
  for(i=FIFO_DEPTH_INDEX-1;i>=0;i=i-1)
  begin
    wr_wpointer[i]=wr_wpointer_gray[i]^wr_wpointer[i+1];
  end
end

assign wr_wpointer_add1 = wr_wpointer + 'd1;

//Sync gray read pointer to write clock domain
always @(posedge wr_clk or negedge wr_reset_n)
begin
  if(!wr_reset_n)
  begin
    wr_rpointer_sync1 <= {FIFO_DEPTH_INDEX{1'b0}};
    wr_rpointer_sync2 <= {FIFO_DEPTH_INDEX{1'b0}};
  end
  else
  begin
    wr_rpointer_sync1 <= rd_rpointer_gray;
    wr_rpointer_sync2 <= wr_rpointer_sync1;
  end
end

//gray code to binary code
always @(wr_rpointer_sync2)
begin
  wr_rpointer[FIFO_DEPTH_INDEX] = wr_rpointer_sync2[FIFO_DEPTH_INDEX];
  for(i=FIFO_DEPTH_INDEX-1;i>=0;i=i-1)
  begin
    wr_rpointer[i]=wr_rpointer_sync2[i]^wr_rpointer[i+1];
  end
end

assign wr_full = (wr_wpointer[FIFO_DEPTH_INDEX]!=wr_rpointer[FIFO_DEPTH_INDEX])&&
          (wr_wpointer[FIFO_DEPTH_INDEX-1:0]==wr_rpointer[FIFO_DEPTH_INDEX-1:0]); 
  
/**********read clock domain logic*******************************/
assign rd_rpointer_index = rd_rpointer[FIFO_DEPTH_INDEX-1:0];
always @(posedge rd_clk or negedge rd_reset_n)
begin
  if(!rd_reset_n)
    rd_rpointer_gray <= {FIFO_DEPTH_INDEX_PLUS1{1'b0}};
  else if(rd_en&&!rd_empty)
    rd_rpointer_gray <= rd_rpointer_gray_next;
end

//binary code to gray code
always @(rd_rpointer_add1)
begin
  rd_rpointer_gray_next[FIFO_DEPTH_INDEX] = rd_rpointer_add1[FIFO_DEPTH_INDEX];
  for(i=0;i<FIFO_DEPTH_INDEX;i=i+1)
  begin  
    rd_rpointer_gray_next[i]= rd_rpointer_add1[i+1]^rd_rpointer_add1[i];
  end
end
//gray code to binary code
always @(rd_rpointer_gray)
begin
  rd_rpointer[FIFO_DEPTH_INDEX] = rd_rpointer_gray[FIFO_DEPTH_INDEX];
  for(i=FIFO_DEPTH_INDEX-1;i>=0;i=i-1)
  begin
    rd_rpointer[i]=rd_rpointer_gray[i]^rd_rpointer[i+1];
  end
end

assign rd_rpointer_add1 = rd_rpointer + 'd1;


//Sync gray write pointer to read clock domain
always @(posedge rd_clk or negedge rd_reset_n)
begin
  if(!rd_reset_n)
  begin
    rd_wpointer_sync1 <= {FIFO_DEPTH_INDEX{1'b0}};
    rd_wpointer_sync2 <= {FIFO_DEPTH_INDEX{1'b0}};
  end
  else
  begin
    rd_wpointer_sync1 <= wr_wpointer_gray;
    rd_wpointer_sync2 <= rd_wpointer_sync1;
  end
end

//gray code to binary code
always @(rd_wpointer_sync2)
begin
  rd_wpointer[FIFO_DEPTH_INDEX] = rd_wpointer_sync2[FIFO_DEPTH_INDEX];
  for(i=FIFO_DEPTH_INDEX-1;i>=0;i=i-1)
  begin
    rd_wpointer[i]=rd_wpointer_sync2[i]^rd_wpointer[i+1];
  end
end

assign rd_empty = (rd_wpointer==rd_rpointer);
assign rd_data = wr_r_array[rd_rpointer_index];

end
endgenerate
endmodule

//***********************************************************************
//    Copyright (c) 2016 Corigine, Inc.
//    All Rights Reserved.
//***********************************************************************
//-----------------------------------------------------------------------
// File:        crg_reset_sync.v
// Created:     15:32:28, Apr 01, 2016
//-----------------------------------------------------------------------
// Abstract:    sync the reset signal
//
//-----------------------------------------------------------------------
module crg_reset_sync (
    input  wire     clk,
    input  wire     i_rstn,
    output wire     o_rstn,
    input  wire     scan_mode
);

reg r1;
reg r2;

always @( posedge clk or negedge i_rstn ) begin
    if ( ~i_rstn ) begin
        r1      <= 1'b0;
        r2      <= 1'b0;
    end
    else begin
        r1      <= 1'b1;
        r2      <= r1;
    end
end

//assign o_rstn = scan_mode ? i_rstn : r2;

scanmux     u_reset_n_o_tm ( .S(scan_mode), .A(r2), .B(i_rstn), .Z(o_rstn));

endmodule

//***********************************************************************
//    Copyright (c) 2016 Corigine, Inc.
//    All Rights Reserved.
//***********************************************************************
//-----------------------------------------------------------------------
// File:        level_sync.v
// Auther:      Kaidi You (kaidiyou@corigine.com)
// Created:     16:16:48, Feb 04, 2016
//-----------------------------------------------------------------------
// Abstract:    Synchronizer for level signal
//
// Naming convention:   
//    r_* represents register  
//    w_* represents wire 
//    x_* and y_* represent signal in clock domain x and y in sync module
//-----------------------------------------------------------------------
module level_sync #(
					parameter DEFAULT_VALUE = 0)
					(
                  //Source clock domain
                  a_data_in,
                  //destination clock domain
                  b_clk,
                  b_reset_n,
                  b_data_out
                  );
 //Source clock domain
input  a_data_in;
 //destination clock domain
input  b_clk;
input  b_reset_n;
output b_data_out;

reg b_sync_1;
reg b_sync_2;
generate
if (DEFAULT_VALUE)
begin:default1
 always@(posedge b_clk or negedge b_reset_n)
 begin
   if(!b_reset_n)
   begin
     b_sync_1<=1'b1;
     b_sync_2<=1'b1;
   end
   else
   begin
     b_sync_1<=a_data_in;
     b_sync_2<=b_sync_1;
   end
 end
end
else
begin:default0
 always@(posedge b_clk or negedge b_reset_n)
 begin
   if(!b_reset_n)
   begin
     b_sync_1<=1'b0;
     b_sync_2<=1'b0;
   end
   else
   begin
     b_sync_1<=a_data_in;
     b_sync_2<=b_sync_1;
   end
 end
end
endgenerate
assign b_data_out = b_sync_2;

endmodule


//***********************************************************************
//    Copyright (c) 2016 Corigine, Inc.
//    All Rights Reserved.
//***********************************************************************
//-----------------------------------------------------------------------
// File:        lru_arbiter.v
// Created:     11:17:01, Junly 19, 2016
//-----------------------------------------------------------------------
// Abstract:    Latest Recent Used arbiter
//
//-----------------------------------------------------------------------
module usb_lru_arbiter(
       clk,
       reset_n,
       req_array,
       win_array,
       win_done
       );
parameter REQ_NUM = 3;
input clk;
input reset_n;
input [REQ_NUM-1:0] req_array;
output [REQ_NUM-1:0] win_array;
input  win_done;
reg [REQ_NUM-1:0] status_reg [REQ_NUM-1:0] ;//This register matrix can be optimized to triangle
reg [REQ_NUM-1:0] win_array_pre;
reg [REQ_NUM-1:0] win_array_latch;
reg arb_busy;

integer i,j,k,u;
always@(posedge clk or negedge reset_n)
begin
  if(!reset_n)
    arb_busy<=1'b0;
  else if(win_done)
    arb_busy<=1'b0;
  else if(|win_array)
    arb_busy<=1'b1;
end

always@(posedge clk or negedge reset_n)
begin
  if(!reset_n)
  begin
    for(u=0;u<REQ_NUM;u=u+1)
    begin
      for(k=0;k<REQ_NUM;k=k+1)
      begin
        if(k<u)
          status_reg[u][k]<=1'b0;
        else
          status_reg[u][k]<=1'b1;
      end
    end
  end
  else if(win_done)
  begin
    for(u=0;u<REQ_NUM;u=u+1)
    begin
      for(k=0;k<REQ_NUM;k=k+1)
      begin
        if(win_array[u])
          status_reg[u][k]<=1'b0;
        else if(win_array[k])
          status_reg[u][k]<=1'b1;
      end
    end
  end
end

always@(*)
begin
for(i=0;i<REQ_NUM;i=i+1)
begin
  win_array_pre[i]=1;
  for(j=0;j<REQ_NUM;j=j+1)
  begin
    if(i==j)
    begin
      win_array_pre[i]=win_array_pre[i]&req_array[j];
    end
    else
    begin
      win_array_pre[i]=win_array_pre[i]&(~req_array[j]|status_reg[i][j]);
    end
  end
end
end

always@(posedge clk or negedge reset_n)
begin
  if(!reset_n)
    win_array_latch<={REQ_NUM{1'b0}};
  else if(!arb_busy)
    win_array_latch<=win_array_pre;
end

assign win_array = arb_busy ? win_array_latch : win_array_pre;

endmodule

//***********************************************************************
//    Copyright (c) 2016 Corigine, Inc.
//    All Rights Reserved.
//***********************************************************************
//-----------------------------------------------------------------------
// File:        lru_arbiter.v
// Created:     11:17:01, Junly 19, 2016
//-----------------------------------------------------------------------
// Abstract:    Latest Recent Used arbiter
//
//-----------------------------------------------------------------------
module lru_prio_arbiter(
       clk,
       reset_n,
       req_array,
       req_prio,
       win_array,
       win_done
       );
parameter REQ_NUM = 3;
input clk;
input reset_n;
input [REQ_NUM-1:0] req_array;
input [REQ_NUM-1:0] req_prio;
output [REQ_NUM-1:0] win_array;
input  win_done;
wire [REQ_NUM-1:0]   req_array_mod;
reg [REQ_NUM-1:0] status_reg [REQ_NUM-1:0] ;//This register matrix can be optimized to triangle
reg [REQ_NUM-1:0] win_array_pre;
reg [REQ_NUM-1:0] win_array_latch;
reg arb_busy;

assign req_array_mod = |(req_array & req_prio ) ? req_array & req_prio : req_array;

integer i,j,k,u;
always@(posedge clk or negedge reset_n)
begin
  if(!reset_n)
    arb_busy<=1'b0;
  else if(win_done)
    arb_busy<=1'b0;
  else if(|win_array)
    arb_busy<=1'b1;
end

always@(posedge clk or negedge reset_n)
begin
  if(!reset_n)
  begin
    for(u=0;u<REQ_NUM;u=u+1)
    begin
      for(k=0;k<REQ_NUM;k=k+1)
      begin
        if(k<u)
          status_reg[u][k]<=1'b0;
        else
          status_reg[u][k]<=1'b1;
      end
    end
  end
  else if(win_done)
  begin
    for(u=0;u<REQ_NUM;u=u+1)
    begin
      for(k=0;k<REQ_NUM;k=k+1)
      begin
        if(win_array[u])
          status_reg[u][k]<=1'b0;
        else if(win_array[k])
          status_reg[u][k]<=1'b1;
      end
    end
  end
end

always@(*)
begin
for(i=0;i<REQ_NUM;i=i+1)
begin
  win_array_pre[i]=1;
  for(j=0;j<REQ_NUM;j=j+1)
  begin
    if(i==j)
    begin
      win_array_pre[i]=win_array_pre[i]&req_array_mod[j];
    end
    else
    begin
      win_array_pre[i]=win_array_pre[i]&(~req_array_mod[j]|status_reg[i][j]);
    end
  end
end
end

always@(posedge clk or negedge reset_n)
begin
  if(!reset_n)
    win_array_latch<={REQ_NUM{1'b0}};
  else if(!arb_busy)
    win_array_latch<=win_array_pre;
end

assign win_array = arb_busy ? win_array_latch : win_array_pre;

endmodule

//***********************************************************************
//    Copyright (c) 2016 Corigine, Inc.
//    All Rights Reserved.
//***********************************************************************
//-----------------------------------------------------------------------
// File:        mem2_fifo.v
// Created:     13:56:18, Jul 26, 2016
//-----------------------------------------------------------------------
// Abstract:    This module is used to translate the memory interface into fifo read interface
//
//-----------------------------------------------------------------------
module mem2fifo #( parameter WIDTH = 4 ) (
    input wire          clk,
    input wire          rstn,
    output wire         mem_ren,
    input wire          mem_rack,
    input wire [WIDTH-1:0] mem_rdata,
    input wire          mem_rempty,

    input wire          fifo_rd,
    output wire [WIDTH-1:0] fifo_rdata,
    output reg          fifo_empty
);

reg [WIDTH-1:0]         data;

//when to fetch data ?
// mem_rempty is 0 and fifo_empty is 1
localparam       IDLE = 1'b0;
localparam       FETCH = 1'b1;

reg     state;
reg     nstate;

always @( posedge clk or negedge rstn) begin
    if ( ~rstn ) begin
        state   <= IDLE;
    end
    else begin
        state  <= nstate;
    end
end

always @( * ) begin
    nstate = state;
    case ( state )
        IDLE: begin
            if ( fifo_empty & ~mem_rempty ) begin
                nstate = FETCH;
            end
        end
        FETCH: begin
            if ( mem_rack ) begin
                nstate  = IDLE;
            end
        end
    endcase
end

always @( posedge clk or negedge rstn ) begin
    if ( ~rstn ) begin
        data    <= {WIDTH{1'b0}};
    end
    else if ( state == FETCH && nstate == IDLE ) begin
        data    <=  mem_rdata;
    end
end

always @( posedge clk or negedge rstn ) begin
    if ( ~rstn ) begin
        fifo_empty      <= 1'b1;
    end
    else if ( state == FETCH && nstate == IDLE ) begin
        fifo_empty      <= 1'b0;
    end
    else if ( fifo_rd ) begin
        fifo_empty      <= 1'b1;
    end
end 

assign  fifo_rdata = data;
assign  mem_ren = state == FETCH;

endmodule

//***********************************************************************
//    Copyright (c) 2016 Corigine, Inc.
//    All Rights Reserved.
//***********************************************************************
//-----------------------------------------------------------------------
// File:        multi_bit_sync.v
// Created:     14:00:01, Feb 02, 2016
//-----------------------------------------------------------------------
// Abstract:    This file implements a multi-bit synchronizer which includes
//              a latch register and synced register. When req pulse is valid
//              the input bits are latched to latch register. The req pulse is
//              then synchronized to destination clock domain and synced
//              register will sample the value of latch register. In the last
//              step, the req pulse is synced back to source clock domain to 
//              generate an ack pulse. A new round synchronizaiton can start 
//              after the previous ack has been received.
//
// Naming convention:   
//    r_* represents register  
//    w_* represents wire 
//    x_* and y_* represent signal in clock domain x and y in sync module
//-----------------------------------------------------------------------
module multi_bit_sync(
       //source clock domain
       a_clk,
       a_reset_n,
       a_req,
       a_ack,
       a_data_in,
       //destination clock domain
       b_clk,
       b_reset_n,
       b_update,
       b_data_out
       );
parameter DATA_WIDTH =1;
parameter DATA_DEFAULT = 'h0;

//source clock domain
input   a_clk;
input   a_reset_n;
input   a_req;//pulse valid
output  a_ack;//pulse valid
input [DATA_WIDTH-1:0] a_data_in;
//destination clock domain
input   b_clk;
input   b_reset_n;
output  b_update;//pulse valid
output [DATA_WIDTH-1:0] b_data_out;

//variable definition
reg [DATA_WIDTH-1:0] a_latch_reg;//latch register
reg [DATA_WIDTH-1:0] b_synced_reg;//synced register
reg a_req_toggle;
reg b_req_sync1;
reg b_req_sync2;
reg b_req_sync3;
reg a_ack_sync1;
reg a_ack_sync2;
reg a_ack_sync3;
reg b_update;
reg b_update_toggle;

/***********************Source clock domain***********************/
always@(posedge a_clk or negedge a_reset_n)
begin
  if(!a_reset_n)
  begin
    a_req_toggle<=1'b0;
    a_latch_reg<=DATA_DEFAULT;
  end
  else if(a_req)
  begin
    a_req_toggle<=~a_req_toggle;
    a_latch_reg<=a_data_in;//latch the input data when a_req is valid
  end
end

always@(posedge a_clk or negedge a_reset_n)
begin
  if(!a_reset_n)
  begin
    a_ack_sync1<=1'b0;
    a_ack_sync2<=1'b0;
    a_ack_sync3<=1'b0;
  end
  else
  begin
    a_ack_sync1<=b_update_toggle;
    a_ack_sync2<=a_ack_sync1;
    a_ack_sync3<=a_ack_sync2;
  end
end
  
assign a_ack = a_ack_sync2^a_ack_sync3;
/***********************Destination clock domain***********************/
always@(posedge b_clk or negedge b_reset_n)
begin
  if(!b_reset_n)
  begin
    b_req_sync1<=1'b0;
    b_req_sync2<=1'b0;
    b_req_sync3<=1'b0;
    b_update<=1'b0;
  end
  else
  begin
    b_req_sync1<=a_req_toggle;
    b_req_sync2<=b_req_sync1;
    b_req_sync3<=b_req_sync2;
    b_update<=b_req_sync2^b_req_sync3;
  end
end

always@(posedge b_clk or negedge b_reset_n)
begin
  if(!b_reset_n)
  begin
    b_synced_reg<=DATA_DEFAULT;
    b_update_toggle<=1'b0;
  end
  else if(b_req_sync2^b_req_sync3)
  begin
    b_synced_reg<=a_latch_reg;
    b_update_toggle<=~b_update_toggle;
  end
end

assign b_data_out = b_synced_reg;

endmodule
//***********************************************************************
//    Copyright (c) 2016 Corigine, Inc.
//    All Rights Reserved.
//***********************************************************************
//-----------------------------------------------------------------------
// File:        pulse_fb_sync.v
// Created:     10:50:02, Feb 01, 2016
//-----------------------------------------------------------------------
// Abstract:    ADD DESCRIPTION HERE
//
// Naming convention:   
//    r_* represents register  
//    w_* represents wire 
//    x_* and y_* represent signal in clock domain x and y in sync module
//-----------------------------------------------------------------------
module pulse_fb_sync (
       //source clock domain a
       a_clk,
       a_reset_n,
       a_pulse_in,
       a_pulse_ack,
       //destination clock domain b
       b_clk,
       b_reset_n,
       b_pulse_out
       );
//source clock domain a
input  a_clk;
input  a_reset_n;
input  a_pulse_in;
output a_pulse_ack;//a_pulse_in can be valid again until a_pulse_ack for
                   //previous a_pulse_in is received
//destination clock domain b
input  b_clk;
input  b_reset_n;
output b_pulse_out;
//variable definition
reg a_r_toggle;//Register that is used to convert pulse to level change 
reg a_r_sync1;//Synchronization register, level 1
reg a_r_sync2;//Synchronization register, level 2
reg a_r_sync3;//Synchronization register, level 3
reg b_r_sync1;//Synchronization register, level 1
reg b_r_sync2;//Synchronization register, level 2
reg b_r_sync3;//Synchronization register, level 3

//**************Clock domain a****************************
always @(posedge a_clk or negedge a_reset_n)
begin
  if(!a_reset_n)
    a_r_toggle <= 1'b0;
  else if(a_pulse_in)//toggle on each valid pulse
    a_r_toggle <= ~a_r_toggle;
end

always @(posedge a_clk or negedge a_reset_n)
begin
  if(!a_reset_n)
  begin
    a_r_sync1 <= 1'b0;
    a_r_sync2 <= 1'b0;
    a_r_sync3 <= 1'b0;
  end
  else
  begin
    a_r_sync1 <= b_r_sync3;
    a_r_sync2 <= a_r_sync1;
    a_r_sync3 <= a_r_sync2;
  end
end

//Generate feedback pulse upon the level change
assign a_pulse_ack = a_r_sync2^a_r_sync3;
//**************Clock domain b****************************
always @(posedge b_clk or negedge b_reset_n)
begin
  if(!b_reset_n)
  begin
    b_r_sync1 <= 1'b0;
    b_r_sync2 <= 1'b0;
    b_r_sync3 <= 1'b0;
  end
  else
  begin
    b_r_sync1 <= a_r_toggle;
    b_r_sync2 <= b_r_sync1;
    b_r_sync3 <= b_r_sync2;
  end
end
    
assign b_pulse_out = b_r_sync2^b_r_sync3;//Generate pulse upon the level change




endmodule

//***********************************************************************
//    Copyright (c) 2016 Corigine, Inc.
//    All Rights Reserved.
//***********************************************************************
//-----------------------------------------------------------------------
// File:        pulse_sync.v
// Created:     10:28:12, Feb 01, 2016
//-----------------------------------------------------------------------
// Abstract:    This file implements a synchronizer that synchronizes a
//              pulse signal from clock domain a to a pulse signal in clock
//              domain b. There is no handshakeing scheme, so users have to
//              avoid two consecutive pulses which may be failed to
//              synchronize 
//
// Naming convention:   
//    r_* represents register  
//    w_* represents wire 
//    x_* and y_* represent signal in clock domain x and y in sync module

//-----------------------------------------------------------------------

module pulse_sync (
       //source clock domain a
       a_clk,
       a_reset_n,
       a_pulse_in,
       //destination clock domain b
       b_clk,
       b_reset_n,
       b_pulse_out
       );
//source clock domain a
input  a_clk;
input  a_reset_n;
input  a_pulse_in;
//destination clock domain b
input  b_clk;
input  b_reset_n;
output b_pulse_out;
//variable definition
reg a_r_toggle;//Register that is used to convert pulse to level change 
reg b_r_sync1;//Synchronization register, level 1
reg b_r_sync2;//Synchronization register, level 2
reg b_r_sync3;//Synchronization register, level 3

//**************Clock domain a****************************
always @(posedge a_clk or negedge a_reset_n)
begin
  if(!a_reset_n)
    a_r_toggle <= 1'b0;
  else if(a_pulse_in)//toggle on each valid pulse
    a_r_toggle <= ~a_r_toggle;
end


//**************Clock domain b****************************
always @(posedge b_clk or negedge b_reset_n)
begin
  if(!b_reset_n)
  begin
    b_r_sync1 <= 1'b0;
    b_r_sync2 <= 1'b0;
    b_r_sync3 <= 1'b0;
  end
  else
  begin
    b_r_sync1 <= a_r_toggle;
    b_r_sync2 <= b_r_sync1;
    b_r_sync3 <= b_r_sync2;
  end
end
    
assign b_pulse_out = b_r_sync2^b_r_sync3;//Generate pulse upon the level change




endmodule

//***********************************************************************
//    Copyright (c) 2016 Corigine, Inc.
//    All Rights Reserved.
//***********************************************************************
//-----------------------------------------------------------------------
// File:        sync_fifo.v
// Created:     11:17:01, Feb 01, 2016
//-----------------------------------------------------------------------
// Abstract:    This file implements a synchronous FIFO based on register
//              array. The FIFO will ignore the write operation in full
//              condition and the read operation in empty condition.
//              Compared with sync_fifo, this FIFO can provide available
//              entry info for write end 
//
// Naming convention:   
//    r_* represents register  
//    w_* represents wire 
//    x_* and y_* represent signal in clock domain x and y in sync module
//-----------------------------------------------------------------------
module sync_fifo_avail(
       clk,
       reset_n,
       wr_en,
       wr_data,
       wr_full,
       avail_entry,
       rd_en,
       rd_data,
       rd_empty
       );
parameter FIFO_WIDTH = 64;
parameter FIFO_DEPTH_INDEX = 4;
parameter FIFO_DEPTH = 1<<FIFO_DEPTH_INDEX;
parameter FIFO_DEPTH_INDEX_PLUS1 = FIFO_DEPTH_INDEX+1;

input   clk;
input   reset_n;
input   wr_en;
input  [FIFO_WIDTH-1:0] wr_data;
output  wr_full;
output [FIFO_DEPTH_INDEX:0] avail_entry;//available entry number
input   rd_en;
output  rd_empty;
output [FIFO_WIDTH-1:0] rd_data;

//variable definition
reg [FIFO_WIDTH-1:0] r_array [FIFO_DEPTH-1:0];
reg [FIFO_DEPTH_INDEX:0] wr_pointer;
reg [FIFO_DEPTH_INDEX:0] rd_pointer;
wire [FIFO_DEPTH_INDEX-1:0] wr_pointer_index;
wire [FIFO_DEPTH_INDEX-1:0] rd_pointer_index;
assign wr_pointer_index = wr_pointer[FIFO_DEPTH_INDEX-1:0];
assign rd_pointer_index = rd_pointer[FIFO_DEPTH_INDEX-1:0];
reg  [FIFO_DEPTH_INDEX:0] avail_entry;
wire [FIFO_DEPTH_INDEX-1:0] avail_entry_lsb;
integer i;
always @(posedge clk or negedge reset_n)
begin
  if(!reset_n)
  begin
    wr_pointer <= {FIFO_DEPTH_INDEX_PLUS1{1'b0}};
    for(i=0;i<FIFO_DEPTH;i=i+1) 
    begin
      r_array[i] <= {FIFO_WIDTH{1'b0}};
    end
  end
  else if(wr_en&&!wr_full)
  //igore the write operation if the FIFO is already full
  begin
    r_array[wr_pointer_index]<=wr_data;
    wr_pointer<=wr_pointer+1;
  end
end

always @(posedge clk or negedge reset_n)
begin
  if(!reset_n)
    rd_pointer <= {FIFO_DEPTH_INDEX_PLUS1{1'b0}};
  else if(rd_en&&!rd_empty)
    rd_pointer <= rd_pointer + 1;
end

assign wr_full = (wr_pointer[FIFO_DEPTH_INDEX]!=rd_pointer[FIFO_DEPTH_INDEX])&&
          (wr_pointer[FIFO_DEPTH_INDEX-1:0]==rd_pointer[FIFO_DEPTH_INDEX-1:0]);

assign avail_entry_lsb=(rd_pointer[FIFO_DEPTH_INDEX-1:0]-wr_pointer[FIFO_DEPTH_INDEX-1:0]);
always@(*)
begin
  if(rd_empty)
    avail_entry=1<<FIFO_DEPTH_INDEX;
  else 
    avail_entry={1'b0,avail_entry_lsb};
end
    

assign rd_empty = (wr_pointer==rd_pointer);

assign rd_data = r_array[rd_pointer_index];
endmodule

//***********************************************************************
//    Copyright (c) 2016 Corigine, Inc.
//    All Rights Reserved.
//***********************************************************************
//-----------------------------------------------------------------------
// File:        sync_fifo.v
// Created:     11:17:01, Feb 01, 2016
//-----------------------------------------------------------------------
// Abstract:    This file implements a synchronous FIFO based on register
//              array. The FIFO will ignore the write operation in full
//              condition and the read operation in empty condition.
//
// Naming convention:   
//    r_* represents register  
//    w_* represents wire 
//    x_* and y_* represent signal in clock domain x and y in sync module
//-----------------------------------------------------------------------
module sync_fifo(
       clk,
       reset_n,
       wr_en,
       wr_data,
       wr_full,
       rd_en,
       rd_data,
       rd_empty
       );
parameter FIFO_WIDTH = 64;
parameter FIFO_DEPTH_INDEX = 4;
parameter FIFO_DEPTH = 1<<FIFO_DEPTH_INDEX;
parameter FIFO_DEPTH_INDEX_PLUS1 = FIFO_DEPTH_INDEX+1;

input   clk;
input   reset_n;
input   wr_en;
input  [FIFO_WIDTH-1:0] wr_data;
output  wr_full;
input   rd_en;
output  rd_empty;
output [FIFO_WIDTH-1:0] rd_data;

//variable definition
reg [FIFO_WIDTH-1:0] r_array [FIFO_DEPTH-1:0];
reg [FIFO_DEPTH_INDEX:0] wr_pointer;
reg [FIFO_DEPTH_INDEX:0] rd_pointer;
wire [FIFO_DEPTH_INDEX-1:0] wr_pointer_index;
wire [FIFO_DEPTH_INDEX-1:0] rd_pointer_index;
assign wr_pointer_index = wr_pointer[FIFO_DEPTH_INDEX-1:0];
assign rd_pointer_index = rd_pointer[FIFO_DEPTH_INDEX-1:0];

integer i;
always @(posedge clk or negedge reset_n)
begin
  if(!reset_n)
  begin
    wr_pointer <= {FIFO_DEPTH_INDEX_PLUS1{1'b0}};
    for(i=0;i<FIFO_DEPTH;i=i+1) 
    begin
      r_array[i] <= {FIFO_WIDTH{1'b0}};
    end
  end
  else if(wr_en&&!wr_full)
  //igore the write operation if the FIFO is already full
  begin
    r_array[wr_pointer_index]<=wr_data;
    wr_pointer<=wr_pointer+1;
  end
end

always @(posedge clk or negedge reset_n)
begin
  if(!reset_n)
    rd_pointer <= {FIFO_DEPTH_INDEX_PLUS1{1'b0}};
  else if(rd_en&&!rd_empty)
    rd_pointer <= rd_pointer + 1;
end

assign wr_full = (wr_pointer[FIFO_DEPTH_INDEX]!=rd_pointer[FIFO_DEPTH_INDEX])&&
          (wr_pointer[FIFO_DEPTH_INDEX-1:0]==rd_pointer[FIFO_DEPTH_INDEX-1:0]); 
assign rd_empty = (wr_pointer==rd_pointer);

assign rd_data = r_array[rd_pointer_index];
endmodule

//***********************************************************************
//    Copyright (c) 2016 Corigine, Inc.
//    All Rights Reserved.
//***********************************************************************
//-----------------------------------------------------------------------
// File:        two_ports_async_mem.v
// Created:     18:27:09, Mar 17, 2016
//-----------------------------------------------------------------------
// Abstract:    Two ports memory model, write and read ports are in
//              different clock domains
//
//-----------------------------------------------------------------------
module two_ports_async_mem(
        //read port
        rd_clk,
        rd_rst_n,
        rd_en,
        rd_addr,
        rd_data,
        //write port
        wr_clk,
        wr_rst_n,
        wr_en,
        wr_addr,
        wr_data
        );
parameter MEM_WIDTH = 64;
parameter MEM_ADDR_WIDTH = 10;
parameter MEM_DEPTH = 1<<MEM_ADDR_WIDTH;
     //read port
input        rd_clk;
input        rd_rst_n;
input        rd_en;
input        [MEM_ADDR_WIDTH-1:0] rd_addr;
output       [MEM_WIDTH-1:0] rd_data;
     //write port
input        wr_clk;
input        wr_rst_n;
input        wr_en;
input        [MEM_ADDR_WIDTH-1:0] wr_addr;
input        [MEM_WIDTH-1:0] wr_data;


reg          [MEM_WIDTH-1:0] rd_data;
reg          [MEM_WIDTH-1:0] mem_array [MEM_DEPTH-1:0];

integer i;
always@(posedge wr_clk or negedge wr_rst_n)
begin
  if(!wr_rst_n)
    for(i=0;i<MEM_DEPTH;i=i+1)
    begin
      mem_array[i]<={MEM_WIDTH{1'b0}};
    end
  else if(wr_en)
    mem_array[wr_addr]<=wr_data;
end

always@(posedge rd_clk or negedge rd_rst_n)
begin
  if(!rd_rst_n)
    rd_data<={MEM_WIDTH{1'b0}};
  else if(rd_en)
    rd_data<= mem_array[rd_addr];
end
  
endmodule

//***********************************************************************
//    Copyright (c) 2016 Corigine, Inc.
//    All Rights Reserved.
//***********************************************************************
//-----------------------------------------------------------------------
// File:        two_ports_sync_mem.v
// Created:     16:41:05, Mar 17, 2016
//-----------------------------------------------------------------------
// Abstract:    Two ports memory model, write and read ports are in same
//              clock domain
//
//-----------------------------------------------------------------------

module two_ports_sync_mem(
        clk,
        rst_n,
        //read port
        rd_en,
        rd_addr,
        rd_data,
        //write port
        wr_en,
        wr_addr,
        wr_data
        );

parameter MEM_WIDTH = 64;
parameter MEM_ADDR_WIDTH = 10;
parameter MEM_DEPTH = 1<<MEM_ADDR_WIDTH;
input        clk;
input        rst_n;
     //read port
input        rd_en;
input        [MEM_ADDR_WIDTH-1:0] rd_addr;
output       [MEM_WIDTH-1:0] rd_data;
     //write port
input        wr_en;
input        [MEM_ADDR_WIDTH-1:0] wr_addr;
input        [MEM_WIDTH-1:0] wr_data;


reg          [MEM_WIDTH-1:0] rd_data;
reg          [MEM_WIDTH-1:0] mem_array [MEM_DEPTH-1:0];

integer i;
always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    for(i=0;i<MEM_DEPTH;i=i+1)
    begin
      mem_array[i]<={MEM_WIDTH{1'b0}};
    end
  else if(wr_en)
    mem_array[wr_addr]<=wr_data;
end

always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    rd_data<={MEM_WIDTH{1'b0}};
  else if(rd_en)
    rd_data<= mem_array[rd_addr];
end
  
endmodule
//***********************************************************************
//    Copyright (c) 2016 Corigine, Inc.
//    All Rights Reserved.
//***********************************************************************
//-----------------------------------------------------------------------
// File:        icg_cell_posedge.v
// Auther:      Qunzhao Tian (qunzhao@corigine.com)
// Created:     10:21:47, Oct 27, 2016
//-----------------------------------------------------------------------
// Abstract:    Latch Based Clock Gating - Posedge
//              The circuit employs a latch with inverted clock input and
//              a AND gate. The output clock is always clock gated HIGH 
//              when Enable is low
//
//-----------------------------------------------------------------------

module icg_cell_posedge
(
//input clock
input  wire clk_i,
//clock enable
input  wire clk_en,
//Test Mode
input  wire test,
//gated output clock
output wire clk_o
);

wire clk_i_inv; //invert version of the clk_i
wire enable;
reg  latch_enable; //latch ouput enable

assign clk_i_inv = !clk_i; 
assign enable = test || clk_en;

always @ (clk_i_inv or enable) begin
  if (clk_i_inv)
    latch_enable = enable;
end

assign clk_o = clk_i && latch_enable;

endmodule




//-----------------------------------------------------------------------
// File: crg_scanmux          
//-----------------------------------------------------------------------

module crg_scanmux ( 
output out,
input  scan_mode,
input  normal_in,
input  scan_in  
);


 scanmux u_scanmux ( .Z(out),	.S(scan_mode),	.A (normal_in),	.B(scan_in) );

endmodule
