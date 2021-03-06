
// 20200311, file created
module dcmi_top (
    //-----------------------------------------------------------------------
    //  Sys
    //-----------------------------------------------------------------------
    input                       rstn,
    input                       hclk,
    input                       ram_clk,
    //-----------------------------------------------------------------------
    //  DCMI Interface
    //-----------------------------------------------------------------------
    // dcmi port
    input                       dcmi_pclk,
    input                       dcmi_vsync,
    input                       dcmi_hsync,
    input [13:0]                dcmi_data,   // support 8/10/12/14 bit
    //-----------------------------------------------------------------------
    //  ahb bus
    //-----------------------------------------------------------------------
    input                       ahb_bus_sel,
    input                       ahb_bus_wr,
    input                       ahb_bus_rd,
    input           [ 3:0]      ahb_bus_addr,
    input           [ 3:0]      ahb_bus_bsel,
    input           [31:0]      ahb_bus_wdata,
    output          [31:0]      ahb_bus_rdata,
    //-----------------------------------------------------------------------
    //  Output
    //-----------------------------------------------------------------------
    // irq
    output                      dcmi_irq,
    // ram
    output                      ram_wr_req,
    input                       ram_wr_ack,
    output          [19:0]      ram_waddr,
    output          [31:0]      ram_wdata
);

