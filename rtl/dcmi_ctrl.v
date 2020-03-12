
// 20200229, file created

module dcmi_ctrl (
    input                       rstn,
    input                       pclk,
    //-----------------------------------------------------------------------
    //  DCMI Interface
    //-----------------------------------------------------------------------
    // dcmi port
//    input                       dcmi_pclk,
    input                       dcmi_vsync,
    input                       dcmi_hsync,
    input [13:0]                dcmi_data,   // support 8/10/12/14 bit
    //-----------------------------------------------------------------------
    //  Registers
    //-----------------------------------------------------------------------
    // DCMI_CR
    input                       block_en,
    input                       capture_en,
    input                       snapshot_mode,
    input                       crop_en,
    input                       jpeg_en,
    input                       embd_sync_en,
//    input                       pclk_polarity,
    input                       hsync_polarity,
    input                       vsync_polarity,
    input       [1:0]           data_bus_width,         // 00: 8-bit, 01: 10-bit, 10: 12-bit, 11: 14-bit
    input       [1:0]           frame_sel_mode,      // 00: all, 01: 1/2, 10: 1/4, 11: reserved
    input       [1:0]           byte_sel_mode,       // 00: all, 01: 1/2, 10: 1/4, 11: 2/4
    input                       line_sel_mode,       // 0: all, 1: 1/2
    input                       byte_sel_start,      // 0: 1st, 1: 2nd
    input                       line_sel_start,      // 0: 1st, 1: 2nd
    // DCMI_ESCR
    input       [7:0]           fec,
    input       [7:0]           lec,
    input       [7:0]           lsc,
    input       [7:0]           fsc,
    // DCMI_ESUR
    input       [7:0]           feu,
    input       [7:0]           leu,
    input       [7:0]           lsu,
    input       [7:0]           fsu,
    // DCMI_CWSTRT
    input       [13:0]          line_crop_start,
    input       [13:0]          pixel_crop_start,
    // DCMI_CWSIZE
    input       [13:0]          line_crop_size,
    input       [13:0]          pixel_crop_size,
    //-----------------------------------------------------------------------
    //  Output
    //-----------------------------------------------------------------------
    // irq
    output                      line_irq_pulse,
    output                      frame_start_irq_pulse,
    output                      err_irq_pulse,
    output                      frame_end_irq_pulse,
    // dout
    output reg                  dout_vld,
    output reg  [31:0]          dout
);

// macros fsm
localparam                      IDLE                    = 4'd0;
localparam                      WAIT_FRAME_START        = 4'd1;
localparam                      WAIT_LINE_START         = 4'd2;
localparam                      LINE_RECV               = 4'd3;
localparam                      WAIT_LINE_END           = 4'd4;
localparam                      WAIT_FRAME_END          = 4'd5;
localparam                      FRAME_END               = 4'd6;
// macros esc
localparam                      ESC_BYTE0               = 2'd0; // embedded synchronization code
localparam                      ESC_BYTE1               = 2'd1;
localparam                      ESC_BYTE2               = 2'd2;
localparam                      ESC_BYTE3               = 2'd3;
// fsm
reg [3:0] curr_st, next_st;
reg [1:0] esc_cnt; 
wire esc_vld; reg esc_err;
// crop
reg [13:0] line_cnt; reg line_active;
reg [13:0] pixel_cnt; reg pixel_active;
//---------------------------------------------------------------------------
// Pre-process: polarity, data latch
//---------------------------------------------------------------------------
// polarity
wire vsync = dcmi_vsync ^ vsync_polarity;
wire hsync = dcmi_hsync ^ hsync_polarity;
//wire pclk = dcmi_pclk ^ pclk_polarity;
reg vsync_d1, hsync_d1;
always @(posedge pclk or negedge rstn)
    if (~rstn) begin
        vsync_d1 <= 0;
        hsync_d1 <= 0;
    end
    else if (block_en == 0) begin
        vsync_d1 <= 0;
        hsync_d1 <= 0;
    end
    else if (jpeg_en == 0 && embd_sync_en == 0) begin
        vsync_d1 <= vsync;
        hsync_d1 <= hsync;
    end
