
// 20200311, file created
module dcmi_top (
    //-----------------------------------------------------------------------
    //  Sys
    //-----------------------------------------------------------------------
    input                       rstn,
    input                       hclk,
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
    output          [23:0]      ram_waddr,
    output          [31:0]      ram_wdata
);

//---------------------------------------------------------------------------
// signals
//---------------------------------------------------------------------------
// misc
wire rstn_dcmi; reg [1:0] rstn_pclk_dly;
wire dcmi_ctrl_vld; wire [31:0] dcmi_ctrl_dout;
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
wire            snapshot_mode;
wire            capture_en;
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
wire [17:0]     dma_saddr;   // 18-bit, 256KB
wire [17:0]     dma_len;    // 18-bit, 256KB
// irq
wire line_irq_pulse_dcmi, line_irq_pulse_hclk;
wire fs_irq_pulse_dcmi, fs_irq_pulse_hclk;
wire err_irq_pulse_dcmi, err_irq_pulse_hclk;
wire fe_irq_pulse_dcmi, fe_irq_pulse_hclk;

// capture_en

// dcmi_pclk polarity processed here!!! tbd!!!

// rstn
always @(posedge dcmi_pclk or negedge rstn)
    if (~rstn)
        rstn_pclk_dly <= 0;
    else
        rstn_pclk_dly <= {rstn_pclk_dly[0], 1'b1};
assign rstn_dcmi = rstn_pclk_dly[1];
// dcmi_reg
dcmi_reg u_dcmi_reg (
    .rstn                   ( rstn                  ),
    .hclk                   ( hclk                  ),
    .ahb_bus_sel            ( ahb_bus_sel           ),
    .ahb_bus_wr             ( ahb_bus_wr            ),
    .ahb_bus_rd             ( ahb_bus_rd            ),
    .ahb_bus_addr           ( ahb_bus_addr          ),
    .ahb_bus_bsel           ( ahb_bus_bsel          ),
    .ahb_bus_wdata          ( ahb_bus_wdata         ),
    .ahb_bus_rdata          ( ahb_bus_rdata         ),
    .block_en               ( block_en              ),
    .capture_en             ( capture_en            ),
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
    .dcmi_dma_saddr         ( dcmi_dma_saddr        ),
    .dcmi_dma_len           ( dcmi_dma_len          ),
    .line_irq_pulse         ( line_irq_pulse_hclk   ),  // irq
    .fs_irq_pulse           ( fs_irq_pulse_hclk     ),
    .err_irq_pulse          ( err_irq_pulse_hclk    ),
    .fe_irq_pulse           ( fe_irq_pulse_hclk     ),
);
// dcmi_ctrl
dcmi_ctrl u_dcmi_ctrl (
    .rstn                   ( rstn_dcmi             ), // need sync
    .dcmi_pclk              ( dcmi_pclk             ),
    .dcmi_vsync             ( dcmi_vsync            ),
    .dcmi_hsync             ( dcmi_hsync            ),
    .dcmi_data              ( dcmi_data             ),
    .block_en               ( block_en              ), // need sync
    .capture_en             ( capture_en            ), // need sync
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
    .line_irq_pulse         ( line_irq_pulse_dcmi   ), // irq
    .frame_start_irq_pulse  ( fs_irq_pulse_dcmi     ),
    .err_irq_pulse          ( err_irq_pulse_dcmi    ),
    .frame_end_irq_pulse    ( fe_irq_pulse          ),
    .dout_vld               ( dcmi_ctrl_vld         ), // to dma
    .dout                   ( dcmi_ctrl_dout        )
);
// dcmi_dma
dcmi_dma u_dcmi_dma (
    .rstn                   ( rstn                  ),
    .clk                    ( clk                   ),
    .dcmi_start             ( dcmi_start            ),
    .dcmi_vld               ( dcmi_ctrl_vld         ),
    .dcmi_data              ( dcmi_ctrl_dout        ),
    .dma_saddr              ( dma_saddr             ),
    .dma_len                ( dma_len               ),
    .ovfl_err               ( ovfl_err              ),
    .ppbuf_empty            ( ppbuf_empty           ),
    .ppbuf_valid            ( ppbuf_valid           ),
    .ram_wr_req             ( ram_wr_req            ),
    .ram_wr_ack             ( ram_wr_ack            ),
    .ram_waddr              ( ram_waddr             ),
    .ram_wdata              ( ram_wdata             )
);
// line_irq
dcmi_psync u_psync_line (
    .srstn                  ( rstn                  ),
    .sclk                   ( hclk                  ),
    .sin                    ( line_irq_pulse_dcmi   ),
    .drstn                  ( rstn_dcmi             ),
    .dclk                   ( dcmi_pclk             ),
    .dout                   ( line_irq_pulse_hclk   )
);
// fs_irq
dcmi_psync u_psync_fs (
    .srstn                  ( rstn                  ),
    .sclk                   ( hclk                  ),
    .sin                    ( fs_irq_pulse_dcmi     ),
    .drstn                  ( rstn_dcmi             ),
    .dclk                   ( dcmi_pclk             ),
    .dout                   ( fs_irq_pulse_hclk     )
);
// err_irq
dcmi_psync u_psync_err (
    .srstn                  ( rstn                  ),
    .sclk                   ( hclk                  ),
    .sin                    ( err_irq_pulse_dcmi    ),
    .drstn                  ( rstn_dcmi             ),
    .dclk                   ( dcmi_pclk             ),
    .dout                   ( err_irq_pulse_hclk    )
);
// fe_irq
dcmi_psync u_psync_fe (
    .srstn                  ( rstn                  ),
    .sclk                   ( hclk                  ),
    .sin                    ( fe_irq_pulse_dcmi     ),
    .drstn                  ( rstn_dcmi             ),
    .dclk                   ( dcmi_pclk             ),
    .dout                   ( fe_irq_pulse_hclk     )
);

endmodule

