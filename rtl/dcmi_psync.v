module dcmi_psync (
    input srstn, sclk, sin,
    input drstn, dclk,
    output dout
);
// source toggle
reg stoggle;
always @(posedge sclk or negedge srstn)
    if (~srstn)
        stoggle <= 0;
    else if (sin)
        stoggle <= ~stoggle;
// cross clock domain
reg [2:0] stoggle_dly;
always @(posedge dclk or negedge drstn)
    if (~drstn)
        stoggle_dly <= 0;
    else
        stoggle_dly <= {stoggle_dly[1:0], stoggle};
// edge
assign dout = stoggle_dly[2] ^ stoggle_dly[1];

endmodule