// dcmi_din_d1
reg [13:0] dcmi_din_d1;
always @(posedge pclk or negedge rstn)
    if (~rstn) begin
        dcmi_din_d1 <= 0;
    end
    else if (curr_st == IDLE && capture_en) begin
        dcmi_din_d1 <= 0;
    end
    else if (curr_st != IDLE) begin
        // 8-bit
        dcmi_din_d1[7:0] <= dcmi_data[7:0];
        // 10/12/14 bit
        if (data_bus_width[1] || data_bus_width[0]) dcmi_din_d1[9:8] <= dcmi_data[9:8];
        // 12/14 bit
        if (data_bus_width[1]) dcmi_din_d1[11:10] <= dcmi_data[11:10];
        // 14 bit
        if (data_bus_width[1] && data_bus_width[0]) dcmi_din_d1[13:12] <= dcmi_data[13:12];
    end
wire [13:0] din_d1 = dcmi_din_d1;
wire [7:0] din_8b = dcmi_data[7:0];
wire [7:0] din_d1_8b = din_d1[7:0];
//---------------------------------------------------------------------------
// Jpeg Synchronization
//---------------------------------------------------------------------------
wire jpeg_start = (~vsync_d1) & vsync; // rising edge
wire jpeg_end = vsync_d1 & (~vsync); // falling edge
//---------------------------------------------------------------------------
// Embedded Synchronization
//---------------------------------------------------------------------------
// esc cnt
always @(posedge pclk or negedge rstn)
    if (~rstn) begin
        esc_cnt <= ESC_BYTE0;
    end
    else if (block_en == 0) begin // disable
        esc_cnt <= ESC_BYTE0;
    end
    else if (curr_st == IDLE && capture_en == 1) begin // init
        esc_cnt <= ESC_BYTE0;
    end
    else if (embd_sync_en && curr_st != IDLE) begin
        case (esc_cnt)
            ESC_BYTE0: if (din_d1_8b == 8'hFF) esc_cnt <= ESC_BYTE1;                              // wait 0xff
            ESC_BYTE1: if (din_d1_8b == 8'h00) esc_cnt <= ESC_BYTE2; else esc_cnt <= ESC_BYTE0;   // wait 0x00
            ESC_BYTE2: if (din_d1_8b == 8'h00) esc_cnt <= ESC_BYTE3; else esc_cnt <= ESC_BYTE0;   // wait 0x00
            default  : esc_cnt <= ESC_BYTE0;                                                    // wait 0xXY
        endcase
    end
// 0xff check
wire fsc_is_ff = (fsc & fsu) == 8'hff;
wire fec_is_ff = (fec & feu) == 8'hff;
// byte valid
wire esc_b1_vld = (esc_cnt == ESC_BYTE1);
wire esc_b2_vld = (esc_cnt == ESC_BYTE2);
wire esc_b3_vld = (esc_cnt == ESC_BYTE3);
assign esc_vld = esc_b3_vld;
// b1 & b2 err
wire esc_b1_err = esc_b1_vld && (din_d1_8b != 8'h00); // byte 1 error
wire esc_b2_err = esc_b2_vld && (din_d1_8b != 8'h00); // byte 2 error
// esc decode
wire esc_is_lsc = (lsc & lsu) == (din_d1_8b & lsu);
wire esc_is_lec = (lec & leu) == (din_d1_8b & leu);
wire esc_is_fsc = (fsc & fsu) == (din_d1_8b & fsu);
wire esc_is_fec = fec_is_ff ? ((fsc_is_ff | ~esc_is_fsc) & ~esc_is_lsc & ~esc_is_lec) : (fec & feu) == (din_d1_8b & feu);
// last_esc_is_fec
reg last_esc_is_fec;
always @(posedge pclk or negedge rstn)
    if (~rstn) begin
        last_esc_is_fec <= 0;
    end
    else if (embd_sync_en && curr_st == WAIT_FRAME_START) begin
        if (esc_vld)
            last_esc_is_fec <= esc_is_fec;
    end
//---------------------------------------------------------------------------
// External Synchronization
//---------------------------------------------------------------------------
wire vsync_start = vsync_d1 & (~vsync); // falling edge
wire vsync_end = (~vsync_d1) & vsync; // rising edge
wire hsync_start = hsync_d1 & (~hsync);
wire hsync_end = (~hsync_d1) & hsync;
//---------------------------------------------------------------------------
// FSM
//---------------------------------------------------------------------------
// sync
always @(posedge pclk or negedge rstn)
    if (~rstn)
        curr_st <= IDLE;
    else if (~block_en)
        curr_st <= IDLE;
    else
        curr_st <= next_st;
wire pixel_crop_end = crop_en & pixel_active & (pixel_cnt == pixel_crop_size - 1);
wire line_crop_end = crop_en & line_active & (line_cnt == line_crop_size - 1);
// comb
always @(*) begin
    // default
    next_st = curr_st;
    esc_err = 0;
    // fsm
    case (curr_st)
        // idle
        IDLE: begin
            if (capture_en)
                next_st = WAIT_FRAME_START;
        end
        // wait for frame start
        WAIT_FRAME_START: begin
            if (jpeg_en & jpeg_start) begin // jpeg mode
                next_st = LINE_RECV;
            end 
            else if (embd_sync_en) begin // embedded sync mode
                if (esc_vld) begin// esc comes
                    if (fsc_is_ff) begin // when fsc=0xff, wait lsc after fec
                        if (last_esc_is_fec & esc_is_lsc)
                            next_st = LINE_RECV;
                    end
                    else begin
                        if (esc_is_fsc) // valid fsc
                            next_st = WAIT_LINE_START;
                    end
                end
            end
            else begin // external sync mode
                if (vsync_start)
                    next_st = WAIT_LINE_START;
            end
        end
        // wait for line start
        WAIT_LINE_START: begin
            if (embd_sync_en) begin // embedded sync
                if (esc_vld) begin // esc comes
                    if (esc_is_lsc)
                        next_st = LINE_RECV;
                    else if (esc_is_fec)
                        next_st = FRAME_END;
                    else begin
                        next_st = FRAME_END; // tbd, exception proc!!! now only terminate receiving
                        esc_err = 1; // esc error
                    end
                end
            end 
            else begin // external sync
                if (vsync_end)
                    next_st = FRAME_END;
                else if (hsync_start)
                    next_st = LINE_RECV;
            end
        end
        // line receiving
        LINE_RECV: begin
            if (jpeg_en) begin // jpeg mode
                if (jpeg_end)
                    next_st = FRAME_END;
            end
            else if (embd_sync_en) begin // embedded sync mode
                if (din_8b == 8'hff) // start of an embedded code, 1 cycle in advance
                    next_st = WAIT_LINE_END;
                else if (pixel_crop_end)
                    next_st = WAIT_LINE_END;
            end 
            else begin // external sync mode
                if (vsync_end) begin // frame terminate in advance
                    next_st = FRAME_END;
                end 
                else if (hsync_end) begin // line terminate in advance
                    if (line_crop_end)
                        next_st = WAIT_FRAME_END;
                    else
                        next_st = WAIT_LINE_START; // start new line 
                end
                else if (pixel_crop_end) begin // reach pixel crop size
                    next_st = WAIT_LINE_END;
                end
            end
        end
        // wait for line end
        WAIT_LINE_END: begin
            if (embd_sync_en) begin // embedded sync mode
                if (esc_vld) begin
                    if (esc_is_lec) begin // match esc
                        if (line_crop_end)
                            next_st = WAIT_FRAME_END;
                        else
                            next_st = WAIT_LINE_START;
                    end 
                    else if (esc_is_fec) begin // non-match esc, frame end in advance
                        next_st = FRAME_END;
                    end 
                    else begin // tbd, illegal esc!!! exception proc???
                        //next_st = curr_st; // wait next esc???
                        next_st = FRAME_END;
                        esc_err = 1;
                    end
                end
            end
            else begin // external sync mode
                if (vsync_end) begin
                    next_st = FRAME_END;
                end
                else if (hsync_end) begin
                    if (line_crop_end)
                        next_st = WAIT_FRAME_END;
                    else
                        next_st = WAIT_LINE_START;
                end
            end
        end
        // wait for frame end
        WAIT_FRAME_END: begin
            if (embd_sync_en) begin // embedded sync mode
                if (esc_vld) begin
                    if (esc_is_fec)
                        next_st = FRAME_END;
                    else if (esc_is_lsc | esc_is_lec) // when crop we may skip lines, but do not trigger error
                        next_st = WAIT_FRAME_END;
                    else begin // esc is illegal
                        //next_st = curr_st; // escape current esc ???
                        next_st = FRAME_END;
                        esc_err = 1;
                    end
                end
            end
            else begin
                if (vsync_end)
                    next_st = FRAME_END;
            end
        end
        // one frame has been received
        FRAME_END: begin
            if (snapshot_mode | (~capture_en))
                next_st = IDLE;
            else
                next_st = WAIT_FRAME_START;
        end
        // default
        default: next_st <= IDLE;
    endcase
end
//---------------------------------------------------------------------------
// Crop Function
//---------------------------------------------------------------------------
// frame sel
reg [1:0] frame_cnt;
always @(posedge pclk or negedge rstn)
    if (~rstn)
        frame_cnt <= 0;
    else if (block_en == 0)
        frame_cnt <= 0;
    else if (curr_st == FRAME_END) begin
        if (frame_cnt == frame_sel_mode)
            frame_cnt <= 0;
        else
            frame_cnt <= frame_cnt + 1;
    end
wire frame_sel = frame_cnt == 2'b00;
// line_cnt
wire line_cnt_init = (curr_st == WAIT_FRAME_START && next_st != WAIT_FRAME_START); // init when frame start
wire line_cnt_inc = (curr_st == LINE_RECV && next_st != LINE_RECV); // inc when finish receiving one line
always @(posedge pclk or negedge rstn)
    if (~rstn)
        line_cnt <= 0;
    else if (~block_en)
        line_cnt <= 0;
    else if (line_cnt_init)
        line_cnt <= 0;
    else if (line_cnt_inc) begin
        if (line_active == 0 && line_cnt == line_crop_start - 1)
            line_cnt <= 0;
        else
            line_cnt <= line_cnt + 1;
    end
// line_active
always @(posedge pclk or negedge rstn)
    if (~rstn)
        line_active <= 0;
    else if (~block_en)
        line_active <= 0;
    else if (line_cnt_init) begin
        if (crop_en && line_crop_start != 0)
            line_active <= 0;
        else
            line_active <= 1;
    end
    else if (line_cnt_inc & ~line_active) begin
        if (line_cnt == line_crop_start - 1)
            line_active <= 1;
    end
wire line_sel = line_active & (line_sel_mode ? ((~line_cnt[0]) ^ line_sel_start) : 1'b1);
// pixel_cnt
wire pixel_cnt_init = line_active & (curr_st != LINE_RECV && next_st == LINE_RECV); // enter LINE_RECV
wire pixel_cnt_inc = line_active & (curr_st == LINE_RECV);
always @(posedge pclk or negedge rstn)
    if (~rstn)
        pixel_cnt <= 0;
    else if (~block_en)
        pixel_cnt <= 0;
    else if (pixel_cnt_init)
        pixel_cnt <= 0;
    else if (pixel_cnt_inc) begin
        if (pixel_active == 0 && pixel_cnt == pixel_crop_start - 1)
            pixel_cnt <= 0;
        else
            pixel_cnt <= pixel_cnt + 1;
    end
// pixel_active
always @(posedge pclk or negedge rstn)
    if (~rstn)
        pixel_active <= 0;
    else if (pixel_cnt_init) begin
        if (crop_en && pixel_crop_start != 0)
            pixel_active <= 0;
        else
            pixel_active <= 1;
    end
    else if (pixel_cnt_inc & ~pixel_active) begin
        if (pixel_cnt == pixel_crop_start - 1)
            pixel_active <= 1;
    end
// pixel sel
wire pixel_sel = pixel_active & ((byte_sel_mode == 2'b00) ? 1'b1 :                                  // mode 0: all
                                 (byte_sel_mode == 2'b01) ? ((~pixel_cnt[0]) ^ byte_sel_start) :    // mode 1: 0/2/4/6/... or 1/3/5/7/...
                                 (byte_sel_mode == 2'b10) ? (pixel_cnt[1:0] == 2'b00) :             // mode 2: 0/4/8/12/...
                                 (~pixel_cnt[1]));                                                  // mode 3: 01/45/89/...
//---------------------------------------------------------------------------
// Output
//---------------------------------------------------------------------------
// irq signal
reg ls_irq, fs_irq, fe_irq, err_irq;
// ls
wire ls_irq_clr = ~block_en | ls_irq ;
wire ls_irq_set = ~ls_irq & (curr_st != LINE_RECV && next_st == LINE_RECV);
always @(posedge pclk or negedge rstn)
    if (~rstn)
        ls_irq <= 0;
    else if (ls_irq_clr)
        ls_irq <= 0;
    else if (ls_irq_set)
        ls_irq <= 1;
// fs
wire fs_irq_clr = ~block_en | fs_irq;
wire fs_irq_set = ~fs_irq & (curr_st == WAIT_FRAME_START && next_st != WAIT_FRAME_START);
always @(posedge pclk or negedge rstn)
    if (~rstn)
        fs_irq <= 0;
    else if (fs_irq_clr)
        fs_irq <= 0;
    else if (fs_irq_set)
        fs_irq <= 1;
// fe
wire fe_irq_clr = ~block_en | fe_irq;
wire fe_irq_set = ~fe_irq & (curr_st == FRAME_END);
always @(posedge pclk or negedge rstn)
    if (~rstn)
        fe_irq <= 0;
    else if (fe_irq_clr)
        fe_irq <= 0;
    else if (fe_irq_set)
        fe_irq <= 1;
// err
wire err_irq_clr = ~block_en | err_irq;
wire err_irq_set = ~err_irq & (esc_err | esc_b1_err | esc_b2_err);
always @(posedge pclk or negedge rstn)
    if (~rstn)
        err_irq <= 0;
    else if (err_irq_clr)
        err_irq <= 0;
    else if (err_irq_set)
        err_irq <= 1;
// irq out
assign line_irq_pulse           = ls_irq;
assign frame_start_irq_pulse    = fs_irq;
assign frame_end_irq_pulse      = fe_irq;
assign err_irq_pulse            = err_irq;
// 32-bit word assemble
reg [31:0] pixel_word; reg pixel_word_vld;
reg [1:0] pixel_inner_word_cnt;
wire [1:0] pixel_inner_word_max = (data_bus_width == 2'b00) ? 2'b11 : 2'b01;
wire [1:0] pixel_inner_word_next = (pixel_inner_word_cnt == pixel_inner_word_max) ? 2'b00 : pixel_inner_word_cnt + 2'b01;
wire piwc_clr = (~block_en) | (curr_st == WAIT_FRAME_START && next_st != WAIT_FRAME_START);     // clear at frame start
wire piwc_inc = jpeg_en ?      (curr_st == LINE_RECV && hsync == 1'b0) :                            // jpeg using hsync to indicate valid data
                embd_sync_en ? (curr_st == LINE_RECV && frame_sel & line_sel & pixel_sel) :         // embedded sync mode
                               (curr_st == LINE_RECV && frame_sel & line_sel & pixel_sel & ~hsync); // external sync mode
always @(posedge pclk or negedge rstn)
    if (~rstn)
        pixel_inner_word_cnt <= 0;
    else if (piwc_clr)
        pixel_inner_word_cnt <= 0;
    else if (piwc_inc)
        pixel_inner_word_cnt <= pixel_inner_word_next;
always @(posedge pclk or negedge rstn)
    if (~rstn)
        pixel_word <= 0;
    else if (piwc_clr)
        pixel_word <= 0;
    else if (piwc_inc) begin
        if (data_bus_width == 2'b00) begin // 8-bit
            case (pixel_inner_word_cnt)
                2'b00: pixel_word[7:0] <= din_d1[7:0];
                2'b01: pixel_word[15:8] <= din_d1[7:0];
                2'b10: pixel_word[23:16] <= din_d1[7:0];
                default: pixel_word[31:24] <= din_d1[7:0];
            endcase
        end
        else begin
            if (pixel_inner_word_cnt[0])
                pixel_word[31:16] <= {2'b00, din_d1[13:0]};
            else
                pixel_word[15:0] <= {2'b00, din_d1[13:0]};
        end
    end
always @(posedge pclk or negedge rstn)
    if (~rstn)
        pixel_word_vld <= 0;
    else if (piwc_clr)
        pixel_word_vld <= 0;
    else if (piwc_inc) begin // valid word
        if (pixel_inner_word_cnt == pixel_inner_word_max)
            pixel_word_vld <= 1;
        else
            pixel_word_vld <= 0;
    end
    else if (fe_irq && pixel_inner_word_cnt != 2'b00) // incompleted word, use delay end to avoid continuse valid
        pixel_word_vld <= 1;
    else
        pixel_word_vld <= 0;
// dout
always @(posedge pclk or negedge rstn)
    if (~rstn) begin
        dout_vld <= 0;
        dout <= 0;
    end
    else if (block_en & pixel_word_vld) begin
        dout_vld <= 1;
        dout <= pixel_word;
    end
    else begin
        dout_vld <= 0;
    end

endmodule