//---------------------------------------------------------------------------
// signals
//---------------------------------------------------------------------------
// misc
wire rstn_dcmi; reg [1:0] rstn_pclk_dly;
wire dw_out_vld_dcmi, dw_out_vld_ram_clk; wire [31:0] dw_out; // data word, if no handshake, data change while sync will not be observed!!!
wire frame_end_hclk;
wire [4:0] dcmi_ris, dcmi_ier, dcmi_mis, dcmi_icr;
wire ppbuf_valid, ppbuf_empty;
// DCMI_CR
wire            line_sel_start;      // 0: 1st, 1: 2nd
wire            line_sel_mode;      // 0: all, 1: 1/2
wire            byte_sel_start;      // 0: 1st, 1: 2nd
wire [1:0]      byte_sel_mode;   // 00: all, 01: 1/2, 10: 1/4, 11: 2/4
wire            block_en;
wire [1:0]      data_bus_width;   // 00: 8-bit, 01: 10-bit, 10: 12-bit, 11: 14-bit
wire [1:0]      frame_sel_mode;     // 00: all, 01: 1/2, 10: 1/4, 11: reserved
wire            vsync_polarity;
wire            hsync_polarity;
wire            pclk_polarity;
wire            embd_sync_en;
wire            jpeg_en;
wire            crop_en;
wire            man_mode;
wire            mcu_rd_dr;
wire            snapshot_mode;
wire            capture_en;
wire            capture_start;
// DCMI_ESCR
wire [7:0]      fec;
wire [7:0]      lec;
wire [7:0]      lsc;
wire [7:0]      fsc;
// DCMI_ESUR
wire [7:0]      feu;
wire [7:0]      leu;
wire [7:0]      lsu;
wire [7:0]      fsu;
// DCMI_CWSTRT
wire [13:0]     line_crop_start;
wire [13:0]     pixel_crop_start;
// DCMI_CWSIZE
wire [13:0]     line_crop_size;
wire [13:0]     pixel_crop_size;
// DCMI_DMA
wire [17:0]     dma_saddr; // 18-bit, 256K*4B = 1MB
wire [17:0]     dma_len; // 18-bit, 256KB
// irq
wire line_irq_pulse_dcmi, line_irq_pulse_hclk;
wire fs_irq_pulse_dcmi, fs_irq_pulse_hclk;
wire err_irq_pulse_dcmi, err_irq_pulse_hclk;
wire fe_irq_pulse_dcmi, fe_irq_pulse_hclk;
wire ovfl_irq_pulse_hclk, ovfl_irq_pulse_ram_clk;
// en
wire capture_en_hclk, capture_en_dcmi;
wire block_en_hclk, block_en_dcmi, block_en_ram_clk;
wire capture_start_ram_clk;
// dcmi_pclk polarity processed here!!! tbd!!!
wire pclk;
assign pclk = dcmi_pclk ^ pclk_polarity;
// rstn
always @(posedge pclk or negedge rstn)
    if (~rstn)
        rstn_pclk_dly <= 0;
    else
        rstn_pclk_dly <= {rstn_pclk_dly[0], 1'b1};
assign rstn_dcmi = rstn_pclk_dly[1];
// block_en
assign block_en_hclk = block_en;
//---------------------------------------------------------------------------
// CLK DOMAIN: PCLK
//---------------------------------------------------------------------------
// dcmi_ctrl
dcmi_ctrl u_dcmi_ctrl (
    .rstn                   ( rstn_dcmi             ), // need sync
    .pclk                   ( pclk                  ),
    .dcmi_vsync             ( dcmi_vsync            ),
    .dcmi_hsync             ( dcmi_hsync            ),
    .dcmi_data              ( dcmi_data             ),
    .block_en               ( block_en_dcmi         ), // need sync
    .capture_en             ( capture_en_dcmi       ), // need sync
    .snapshot_mode          ( snapshot_mode         ),
    .crop_en                ( crop_en               ),
    .jpeg_en                ( jpeg_en               ),
    .embd_sync_en           ( embd_sync_en          ),
//    .pclk_polarity          ( pclk_polarity         ),
    .hsync_polarity         ( hsync_polarity        ),
    .vsync_polarity         ( vsync_polarity        ),
    .data_bus_width         ( data_bus_width        ),
    .frame_sel_mode         ( frame_sel_mode        ),
    .byte_sel_mode          ( byte_sel_mode         ),
    .line_sel_mode          ( line_sel_mode         ),
    .byte_sel_start         ( byte_sel_start        ),
    .line_sel_start         ( line_sel_start        ),
    .fec                    ( fec                   ),
    .lec                    ( lec                   ),
    .lsc                    ( lsc                   ),
    .fsc                    ( fsc                   ),
    .feu                    ( feu                   ),
    .leu                    ( leu                   ),
    .lsu                    ( lsu                   ),
    .fsu                    ( fsu                   ),
    .line_crop_start        ( line_crop_start       ),
    .pixel_crop_start       ( pixel_crop_start      ),
    .line_crop_size         ( line_crop_size        ),
    .pixel_crop_size        ( pixel_crop_size       ),
    .line_irq_pulse         ( line_irq_pulse_dcmi   ), // irq
    .frame_start_irq_pulse  ( fs_irq_pulse_dcmi     ),
    .err_irq_pulse          ( err_irq_pulse_dcmi    ),
    .frame_end_irq_pulse    ( fe_irq_pulse_dcmi     ),
    .dout_vld               ( dw_out_vld_dcmi       ), // to dma
    .dout                   ( dw_out                )
);
// dw_out_vld_ram_clk
dcmi_psync u_psync_vld (
    .srstn                  ( rstn_dcmi             ),
    .sclk                   ( pclk                  ),
    .sin                    ( dw_out_vld_dcmi       ),
    .drstn                  ( rstn                  ),
    .dclk                   ( ram_clk               ),
    .dout                   ( dw_out_vld_ram_clk    )
);
// line_irq
dcmi_psync u_psync_line (
    .srstn                  ( rstn                  ),
    .sclk                   ( hclk                  ),
    .sin                    ( line_irq_pulse_dcmi   ),
    .drstn                  ( rstn_dcmi             ),
    .dclk                   ( pclk                  ),
    .dout                   ( line_irq_pulse_hclk   )
);
// fs_irq
dcmi_psync u_psync_fs (
    .srstn                  ( rstn                  ),
    .sclk                   ( hclk                  ),
    .sin                    ( fs_irq_pulse_dcmi     ),
    .drstn                  ( rstn_dcmi             ),
    .dclk                   ( pclk                  ),
    .dout                   ( fs_irq_pulse_hclk     )
);
// err_irq
dcmi_psync u_psync_err (
    .srstn                  ( rstn                  ),
    .sclk                   ( hclk                  ),
    .sin                    ( err_irq_pulse_dcmi    ),
    .drstn                  ( rstn_dcmi             ),
    .dclk                   ( pclk                  ),
    .dout                   ( err_irq_pulse_hclk    )
);
// fe_irq
dcmi_psync u_psync_fe (
    .srstn                  ( rstn                  ),
    .sclk                   ( hclk                  ),
    .sin                    ( fe_irq_pulse_dcmi     ),
    .drstn                  ( rstn_dcmi             ),
    .dclk                   ( pclk                  ),
    .dout                   ( fe_irq_pulse_hclk     )
);
//---------------------------------------------------------------------------
// CLK DOMAIN: RAM
//---------------------------------------------------------------------------
// dcmi_dma
dcmi_dma u_dcmi_dma (
    .rstn                   ( rstn                  ),
    .clk                    ( ram_clk               ),
    .block_en               ( block_en_ram_clk      ),
    .man_mode               ( man_mode              ),
    .mcu_rd_dr              ( mcu_rd_dr             ),
    .capture_start          ( capture_start_ram_clk ),
    .dcmi_dw_vld            ( dw_out_vld_ram_clk    ),
    .dcmi_dw_out            ( dw_out                ),
    .dma_saddr              ( dma_saddr             ),
    .dma_len                ( dma_len               ),
    .ovfl_irq_pulse         ( ovfl_irq_pulse_ram_clk ),
    .ppbuf_empty            ( ppbuf_empty           ),
    .ppbuf_valid            ( ppbuf_valid           ),
    .ram_wr_req             ( ram_wr_req            ),
    .ram_wr_ack             ( ram_wr_ack            ),
    .ram_waddr              ( ram_waddr[19:2]       ),
    .ram_wdata              ( ram_wdata             )
);
assign ram_waddr[1:0] = 2'b00;
// ovfl irq pulse
dcmi_psync u_psync_ovfl_irq (
    .srstn                  ( rstn                  ),
    .sclk                   ( ram_clk               ),
    .sin                    ( ovfl_irq_pulse_ram_clk ),
    .drstn                  ( rstn                  ),
    .dclk                   ( hclk                  ),
    .dout                   ( ovfl_irq_pulse_hclk   )
);
//---------------------------------------------------------------------------
// CLK DOMAIN: HCLK
//---------------------------------------------------------------------------
// dcmi_reg
dcmi_reg u_dcmi_reg (
    .rstn                   ( rstn                  ),
    .hclk                   ( hclk                  ),
    .frame_end              ( fe_irq_pulse_hclk     ),
    .ahb_bus_sel            ( ahb_bus_sel           ),
    .ahb_bus_wr             ( ahb_bus_wr            ),
    .ahb_bus_rd             ( ahb_bus_rd            ),
    .ahb_bus_addr           ( ahb_bus_addr          ),
    .ahb_bus_bsel           ( ahb_bus_bsel          ),
    .ahb_bus_wdata          ( ahb_bus_wdata         ),
    .ahb_bus_rdata          ( ahb_bus_rdata         ),
    .block_en               ( block_en              ),
    .capture_en             ( capture_en            ),
    .capture_start          ( capture_start         ),
    .man_mode               ( man_mode              ),
    .mcu_rd_dr              ( mcu_rd_dr             ),
    .snapshot_mode          ( snapshot_mode         ),
    .crop_en                ( crop_en               ),
    .jpeg_en                ( jpeg_en               ),
    .embd_sync_en           ( embd_sync_en          ),
    .pclk_polarity          ( pclk_polarity         ),
    .hsync_polarity         ( hsync_polarity        ),
    .vsync_polarity         ( vsync_polarity        ),
    .data_bus_width         ( data_bus_width        ),
    .frame_sel_mode         ( frame_sel_mode        ),
    .byte_sel_mode          ( byte_sel_mode         ),
    .line_sel_mode          ( line_sel_mode         ),
    .byte_sel_start         ( byte_sel_start        ),
    .line_sel_start         ( line_sel_start        ),
    .fec                    ( fec                   ),
    .lec                    ( lec                   ),
    .lsc                    ( lsc                   ),
    .fsc                    ( fsc                   ),
    .feu                    ( feu                   ),
    .leu                    ( leu                   ),
    .lsu                    ( lsu                   ),
    .fsu                    ( fsu                   ),
    .line_crop_start        ( line_crop_start       ),
    .pixel_crop_start       ( pixel_crop_start      ),
    .line_crop_size         ( line_crop_size        ),
    .pixel_crop_size        ( pixel_crop_size       ),
    .dma_saddr              ( dma_saddr             ), // dma
    .dma_len                ( dma_len               ),
    .dcmi_ris               ( dcmi_ris              ), // irq
    .dcmi_ier               ( dcmi_ier              ),
    .dcmi_mis               ( dcmi_mis              ),
    .dcmi_icr               ( dcmi_icr              ),
    .dcmi_dr                ( ram_wdata             ), // DCMI_DR
    .dcmi_hsync             ( dcmi_hsync            ), // DCMI_SR
    .dcmi_vsync             ( dcmi_vsync            ),
    .dcmi_pclk              ( dcmi_pclk             ),
    .ppbuf_valid            ( ppbuf_valid           ),
    .ppbuf_empty            ( ppbuf_empty           )
);
// irq
dcmi_irq u_irq (
    .rstn                   ( rstn                  ),
    .clk                    ( hclk                  ),
    .line_irq_pulse         ( line_irq_pulse_hclk   ),
    .vsync_irq_pulse        ( fs_irq_pulse_hclk     ),
    .err_irq_pulse          ( err_irq_pulse_hclk    ),
    .ovfl_irq_pulse         ( ovfl_irq_pulse_hclk   ),
    .frame_end_irq_pulse    ( fe_irq_pulse_hclk     ),
    .dcmi_ris               ( dcmi_ris              ),
    .dcmi_ier               ( dcmi_ier              ),
    .dcmi_mis               ( dcmi_mis              ),
    .dcmi_icr               ( dcmi_icr              ),
    .dcmi_irq               ( dcmi_irq              )
);
dcmi_sync u_sync_block_en1 (
    .rstn                   ( rstn_dcmi             ),
    .clk                    ( pclk                  ),
    .din                    ( block_en_hclk         ),
    .dout                   ( block_en_dcmi         )
);
dcmi_sync u_sync_block_en2 (
    .rstn                   ( rstn                  ),
    .clk                    ( ram_clk               ),
    .din                    ( block_en_hclk         ),
    .dout                   ( block_en_ram_clk      )
);
// capture_start_ram_clk
dcmi_psync u_psync_capture_start (
    .srstn                  ( rstn                  ),
    .sclk                   ( hclk                  ),
    .sin                    ( capture_start         ),
    .drstn                  ( rstn_dcmi             ),
    .dclk                   ( ram_clk               ),
    .dout                   ( capture_start_ram_clk )
);
// capture_en
assign capture_en_hclk = capture_en;
dcmi_sync u_sync_capture_en (
    .rstn                   ( rstn_dcmi             ),
    .clk                    ( pclk                  ),
    .din                    ( capture_en_hclk       ),
    .dout                   ( capture_en_dcmi       )
);

endmodule

