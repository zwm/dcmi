
// 20200311, file created

module dcmi_reg (
    //-----------------------------------------------------------------------
    //  Sys
    //-----------------------------------------------------------------------
    input                       rstn,
    input                       hclk,
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
    //  Registers
    //-----------------------------------------------------------------------
    // DCMI_CR
    output reg                  block_en,
    output reg                  capture_en,
    output reg                  snapshot_mode,
    output reg                  crop_en,
    output reg                  jpeg_en,
    output reg                  embd_sync_en,
    output reg                  pclk_polarity,
    output reg                  hsync_polarity,
    output reg                  vsync_polarity,
    output reg  [1:0]           data_bus_width,         // 00: 8-bit, 01: 10-bit, 10: 12-bit, 11: 14-bit
    output reg  [1:0]           frame_sel_mode,      // 00: all, 01: 1/2, 10: 1/4, 11: reserved
    output reg  [1:0]           byte_sel_mode,       // 00: all, 01: 1/2, 10: 1/4, 11: 2/4
    output reg                  line_sel_mode,       // 0: all, 1: 1/2
    output reg                  byte_sel_start,      // 0: 1st, 1: 2nd
    output reg                  line_sel_start,      // 0: 1st, 1: 2nd
    // DCMI_ESCR
    output reg  [7:0]           fec,
    output reg  [7:0]           lec,
    output reg  [7:0]           lsc,
    output reg  [7:0]           fsc,
    // DCMI_ESUR
    output reg  [7:0]           feu,
    output reg  [7:0]           leu,
    output reg  [7:0]           lsu,
    output reg  [7:0]           fsu,
    // DCMI_CWSTRT
    output reg  [13:0]          line_crop_start,
    output reg  [13:0]          pixel_crop_start,
    // DCMI_CWSIZE
    output reg  [13:0]          line_crop_size,
    output reg  [13:0]          pixel_crop_size,
    // DCMI_DMA
    output reg  [17:0]          dcmi_dma_saddr,
    output reg  [17:0]          dcmi_dma_len,
    //-----------------------------------------------------------------------
    //  Output
    //-----------------------------------------------------------------------
    // irq
    output                      line_irq_pulse,
    output                      frame_start_irq_pulse,
    output                      err_irq_pulse,
    output                      frame_end_irq_pulse,
);

// 0: DCMI_CR
always @(posedge hclk or negedge rstn)
    if (~rstn) begin
        line_sel_start      <= 0;
        line_sel_mode       <= 0;
        byte_sel_start      <= 0;
        byte_sel_mode       <= 0;
        data_bus_width      <= 0;
        frame_sel_mode      <= 0;
        vsync_polarity      <= 0;
        hsync_polarity      <= 0;
        pclk_polarity       <= 0;
        embd_sync_en        <= 0;
        jpeg_en             <= 0;
        crop_en             <= 0;
        snapshot_mode       <= 0;
        capture_en          <= 0;
    end
    else if (ahb_bus_sel & ahb_bus_wr & ahb_bus_addr == 0) begin
        if (ahb_bus_bsel[3]) begin // [31:24]
            // rfu
        end
        if (ahb_bus_bsel[2]) begin // [23:16]
            line_sel_start      <= ahb_bus_wdata[20];      // 0: 1st, 1: 2nd
            line_sel_mode       <= ahb_bus_wdata[19];      // 0: all, 1: 1/2
            byte_sel_start      <= ahb_bus_wdata[18];      // 0: 1st, 1: 2nd
            byte_sel_mode       <= ahb_bus_wdata[17:16];   // 00: all, 01: 1/2, 10: 1/4, 11: 2/4
        end
        if (ahb_bus_bsel[1]) begin // [15: 8]
            data_bus_width      <= ahb_bus_wdata[11:10];   // 00: 8-bit, 01: 10-bit, 10: 12-bit, 11: 14-bit
            frame_sel_mode      <= ahb_bus_wdata[9:8];     // 00: all, 01: 1/2, 10: 1/4, 11: reserved
        end
        if (ahb_bus_bsel[0]) begin // [ 7: 0]
            vsync_polarity      <= ahb_bus_wdata[7];
            hsync_polarity      <= ahb_bus_wdata[6];
            pclk_polarity       <= ahb_bus_wdata[5];
            embd_sync_en        <= ahb_bus_wdata[4];
            jpeg_en             <= ahb_bus_wdata[3];
            crop_en             <= ahb_bus_wdata[2];
            snapshot_mode       <= ahb_bus_wdata[1];
            capture_en          <= ahb_bus_wdata[0];
        end
    end
// 1: DCMI_ESCR
always @(posedge hclk or negedge rstn)
    if (~rstn) begin
        fec                 <= 0;
        lec                 <= 0;
        lsc                 <= 0;
        fsc                 <= 0;
    end
    else if (ahb_bus_sel & ahb_bus_wr & ahb_bus_addr == 1) begin
        if (ahb_bus_bsel[3]) begin // [31:24]
            fec                 <= ahb_bus_wdata[31:24];
        end
        if (ahb_bus_bsel[2]) begin // [23:16]
            lec                 <= ahb_bus_wdata[23:16];
        end
        if (ahb_bus_bsel[1]) begin // [15: 8]
            lsc                 <= ahb_bus_wdata[15: 8];
        end
        if (ahb_bus_bsel[0]) begin // [ 7: 0]
            fsc                 <= ahb_bus_wdata[ 7: 0];
        end
    end
