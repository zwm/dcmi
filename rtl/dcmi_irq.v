
// 20200312, file created

module dcmi_irq (
    // sys
    input                       rstn,
    input                       clk,
    // pulse
    input                       line_irq_pulse,
    input                       vsync_irq_pulse,
    input                       err_irq_pulse,
    input                       ovfl_irq_pulse,
    input                       frame_end_irq_pulse,
    // reg
    output reg      [4:0]       dcmi_ris,
    input           [4:0]       dcmi_ier,
    output          [4:0]       dcmi_mis,
    input           [4:0]       dcmi_icr,
    output                      dcmi_irq
);
// DCMI_RIS
// dcmi_ris[4]: line
always @(posedge clk or negedge rstn)
    if (~rstn)
        dcmi_ris[4] <= 0;
    else if (dcmi_icr[4])
        dcmi_ris[4] <= 0;
    else if (line_irq_pulse)
        dcmi_ris[4] <= 1;
// dcmi_ris[3]: vsync
always @(posedge clk or negedge rstn)
    if (~rstn)
        dcmi_ris[3] <= 0;
    else if (dcmi_icr[3])
        dcmi_ris[3] <= 0;
    else if (vsync_irq_pulse)
        dcmi_ris[3] <= 1;
// dcmi_ris[2]: err
always @(posedge clk or negedge rstn)
    if (~rstn)
        dcmi_ris[2] <= 0;
    else if (dcmi_icr[2])
        dcmi_ris[2] <= 0;
    else if (err_irq_pulse)
        dcmi_ris[2] <= 1;
// dcmi_ris[1]: ovfl
always @(posedge clk or negedge rstn)
    if (~rstn)
        dcmi_ris[1] <= 0;
    else if (dcmi_icr[1])
        dcmi_ris[1] <= 0;
    else if (ovfl_irq_pulse)
        dcmi_ris[1] <= 1;
// dcmi_ris[0]: fe
always @(posedge clk or negedge rstn)
    if (~rstn)
        dcmi_ris[0] <= 0;
    else if (dcmi_icr[0])
        dcmi_ris[0] <= 0;
    else if (frame_end_irq_pulse)
        dcmi_ris[0] <= 1;
// DCMI_MIS
assign dcmi_mis = dcmi_ris & dcmi_ier;
// DCMI_IRQ
assign dcmi_irq = |dcmi_mis;

endmodule

