// -----------------------------------------------------------
// Glitch Free Clock Mux
// -----------------------------------------------------------
// This module is a 2:1 mux that switches between two
// clocks in such a way has to not produce glitches
//
// Note: clk1 is assumed to be the master clock to which
//       the select signal is sync'd
module sync_mux( clk1, clk1_res_n, clk2, clk2_res_n, sel, clk_out, test_mode, scan_clk, clk_sel_out );
input   clk1;
input   clk1_res_n;
input   clk2;
input   clk2_res_n;
input   sel;        
output  clk_out;
input   test_mode;
input   scan_clk;
output  clk_sel_out;

wire        clk1_tm, clk2_tm;
scanclkmux  u_clk1_tm  ( .S(test_mode), .A(clk1), .B(scan_clk), .Z(clk1_tm));
scanclkmux  u_clk2_tm  ( .S(test_mode), .A(clk2), .B(scan_clk), .Z(clk2_tm));

// ------------------------------------
// Detect change in mux selection
// -------------------------------------
reg     sel_sync, sel_sync_d1, sel_sync_d2, sel_sync_d3;
wire    sel_change = (sel_sync_d1 != sel_sync_d2);
always @(posedge clk1_tm or negedge clk1_res_n) begin
    if(~clk1_res_n) begin
        sel_sync <= 1'b0;
        sel_sync_d1 <= 1'b0;
        sel_sync_d2 <= 1'b0;
        sel_sync_d3 <= 1'b0;
    end else begin
        sel_sync <= sel;
        sel_sync_d1 <= sel_sync;
        sel_sync_d2 <= sel_sync_d1;
        sel_sync_d3 <= sel_sync_d2;
    end
end


// ---------------------------------------
// State Machine
// ---------------------------------------
// There are two states:  IDLE and DISABLED

reg         clk1_clk1_enable_d2;     // Sync'd with the clk1_tm domain
reg         clk1_clk2_enable_d2;     // Sync'd with the clk1_tm domain
reg         clk_selection;

reg         state, nstate;
parameter   STATE_IDLE      = 0,
            STATE_DISABLE   = 1;
reg         nall_off;
reg         nset_clk_enable;

always @( state or sel_change or clk1_clk1_enable_d2 or clk1_clk2_enable_d2 ) begin
    nstate          <= state;
    nall_off        <= 1'b0;
    nset_clk_enable <= 1'b0;
    
    case( state )
        STATE_IDLE: begin
                if( sel_change ) begin
                    nstate      <= STATE_DISABLE;
                    nall_off    <= 1'b0;
                end
            end
        STATE_DISABLE: begin
                nall_off    <= 1'b1;    // hold all clocks off until both are off
                if( ~clk1_clk1_enable_d2 & ~clk1_clk2_enable_d2 ) begin
                    nset_clk_enable <= 1'b1;
                    nstate          <= STATE_IDLE;
                end
            end
        default: nstate <= STATE_IDLE;
    endcase
end

always @( posedge clk1_tm or negedge clk1_res_n ) begin
    if( ~clk1_res_n ) begin
        state           <= STATE_IDLE;
        clk_selection   <= 1'b0;    // 0 = clk1_tm selected, 1 = clk2_tm selected
    end else begin
        state   <= nstate;
        if( nset_clk_enable ) begin
            clk_selection  <= sel_sync_d1;
        end
    end
end

// ------------------------------------
// Enable/Disable Clock 1 in its domain
// -------------------------------------
reg     clk1_clk1_enable_d1;
// Used to cross 'clk2_tm' clk enable to 'clk1_tm' domain
reg     clk2_clk_enable_d2;
reg     clk1_clk2_enable_sync;
reg     clk1_clk2_enable_d1;  
always @( posedge clk1_tm or negedge clk1_res_n ) begin
    if( ~clk1_res_n ) begin
        clk1_clk1_enable_d1      <= 1'b1;
        clk1_clk1_enable_d2      <= 1'b1;
        // Used to cross 'clk2_tm' clk enable to 'clk1_tm' domain
        clk1_clk2_enable_sync   <= 1'b0;
        clk1_clk2_enable_d1     <= 1'b0;
        clk1_clk2_enable_d2     <= 1'b0;
    end else begin
        clk1_clk1_enable_d1 <= ~nall_off & (clk_selection == 1'b0); // used to drive the gated clock libary cell
        clk1_clk1_enable_d2 <= clk1_clk1_enable_d1;
        // Used to cross 'clk2_tm' clk enable to 'clk1_tm' domain
        clk1_clk2_enable_sync   <= clk2_clk_enable_d2;              // from 'clk2_tm' clock domain 
        clk1_clk2_enable_d1     <= clk1_clk2_enable_sync;
        clk1_clk2_enable_d2     <= clk1_clk2_enable_d1;
    end
end

// ------------------------------------
// Enable/Disable Clock 2 in its domain
// -------------------------------------
reg clk2_clk_enable_sync;
reg clk2_clk_enable_d1;

always @(posedge clk2_tm or negedge clk2_res_n) begin
    if( ~clk2_res_n ) begin
        clk2_clk_enable_sync   <= 1'b0;
        clk2_clk_enable_d1     <= 1'b0;
        clk2_clk_enable_d2     <= 1'b0;
    end else begin
        clk2_clk_enable_sync   <= ~nall_off & (clk_selection == 1'b1);
        clk2_clk_enable_d1     <= clk2_clk_enable_sync; // used to drive the gated clock libary cell
        clk2_clk_enable_d2     <= clk2_clk_enable_d1;
    end
end


wire    clk1_clk_gated;
wire    clk1_gate_en = clk1_clk1_enable_d1;   // for hold time of library cell
// clk1_tm Gated clock
gated_clk_sync u_gated_clk1(    .QCK(clk1_clk_gated), 
                                .E(clk1_gate_en),	
                                .TE( test_mode),	
                                .CK(clk1_tm) );
// clk2_tm Gated clock
// Use sync gated clock since we sync the enable to clk2_tm above and
// we use the _d2 version to assume the clock is actually disabled
wire    clk2_clk_gated;
wire    clk2_gate_en = clk2_clk_enable_d1;   // for hold time of library cell
gated_clk_sync u_gated_clk2(    .QCK(clk2_clk_gated), 
                                .E(clk2_gate_en),	
                                .TE( test_mode),	
                                .CK(clk2_tm) );

/* synopsys dc_script_begin
	set_dont_touch u_sync_mux_test_mode
*/
// clk_selection only changes when both clocks are OFF.  That's a good
// time to mux the clock before we enable it on the way out.
wire    final_clk;
clkmux      u_final_clk_clkmux   (.S(clk_selection), .A(clk1_clk_gated), .B(clk2_clk_gated), .Z(final_clk));
scanclkmux  u_sync_mux_test_mode (.S(test_mode),     .A(final_clk),      .B(scan_clk),       .Z(clk_out));

// Export an output so that the flip-flops in this module can be included in scan
// OR this signal with a flip-flop path in the module above.  During SCAN this
// will be data.  During normal chip mode this signal will be 0
assign      clk_sel_out = clk_selection;



endmodule
