
// 20200311, file created

module dcmi_reg (
    //-----------------------------------------------------------------------
    //  Sys
    //-----------------------------------------------------------------------
    input                       rstn,
    input                       hclk,
    input                       frame_end,
    //-----------------------------------------------------------------------
    //  ahb bus
    //-----------------------------------------------------------------------
    input                       ahb_bus_sel,
    input                       ahb_bus_wr,
    input                       ahb_bus_rd,
    input       [ 3:0]          ahb_bus_addr,
    input       [ 3:0]          ahb_bus_bsel,
    input       [31:0]          ahb_bus_wdata,
    output reg  [31:0]          ahb_bus_rdata,
    //-----------------------------------------------------------------------
    //  Registers
    //-----------------------------------------------------------------------
    // DCMI_CR
    output reg                  block_en,
    output reg                  capture_en,
    output                      capture_start,
    output reg                  man_mode,
    output                      mcu_rd_dr,
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
    output reg  [17:0]          dma_saddr,
    output reg  [17:0]          dma_len,
    // DCMI IRQ
    input       [ 4:0]          dcmi_ris,
    output reg  [ 4:0]          dcmi_ier,
    input       [ 4:0]          dcmi_mis,
    output reg  [ 4:0]          dcmi_icr,
    // DCMI_DR
    input       [31:0]          dcmi_dr,
    // Other Status,
    input                       dcmi_hsync,
    input                       dcmi_vsync,
    input                       dcmi_pclk,
    input                       ppbuf_valid,
    input                       ppbuf_empty
);

// 0: DCMI_CR
always @(posedge hclk or negedge rstn)
    if (~rstn) begin
        line_sel_start      <= 0;
        line_sel_mode       <= 0;
        byte_sel_start      <= 0;
        byte_sel_mode       <= 0;
        man_mode            <= 0;
        block_en            <= 0;
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
    else if (ahb_bus_sel & ahb_bus_wr & (ahb_bus_addr == 0)) begin
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
            man_mode            <= ahb_bus_wdata[15];
            block_en            <= ahb_bus_wdata[14];
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
// 0: capture_en
always @(posedge hclk or negedge rstn)
    if (~rstn) begin
        capture_en <= 0;
    end
    else if (ahb_bus_sel & ahb_bus_wr & (ahb_bus_addr == 0)) begin
        if (ahb_bus_bsel[0]) begin // [ 7: 0]
            capture_en <= ahb_bus_wdata[0];
        end
    end
    else if (frame_end & snapshot_mode)
        capture_en <= 0;
assign capture_start = (~capture_en) & ahb_bus_sel & ahb_bus_wr & (ahb_bus_addr == 0) & ahb_bus_wdata[0];
// 1: DCMI_SR, RO
// 2: DCMI_RIS, RO
// 3: DCMI_IER, RW
always @(posedge hclk or negedge rstn)
    if (~rstn)
        dcmi_ier <= 0;
    else if (ahb_bus_sel & ahb_bus_wr & (ahb_bus_addr == 3) & ahb_bus_bsel[0])
        dcmi_ier <= ahb_bus_wdata[4:0];
// 4: DCMI_MIS, RO
// 5: DCMI_ICR, WO
always @(*)
    if (ahb_bus_sel & ahb_bus_wr & (ahb_bus_addr == 5) & ahb_bus_bsel[0])
        dcmi_icr = ahb_bus_wdata[4:0];
    else
        dcmi_icr = 0;
// 6: DCMI_ESCR
always @(posedge hclk or negedge rstn)
    if (~rstn) begin
        fec                 <= 0;
        lec                 <= 0;
        lsc                 <= 0;
        fsc                 <= 0;
    end
    else if (ahb_bus_sel & ahb_bus_wr & (ahb_bus_addr == 6)) begin
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
// 7: DCMI_ESUR
always @(posedge hclk or negedge rstn)
    if (~rstn) begin
        feu                 <= 0;
        leu                 <= 0;
        lsu                 <= 0;
        fsu                 <= 0;
    end
    else if (ahb_bus_sel & ahb_bus_wr & (ahb_bus_addr == 7)) begin
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
// 8: DCMI_CWSTRT
always @(posedge hclk or negedge rstn)
    if (~rstn) begin
        line_crop_start     <= 0;
        pixel_crop_start    <= 0;
        dma_saddr[17:16] <= 0;
        dma_len[17:16] <= 0;
    end
    else if (ahb_bus_sel & ahb_bus_wr & (ahb_bus_addr == 8)) begin
        if (ahb_bus_bsel[3]) begin // [31:24]
            dma_saddr[17:16] <= ahb_bus_wdata[31:30];
            line_crop_start[13:8] <= ahb_bus_wdata[29:24];
        end
        if (ahb_bus_bsel[2]) begin // [23:16]
            line_crop_start[7:0] <= ahb_bus_wdata[23:16];
        end
        if (ahb_bus_bsel[1]) begin // [15: 8]
            dma_len[17:16] <= ahb_bus_wdata[15:14];
            pixel_crop_start[13:8] <= ahb_bus_wdata[13:8];
        end
        if (ahb_bus_bsel[0]) begin // [ 7: 0]
            pixel_crop_start[7:0] <= ahb_bus_wdata[7:0];
        end
    end
