
// 20200311, file created

module dcmi_dma (
    // ahb
    input                               rstn,
    input                               clk,
    // from dcmi ctrl
    input                               dcmi_start,
    input                               dcmi_vld,
    input       [31:0]                  dcmi_data,
    // registers
    input       [`DMA_ADDR_LEN-1:0]     dma_saddr,
    input       [`DMA_ADDR_LEN-1:0]     dma_len,
    output reg                          ovfl_err,
    output                              ppbuf_empty,
    output                              ppbuf_valid,
    // ram port
    output                              ram_wr_req,
    input                               ram_wr_ack,
    output reg  [`DMA_ADDR_LEN-1:0]     ram_waddr,
    output      [31:0]                  ram_wdata
);
// wires
wire ppbuf_wr_rdy, ppbuf_wr_req, ppbuf_wr_err;
wire ppbuf_rd_rdy, ppbuf_rd_req;
wire [31:0] ppbuf_wr_data, ppbuf_rd_data;
// ram_waddr
always @(posedge clk or negedge rstn)
    if (~rstn)
        ram_waddr <= 0;
    else if (~block_en)
        ram_waddr <= 0;
    else if (dcmi_start)
        ram_waddr <= dma_saddr;
    else if (ram_wr_req == 1 && ram_wr_ack == 1) begin
        if (ram_waddr == (dma_saddr + dma_len - 1))
            ram_waddr <= dma_saddr;
        else
            ram_waddr <= ram_waddr + 1;
    end
// ppbuf write
assign ppbuf_wr_req = dcmi_vld;
assign ppbuf_wr_data = dcmi_data;
assign ppbuf_wr_err = dcmi_vld & ~ppbuf_wr_rdy; // overflow
// ppbuf read
assign ram_wr_req = ppbuf_rd_rdy;
assign ram_wdata = ppbuf_rd_data;
assign ppbuf_rd_req = ram_wr_req & ram_wr_ack; // when write finish, switch buffer
// ovfl_err
always @(posedge clk or negedge rstn)
    if (~rstn)
        ovfl_err <= 0;
    else if (~block_en)
        ovfl_err <= 0;
    else if (dcmi_start)
        ovfl_err <= 0;
    else if (ppbuf_wr_err) begin
        ovfl_err <= 1;
assign ppbuf_empty = ppbuf_wr_rdy;
assign ppbuf_valid = ppbuf_rd_rdy;
// inst ppbuf
dcmi_pingpang u_ppbuf (
    .rstn           ( rstn              ),
    .clk            ( clk               ),
    .block_en       ( block_en          ),
    .wr_rdy         ( ppbuf_wr_rdy      ),
    .wr_req         ( ppbuf_wr_req      ),
    .wr_data        ( ppbuf_wr_data     ),
    .rd_rdy         ( ppbuf_rd_rdy      ),
    .rd_req         ( ppbuf_rd_req      ),
    .rd_data        ( ppbuf_rd_data     )
);

endmodule