// 2: DCMI_ESUR
always @(posedge hclk or negedge rstn)
    if (~rstn) begin
        feu                 <= 0;
        leu                 <= 0;
        lsu                 <= 0;
        fsu                 <= 0;
    end
    else if (ahb_bus_sel & ahb_bus_wr & ahb_bus_addr == 1) begin
        if (ahb_bus_bsel[3]) begin // [31:24]
            feu                 <= ahb_bus_wdata[31:24];
        end
        if (ahb_bus_bsel[2]) begin // [23:16]
            leu                 <= ahb_bus_wdata[23:16];
        end
        if (ahb_bus_bsel[1]) begin // [15: 8]
            lsu                 <= ahb_bus_wdata[15: 8];
        end
        if (ahb_bus_bsel[0]) begin // [ 7: 0]
            fsu                 <= ahb_bus_wdata[ 7: 0];
        end
    end
// 3: DCMI_CWSTRT
always @(posedge hclk or negedge rstn)
    if (~rstn) begin
        line_crop_start     <= 0;
        pixel_crop_start    <= 0;
        dcmi_dma_saddr[17:16] <= 0;
        dcmi_dma_len[17:16] <= 0;
    end
    else if (ahb_bus_sel & ahb_bus_wr & ahb_bus_addr == 1) begin
        if (ahb_bus_bsel[3]) begin // [31:24]
            dcmi_dma_saddr[17:16] <= ahb_bus_wdata[31:30];
            line_crop_start[13:8] <= ahb_bus_wdata[29:24];
        end
        if (ahb_bus_bsel[2]) begin // [23:16]
            line_crop_start[7:0] <= ahb_bus_wdata[23:16];
        end
        if (ahb_bus_bsel[1]) begin // [15: 8]
            dcmi_dma_len[17:16] <= ahb_bus_wdata[15:14];
            pixel_crop_start[13:8] <= ahb_bus_wdata[13:8];
        end
        if (ahb_bus_bsel[0]) begin // [ 7: 0]
            pixel_crop_start[7:0] <= ahb_bus_wdata[7:0];
        end
    end
// 4: DCMI_DMA_ADDR
always @(posedge hclk or negedge rstn)
    if (~rstn) begin
        dcmi_dma_saddr[15:0] <= 0;
        dcmi_dma_len[15:0] <= 0;
    end
    else if (ahb_bus_sel & ahb_bus_wr & ahb_bus_addr == 1) begin
        if (ahb_bus_bsel[3]) begin // [31:24]
            dcmi_dma_saddr[15:8] <= ahb_bus_wdata[31:24];
        end
        if (ahb_bus_bsel[2]) begin // [23:16]
            dcmi_dma_saddr[ 7:0] <= ahb_bus_wdata[23:16];
        end
        if (ahb_bus_bsel[1]) begin // [15: 8]
             dcmi_dma_len[15:8] <= ahb_bus_wdata[15: 8];
        end
        if (ahb_bus_bsel[0]) begin // [ 7: 0]
             dcmi_dma_len[ 7:0] <= ahb_bus_wdata[ 7: 0];
        end
    end
// 2: DCMI_ESUR
always @(posedge hclk or negedge rstn)
    if (~rstn) begin
        feu                 <= 0;
        leu                 <= 0;
        lsu                 <= 0;
        fsu                 <= 0;
    end
    else if (ahb_bus_sel & ahb_bus_wr & ahb_bus_addr == 1) begin
        if (ahb_bus_bsel[3]) begin // [31:24]
            feu                 <= ahb_bus_wdata[31:24];
        end
        if (ahb_bus_bsel[2]) begin // [23:16]
            leu                 <= ahb_bus_wdata[23:16];
        end
        if (ahb_bus_bsel[1]) begin // [15: 8]
            lsu                 <= ahb_bus_wdata[15: 8];
        end
        if (ahb_bus_bsel[0]) begin // [ 7: 0]
            fsu                 <= ahb_bus_wdata[ 7: 0];
        end
    end
// 2: DCMI_ESUR
always @(posedge hclk or negedge rstn)
    if (~rstn) begin
        feu                 <= 0;
        leu                 <= 0;
        lsu                 <= 0;
        fsu                 <= 0;
    end
    else if (ahb_bus_sel & ahb_bus_wr & ahb_bus_addr == 1) begin
        if (ahb_bus_bsel[3]) begin // [31:24]
            feu                 <= ahb_bus_wdata[31:24];
        end
        if (ahb_bus_bsel[2]) begin // [23:16]
            leu                 <= ahb_bus_wdata[23:16];
        end
        if (ahb_bus_bsel[1]) begin // [15: 8]
            lsu                 <= ahb_bus_wdata[15: 8];
        end
        if (ahb_bus_bsel[0]) begin // [ 7: 0]
            fsu                 <= ahb_bus_wdata[ 7: 0];
        end
    end

endmodule