// 9: DCMI_CWSIZE
always @(posedge hclk or negedge rstn)
    if (~rstn) begin
        line_crop_size     <= 0;
        pixel_crop_size    <= 0;
    end
    else if (ahb_bus_sel & ahb_bus_wr & (ahb_bus_addr == 9)) begin
        if (ahb_bus_bsel[3]) begin // [31:24]
            line_crop_size[13:8] <= ahb_bus_wdata[29:24];
        end
        if (ahb_bus_bsel[2]) begin // [23:16]
            line_crop_size[7:0] <= ahb_bus_wdata[23:16];
        end
        if (ahb_bus_bsel[1]) begin // [15: 8]
            pixel_crop_size[13:8] <= ahb_bus_wdata[13:8];
        end
        if (ahb_bus_bsel[0]) begin // [ 7: 0]
            pixel_crop_size[7:0] <= ahb_bus_wdata[7:0];
        end
    end
// 10: DCMI_DR, need not delay!!!
assign mcu_rd_dr = ahb_bus_sel & ahb_bus_rd & (ahb_bus_addr == 10);
// 12: DCMI_DMA_ADDR
always @(posedge hclk or negedge rstn)
    if (~rstn) begin
        dma_saddr[15:0] <= 0;
        dma_len[15:0] <= 0;
    end
    else if (ahb_bus_sel & ahb_bus_wr & (ahb_bus_addr == 12)) begin
        if (ahb_bus_bsel[3]) begin // [31:24]
            dma_saddr[15:8] <= ahb_bus_wdata[31:24];
        end
        if (ahb_bus_bsel[2]) begin // [23:16]
            dma_saddr[ 7:0] <= ahb_bus_wdata[23:16];
        end
        if (ahb_bus_bsel[1]) begin // [15: 8]
             dma_len[15:8] <= ahb_bus_wdata[15: 8];
        end
        if (ahb_bus_bsel[0]) begin // [ 7: 0]
             dma_len[ 7:0] <= ahb_bus_wdata[ 7: 0];
        end
    end

// read 
always @(*)
    if (ahb_bus_sel & ahb_bus_rd) begin
        case (ahb_bus_addr)
            0: ahb_bus_rdata = { 11'h0,             // [31:21]
                                line_sel_start,     // [20]
                                line_sel_mode,      // [19]
                                byte_sel_start,     // [18]
                                byte_sel_mode,      // [17:16]
                                man_mode,           // [15]
                                block_en,           // [14]
                                2'h0,               // [13:12]
                                data_bus_width,     // [11:10]
                                frame_sel_mode,     // [9:8]
                                vsync_polarity,     // [7]
                                hsync_polarity,     // [6]
                                pclk_polarity,      // [5]
                                embd_sync_en,       // [4]
                                jpeg_en,            // [3]
                                crop_en,            // [2]
                                snapshot_mode,      // [1]
                                capture_en};        // [0]
            1: ahb_bus_rdata = { 27'h0,             // [31:5]
                                dcmi_pclk,          // [4]
                                ppbuf_empty,        // [3]
                                ppbuf_valid,        // [2]
                                dcmi_vsync,         // [1]
                                dcmi_hsync};        // [0]
            2: ahb_bus_rdata = {27'h0,              // [31:5]
                                dcmi_ris};          // [4:0]
            3: ahb_bus_rdata = {27'h0,              // [31:5]
                                dcmi_ier};          // [4:0]
            4: ahb_bus_rdata = {27'h0,              // [31:5]
                                dcmi_mis};          // [4:0]
            5: ahb_bus_rdata = {27'h0,              // [31:5]
                                dcmi_icr};          // [4:0]
            6: ahb_bus_rdata = {fec,                // [31:24]
                                lec,                // [23:16]
                                lsc,                // [15:8]
                                fsc};               // [7:0]
            7: ahb_bus_rdata = {feu,                // [31:24]
                                leu,                // [23:16]
                                lsu,                // [15:8]
                                fsu};               // [7:0]
            8: ahb_bus_rdata = {dma_saddr[17:16],  // [31:30]
                                line_crop_start,    // [29:16]
                                dma_len[17:16],    // [15:14]
                                pixel_crop_start};  // [13:0]
            9: ahb_bus_rdata = {2'h0,               // [31:30]
                                line_crop_size,     // [29:16]
                                2'h0,               // [15:14]
                                pixel_crop_size};   // [13:0]
            10: ahb_bus_rdata = dcmi_dr;
            12: ahb_bus_rdata = {dma_saddr[15:0],  // [31:16]
                                 dma_len[15:0]};   // [15:0]
            default: ahb_bus_rdata = 32'h0;
        endcase
    end

endmodule

