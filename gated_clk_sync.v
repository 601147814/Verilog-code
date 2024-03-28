module gated_clk_sync ( QCK,   E,	TE,	CK );
output	QCK;
input E;       // clock enable
input TE;      // test enable
input CK;

reg     E_ff;
initial #10 E_ff = 0;
always @( CK or E or TE ) begin
    casex( {CK,(E | TE)} )
        2'b1x: begin end
        2'b00: E_ff = 1'b0;
        2'b01: E_ff = 1'b1;
    endcase
end
assign  QCK = E_ff & CK;
endmodule
