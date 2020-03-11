module dcmi_pingpang (
    input rstn,
    input clk,
    input block_en,
    // wr
    output wr_rdy,
    input wr_req,
    input [31:0] wr_data,
    // rd
    output rd_rdy,
    input rd_req,
    output [31:0] rd_data
);

//---------------------------------------------------------------------------
// SIGNAL
//---------------------------------------------------------------------------
// reg
reg [31:0] d0, d1;
reg rptr, wptr, d0_busy, d1_busy;
//---------------------------------------------------------------------------
// WRITE
//---------------------------------------------------------------------------
wire wr_vld = wr_req & wr_rdy;
// wptr
always @(posedge clk or negedge rstn)
    if (~rstn)
        wptr <= 0;
    else if (~block_en)
        wptr <= 0;
    else if (wr_vld == 1)
        wptr <= ~wptr;
// wdata
always @(posedge clk or negedge rstn)
    if (~rstn) begin
        d0 <= 0;
        d1 <= 0;
    end
    else if (~block_en) begin
        d0 <= 0;
        d1 <= 0;
    end
    else if (wr_vld == 1) begin
        if (wptr == 0)
            d0 <= wr_data;
        else
            d1 <= wdata;
    end
//---------------------------------------------------------------------------
// READ
//---------------------------------------------------------------------------
wire rd_vld = rd_req & rd_rdy;
// rptr
always @(posedge clk or negedge rstn)
    if (~rstn)
        rptr <= 0;
    else if (~block_en)
        rptr <= 0;
    else if (rd_vld == 1)
        rptr <= ~rptr;
// d0_busy
always @(posedge clk or negedge rstn)
    if (~rstn)
        d0_busy <= 0;
    else if (~block_en)
        d0_busy <= 0;
    else if (wr_vld == 1 && wptr == 0)
        d0_busy <= 1;
    else if (rd_vld == && rptr == 0)
        d0_busy <= 0;
// d1_busy
always @(posedge clk or negedge rstn)
    if (~rstn)
        d1_busy <= 0;
    else if (~block_en)
        d1_busy <= 0;
    else if (wr_vld == 1 && wptr == 1)
        d1_busy <= 1;
    else if (rd_vld == && rptr == 1)
        d1_busy <= 0;
//---------------------------------------------------------------------------
// OUTPUT
//---------------------------------------------------------------------------
assign wr_rdy = wptr ? ~d1_busy : ~d0_busy; // when buffer empty, w ready assert
assign rd_rdy = rptr ?  d1_busy :  d0_busy; // when buffer filled, r ready assert
assign rd_data = rptr ? d1 : d0;

endmodule

