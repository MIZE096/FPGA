//******************************************************************
// 极简回声效果模块
// 避免复杂的FIFO控制，确保音频流不中断
//******************************************************************
module simple_echo_effect 
( 
    input                       clk,
    input                       sck, 
    input                       rst_n, 
    input                       echo_effect_enable,
    input signed [15:0]         data_in_left, 
    input signed [15:0]         data_in_right, 
    input                       data_valid,
    output reg signed [15:0]    data_out_left, 
    output reg signed [15:0]    data_out_right, 
    output reg                  data_out_valid
); 

    // 简单的延迟缓冲区
    reg signed [15:0] delay_buffer_left [0:1023];  // 1KB缓冲区，约21ms延迟 @48kHz
    reg signed [15:0] delay_buffer_right [0:1023];
    reg [9:0] write_ptr = 10'd0;
    reg [9:0] read_ptr = 10'd512;  // 固定512样本延迟（约10ms）
    
    // 回声增益参数
    parameter ECHO_GAIN = 16'd8192;  // 0.25倍增益 (Q15格式)
    
    // 临时计算变量
    wire signed [31:0] echo_scaled_left, echo_scaled_right;
    wire signed [31:0] mixed_left, mixed_right;
    
    // 回声增益计算
    assign echo_scaled_left = (delay_buffer_left[read_ptr] * ECHO_GAIN) >>> 15;
    assign echo_scaled_right = (delay_buffer_right[read_ptr] * ECHO_GAIN) >>> 15;
    
    // 数据混合
    assign mixed_left = data_in_left + echo_scaled_left;
    assign mixed_right = data_in_right + echo_scaled_right;
    
    always @(posedge sck or negedge rst_n) begin
        if (!rst_n) begin
            // 初始化延迟缓冲区
            for (integer i = 0; i < 1024; i = i + 1) begin
                delay_buffer_left[i] <= 16'd0;
                delay_buffer_right[i] <= 16'd0;
            end
            write_ptr <= 10'd0;
            read_ptr <= 10'd512;
            data_out_left <= 16'd0;
            data_out_right <= 16'd0;
            data_out_valid <= 1'b0;
        end else if (data_valid) begin
            // 更新指针
            write_ptr <= write_ptr + 10'd1;
            read_ptr <= read_ptr + 10'd1;
            
            // 写入当前数据到延迟缓冲区
            delay_buffer_left[write_ptr] <= data_in_left;
            delay_buffer_right[write_ptr] <= data_in_right;
            
            // 输出处理
            data_out_valid <= 1'b1;
            
            if (echo_effect_enable) begin
                // 应用回声效果
                data_out_left <= (mixed_left > 32767) ? 16'd32767 : 
                                (mixed_left < -32768) ? -16'd32768 : mixed_left[15:0];
                data_out_right <= (mixed_right > 32767) ? 16'd32767 : 
                                 (mixed_right < -32768) ? -16'd32768 : mixed_right[15:0];
            end else begin
                // 直通模式
                data_out_left <= data_in_left;
                data_out_right <= data_in_right;
            end
        end else begin
            data_out_valid <= 1'b0;
        end
    end

endmodule