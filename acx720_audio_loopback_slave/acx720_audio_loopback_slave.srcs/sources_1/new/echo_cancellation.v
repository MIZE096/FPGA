`timescale 1ns/1ns
module echo_cancellation
#(  
    parameter DATA_WIDTH = 16
)
(
    input                       sck,
    input                       clk,
    input                       rst_n,
    input                       echo_enable,
    input   signed[DATA_WIDTH - 1:0]  data_in_left,
    input   signed[DATA_WIDTH - 1:0]  data_in_right,
    output reg signed[DATA_WIDTH - 1:0]  data_out_left,
    output reg signed[DATA_WIDTH - 1:0]  data_out_right
);

parameter signed threshold_high = 16'b0111111111111111;  //+32767
parameter signed threshold_low  = 16'b1000000000000000; // -32768

wire                almost_full;
reg                 rd_en;
wire  signed[15:0]  rd_data;
wire  signed[15:0]  p_1;
wire [14:0]         wr_water_level;
wire [31:0]         p;

// 延迟和衰减参数设置
reg [14:0]         set_delay = 15'd2400;      // 约50ms延迟 (2400 samples @ 48kHz)
reg [15:0]         set_echo_Attenuation_factor = 16'd16384; // 0.5倍衰减

assign p_1 = p[31:16];

always @(posedge sck or negedge rst_n)
begin
    if(~rst_n) begin
        rd_en <= 'd0;
    end
    else if(wr_water_level >= set_delay) begin
        rd_en <= 1'b1;
    end
    else begin
        rd_en <= rd_en;
    end
end

always @(posedge sck or negedge rst_n)
begin
    if(~rst_n) begin
        data_out_left <= 'd0;
        data_out_right <= 'd0;
    end
    else if (echo_enable) begin
        // 左声道进行回声消除
        if ((data_in_left - p_1) >= threshold_high) begin
            data_out_left <= 16'b0111111111111111;
        end
        else if ((data_in_left - p_1) <= threshold_low) begin
            data_out_left <= 16'b1000000000000000;
        end
        else begin
            data_out_left <= data_in_left - p_1;
        end
        
        // 右声道同样进行回声消除（之前只处理了左声道）
        if ((data_in_right - p_1) >= threshold_high) begin
            data_out_right <= 16'b0111111111111111;
        end
        else if ((data_in_right - p_1) <= threshold_low) begin
            data_out_right <= 16'b1000000000000000;
        end
        else begin
            data_out_right <= data_in_right - p_1;
        end
    end
    else begin
        // 回声消除关闭，直接输出
        data_out_left <= data_in_left;
        data_out_right <= data_in_right;
    end
end

// 回声消除FIFO
echo_fifo echo_fifo_inst (
  .clk(sck),                      // input
  .rst(~rst_n),                   // input
  .wr_en(1'b1),                   // input
  .wr_data(data_out_left),        // input [15:0]
  .wr_full(),                     // output
  .almost_full(almost_full),      // output
  .wr_water_level(wr_water_level),// output [14:0]
  .rd_en(rd_en),                  // input
  .rd_data(rd_data),              // output [15:0]
  .rd_empty()                     // output
);

// 乘法器用于衰减计算
simple_multi_16x16 simple_multi_16x16 (
  .a(rd_data),                         // input [15:0]
  .b(set_echo_Attenuation_factor),     // input [15:0]
  .clk(sck),                           // input
  .rst(~rst_n),                        // input
  .ce(rd_en),                          // input
  .p(p)                                // output [31:0]
);

endmodule