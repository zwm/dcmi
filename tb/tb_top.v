`timescale 1ns/1ps

module tb_top();
// macro
`include "tb_define.v"
// reg
reg block_en;
reg capture_en;
reg snapshot_mode;
reg crop_en;
reg jpeg_en;
reg embd_sync_en;
reg pclk_polarity;
reg hsync_polarity;
reg vsync_polarity;
reg data_bus_width;         // 00: 8-bit, 01: 10-bit, 10: 12-bit, 11: 14-bit
reg [1:0] frame_sel_mode;      // 00: all, 01: 1/2, 10: 1/4, 11: reserved
reg [1:0] byte_sel_mode;       // 00: all, 01: 1/2, 10: 1/4, 11: 2/4
reg line_sel_mode;       // 0: all, 1: 1/2
reg byte_sel_start;      // 0: 1st, 1: 2nd
reg line_sel_start;      // 0: 1st, 1: 2nd
reg [7:0] fsc, fec, lsc, lec;
reg [7:0] fsu, feu, lsu, leu;
reg [12:0] line_crop_start;
reg [13:0] pixel_crop_start;
reg [13:0] line_crop_size;
reg [13:0] pixel_crop_size;
// dcmi
wire dcmi_pclk, dcmi_vsync, dcmi_hsync; wire [13:0] dcmi_data; reg dcmi_pwdn;
// output
wire line_irq_pulse, frame_start_irq_pulse, err_irq_pulse, frame_end_irq_pulse;
wire dout_vld; wire [31:0] dout;

// main
initial begin
    sys_init;
    #50_000;
    dcmi_pwon;
    reg_init;
    repeat (10) @(posedge dcmi_pclk);
    set_block_en(1);
    repeat (10) @(posedge dcmi_pclk);
    set_capture_en(1);
    repeat (10) @(posedge dcmi_pclk);
    set_capture_en(0);
    #1000_000;
    $finish;
end
// inst dcmi
dcmi_ctrl u_dcmi (
    .dcmi_pclk(dcmi_pclk),
    .dcmi_vsync(dcmi_vsync),
    .dcmi_hsync(dcmi_hsync),
    .dcmi_data(dcmi_data),   // support 8/10/12/14 bit
    .block_en(block_en),
    .capture_en(capture_en),
    .snapshot_mode(snapshot_mode),
    .crop_en(crop_en),
    .jpeg_en(jpeg_en),
    .embd_sync_en(embd_sync_en),
    .pclk_polarity(pclk_polarity),
    .hsync_polarity(hsync_polarity),
    .vsync_polarity(vsync_polarity),
    .data_bus_width(data_bus_width),         // 00: 8-bit, 01: 10-bit, 10: 12-bit, 11: 14-bit
    .frame_sel_mode(frame_sel_mode),      // 00: all, 01: 1/2, 10: 1/4, 11: reserved
    .byte_sel_mode(byte_sel_mode),       // 00: all, 01: 1/2, 10: 1/4, 11: 2/4
    .line_sel_mode(line_sel_mode),       // 0: all, 1: 1/2
    .byte_sel_start(byte_sel_start),      // 0: 1st, 1: 2nd
    .line_sel_start(line_sel_start),      // 0: 1st, 1: 2nd
    .fec(fec),
    .lec(lec),
    .lsc(lsc),
    .fsc(fsc),
    .feu(feu),
    .leu(leu),
    .lsu(lsu),
    .fsu(fsu),
    .line_crop_start(line_crop_start),
    .pixel_crop_start(pixel_crop_start),
    .line_crop_size(line_crop_size),
    .pixel_crop_size(pixel_crop_size),
    .line_irq_pulse(line_irq_pulse),
    .frame_start_irq_pulse(frame_start_irq_pulse),
    .err_irq_pulse(err_irq_pulse),
    .frame_end_irq_pulse(frame_end_irq_pulse),
    .dout_vld(dout_vld),
    .dout(dout)
);
// inst camera
camera_dcmi u_camera (
    .dcmi_pwdn(dcmi_pwdn),
    .dcmi_mclk(dcmi_mclk),
    .dcmi_pclk(dcmi_pclk),
    .dcmi_vsync(dcmi_vsync),
    .dcmi_hsync(dcmi_hsync),
    .dcmi_data(dcmi_data)
);
// fsdb
`ifdef DUMP_FSDB
initial begin
    $fsdbDumpfile("tb_top.fsdb");
    $fsdbDumpvars(0, tb_top);
end
`endif

task sys_init;
    begin
        block_en = 0;
        capture_en = 0;
        snapshot_mode = 0;
        crop_en = 0;
        jpeg_en = 0;
        embd_sync_en = 0;
        pclk_polarity = 0;
        hsync_polarity = 0;
        vsync_polarity = 0;
        data_bus_width = 0;         // 00: 8-bit, 01: 10-bit, 10: 12-bit, 11: 14-bit
        frame_sel_mode = 0;      // 00: all, 01: 1/2, 10: 1/4, 11: reserved
        byte_sel_mode = 0;       // 00: all, 01: 1/2, 10: 1/4, 11: 2/4
        line_sel_mode = 0;       // 0: all, 1: 1/2
        byte_sel_start = 0;      // 0: 1st, 1: 2nd
        line_sel_start = 0;      // 0: 1st, 1: 2nd
        fsc = 0;
        fec = 0;
        lsc = 0;
        lec = 0;
        fsu = 0;
        feu = 0;
        lsu = 0;
        leu = 0;
        line_crop_start = 0;
        pixel_crop_start = 0;
        line_crop_size = 0;
        pixel_crop_size = 0;
        dcmi_pwdn = 0;
    end
endtask

task reg_init;
    begin
        block_en = 0;
        capture_en = 0;
        snapshot_mode = 1;
        crop_en = 0;
        jpeg_en = 0;
        embd_sync_en = 0;
        pclk_polarity = 0;
        hsync_polarity = 0;
        vsync_polarity = 0;
        data_bus_width = 0;         // 00: 8-bit, 01: 10-bit, 10: 12-bit, 11: 14-bit
        frame_sel_mode = 0;      // 00: all, 01: 1/2, 10: 1/4, 11: reserved
        byte_sel_mode = 0;       // 00: all, 01: 1/2, 10: 1/4, 11: 2/4
        line_sel_mode = 0;       // 0: all, 1: 1/2
        byte_sel_start = 0;      // 0: 1st, 1: 2nd
        line_sel_start = 0;      // 0: 1st, 1: 2nd
        fsc = 0;
        fec = 0;
        lsc = 0;
        lec = 0;
        fsu = 0;
        feu = 0;
        lsu = 0;
        leu = 0;
        line_crop_start = 0;
        pixel_crop_start = 0;
        line_crop_size = 0;
        pixel_crop_size = 0;
    end
endtask

task set_block_en;
    input val;
    begin
        block_en = val;
    end
endtask

task set_capture_en;
    input val;
    begin
        capture_en = val;
    end
endtask

task dcmi_pwon;
    begin
        dcmi_pwdn = 1;
        #1000;
        dcmi_pwdn = 0;
    end
endtask
