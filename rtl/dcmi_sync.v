module dcmi_sync (
    input rstn, clk, din,
    output dout
);
// dly
reg [1:0] din_dly;
always @(posedge clk or negedge rstn)
    if (~rstn)
        din_dly <= 0;
    else
        din_dly <= {din_dly[0], din};
// output
assign dout = din_dly[1];

endmodule

