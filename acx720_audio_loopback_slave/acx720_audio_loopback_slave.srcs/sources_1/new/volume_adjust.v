//******************************************************************
// 音量控制模块
// 支持10级音量调节，包含增大和减小功能
// 同时支持按钮和串口控制
//******************************************************************
module volume_control
#(  
    parameter DATA_WIDTH = 16
)
(
    input                       clk,
    input                       sck,
    input                       rst_n,
    input                       volume_up,          // 音量增加信号（按钮）
    input                       volume_down,        // 音量减小信号（按钮）
    input                       uart_volume_up,     // 串口音量增加信号
    input                       uart_volume_down,   // 串口音量减小信号
    input   signed [DATA_WIDTH - 1:0]  data_in_left,
    input   signed [DATA_WIDTH - 1:0]  data_in_right,
    output reg signed [DATA_WIDTH - 1:0]  data_out_left,
    output reg signed [DATA_WIDTH - 1:0]  data_out_right,
    output reg [3:0]            volume_level,      // 音量级别 (0-9)
    output reg                  volume_up_led,     // 音量增大指示灯
    output reg                  volume_down_led    // 音量减小指示灯
);

    // 按钮消抖相关
    reg [19:0] debounce_counter_up;
    reg [19:0] debounce_counter_down;
    reg volume_up_sync;
    reg volume_up_prev;
    reg volume_up_pressed;
    reg volume_down_sync;
    reg volume_down_prev;
    reg volume_down_pressed;
    
    // 串口信号处理
    reg uart_volume_up_prev;
    reg uart_volume_down_prev;
    reg uart_volume_up_pressed;
    reg uart_volume_down_pressed;
    
    // 指示灯计数器
    reg [23:0] led_counter_up;
    reg [23:0] led_counter_down;
    
    // 临时计算变量
    reg signed [31:0] temp_left;
    reg signed [31:0] temp_right;
    
    // 合并的控制信号
    wire combined_volume_up = volume_up_pressed | uart_volume_up_pressed;
    wire combined_volume_down = volume_down_pressed | uart_volume_down_pressed;
    
    // 音量级别更新
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            volume_level <= 4'd5;  // 初始音量级别5 (原始音量)
        end else begin
            // 音量级别更新
            if (combined_volume_up) begin
                if (volume_level < 4'd9) begin
                    volume_level <= volume_level + 1'b1;
                end
            end else if (combined_volume_down) begin
                if (volume_level > 4'd0) begin
                    volume_level <= volume_level - 1'b1;
                end
            end
        end
    end
    
    // 音量增大按钮消抖处理
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            volume_up_sync <= 1'b1;
            volume_up_prev <= 1'b1;
            debounce_counter_up <= 20'd0;
            volume_up_pressed <= 1'b0;
        end else begin
            // 同步按钮输入
            volume_up_sync <= volume_up;
            volume_up_prev <= volume_up_sync;
            
            // 检测下降沿
            if (volume_up_prev && !volume_up_sync) begin
                debounce_counter_up <= 20'd1000000; // 20ms消抖
            end else if (debounce_counter_up > 0) begin
                debounce_counter_up <= debounce_counter_up - 1'b1;
                if (debounce_counter_up == 20'd1) begin
                    volume_up_pressed <= 1'b1;
                end else begin
                    volume_up_pressed <= 1'b0;
                end
            end else begin
                volume_up_pressed <= 1'b0;
            end
        end
    end
    
    // 音量减小按钮消抖处理
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            volume_down_sync <= 1'b1;
            volume_down_prev <= 1'b1;
            debounce_counter_down <= 20'd0;
            volume_down_pressed <= 1'b0;
        end else begin
            // 同步按钮输入
            volume_down_sync <= volume_down;
            volume_down_prev <= volume_down_sync;
            
            // 检测下降沿
            if (volume_down_prev && !volume_down_sync) begin
                debounce_counter_down <= 20'd1000000; // 20ms消抖
            end else if (debounce_counter_down > 0) begin
                debounce_counter_down <= debounce_counter_down - 1'b1;
                if (debounce_counter_down == 20'd1) begin
                    volume_down_pressed <= 1'b1;
                end else begin
                    volume_down_pressed <= 1'b0;
                end
            end else begin
                volume_down_pressed <= 1'b0;
            end
        end
    end
    
    // 串口音量控制处理
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_volume_up_prev <= 1'b0;
            uart_volume_down_prev <= 1'b0;
            uart_volume_up_pressed <= 1'b0;
            uart_volume_down_pressed <= 1'b0;
        end else begin
            // 检测串口信号的上升沿
            uart_volume_up_prev <= uart_volume_up;
            uart_volume_down_prev <= uart_volume_down;
            
            if (!uart_volume_up_prev && uart_volume_up) begin
                uart_volume_up_pressed <= 1'b1;
            end else begin
                uart_volume_up_pressed <= 1'b0;
            end
            
            if (!uart_volume_down_prev && uart_volume_down) begin
                uart_volume_down_pressed <= 1'b1;
            end else begin
                uart_volume_down_pressed <= 1'b0;
            end
        end
    end
    
    // 增大指示灯控制
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_counter_up <= 24'd0;
            volume_up_led <= 1'b0;
        end else begin
            if (combined_volume_up) begin
                led_counter_up <= 24'd2500000; // 50ms点亮
                volume_up_led <= 1'b1;
            end else if (led_counter_up > 0) begin
                led_counter_up <= led_counter_up - 1'b1;
                volume_up_led <= 1'b1; // 保持亮直到计数器结束
            end else begin
                volume_up_led <= 1'b0;
            end
        end
    end
    
    // 减小指示灯控制
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_counter_down <= 24'd0;
            volume_down_led <= 1'b0;
        end else begin
            if (combined_volume_down) begin
                led_counter_down <= 24'd2500000; // 50ms点亮
                volume_down_led <= 1'b1;
            end else if (led_counter_down > 0) begin
                led_counter_down <= led_counter_down - 1'b1;
                volume_down_led <= 1'b1; // 保持亮直到计数器结束
            end else begin
                volume_down_led <= 1'b0;
            end
        end
    end
    
    // 音量调节处理 - 10级音量调节
    always @(posedge sck or negedge rst_n) begin
        if (!rst_n) begin
            data_out_left <= 16'd0;
            data_out_right <= 16'd0;
        end else begin
            // 左声道音量调节
            case(volume_level)
                4'd0: begin // 0.0x - 静音
                    data_out_left <= 16'd0;
                end
                4'd1: begin // 0.2x - (原始 × 0.2)
                    temp_left = (data_in_left >>> 2) + (data_in_left >>> 3);
                    data_out_left <= temp_left[15:0];
                end
                4'd2: begin // 0.4x - (原始 × 0.4)
                    temp_left = (data_in_left >>> 1) + (data_in_left >>> 3);
                    data_out_left <= temp_left[15:0];
                end
                4'd3: begin // 0.6x - (原始 × 0.6)
                    temp_left = (data_in_left >>> 1) + (data_in_left >>> 2);
                    data_out_left <= temp_left[15:0];
                end
                4'd4: begin // 0.8x - (原始 × 0.8)
                    temp_left = data_in_left - (data_in_left >>> 2);
                    data_out_left <= temp_left[15:0];
                end
                4'd5: begin // 1.0x - 原始音量
                    data_out_left <= data_in_left;
                end
                4'd6: begin // 1.2x - (原始 + 1/5)
                    temp_left = data_in_left + (data_in_left >>> 2) + (data_in_left >>> 3);
                    data_out_left <= (temp_left > 32767) ? 16'd32767 : 
                                    (temp_left < -32768) ? -16'd32768 : temp_left[15:0];
                end
                4'd7: begin // 1.4x - (原始 + 2/5)
                    temp_left = data_in_left + (data_in_left >>> 1) - (data_in_left >>> 3);
                    data_out_left <= (temp_left > 32767) ? 16'd32767 : 
                                    (temp_left < -32768) ? -16'd32768 : temp_left[15:0];
                end
                4'd8: begin // 1.6x - (原始 + 3/5)
                    temp_left = data_in_left + (data_in_left >>> 1) + (data_in_left >>> 3);
                    data_out_left <= (temp_left > 32767) ? 16'd32767 : 
                                    (temp_left < -32768) ? -16'd32768 : temp_left[15:0];
                end
                4'd9: begin // 1.8x - (原始 + 4/5)
                    temp_left = data_in_left + (data_in_left >>> 1) + (data_in_left >>> 2);
                    data_out_left <= (temp_left > 32767) ? 16'd32767 : 
                                    (temp_left < -32768) ? -16'd32768 : temp_left[15:0];
                end
                default: begin
                    data_out_left <= data_in_left;
                end
            endcase
            
            // 右声道音量调节（与左声道相同处理）
            case(volume_level)
                4'd0: begin
                    data_out_right <= 16'd0;
                end
                4'd1: begin
                    temp_right = (data_in_right >>> 2) + (data_in_right >>> 3);
                    data_out_right <= temp_right[15:0];
                end
                4'd2: begin
                    temp_right = (data_in_right >>> 1) + (data_in_right >>> 3);
                    data_out_right <= temp_right[15:0];
                end
                4'd3: begin
                    temp_right = (data_in_right >>> 1) + (data_in_right >>> 2);
                    data_out_right <= temp_right[15:0];
                end
                4'd4: begin
                    temp_right = data_in_right - (data_in_right >>> 2);
                    data_out_right <= temp_right[15:0];
                end
                4'd5: begin
                    data_out_right <= data_in_right;
                end
                4'd6: begin
                    temp_right = data_in_right + (data_in_right >>> 2) + (data_in_right >>> 3);
                    data_out_right <= (temp_right > 32767) ? 16'd32767 : 
                                     (temp_right < -32768) ? -16'd32768 : temp_right[15:0];
                end
                4'd7: begin
                    temp_right = data_in_right + (data_in_right >>> 1) - (data_in_right >>> 3);
                    data_out_right <= (temp_right > 32767) ? 16'd32767 : 
                                     (temp_right < -32768) ? -16'd32768 : temp_right[15:0];
                end
                4'd8: begin
                    temp_right = data_in_right + (data_in_right >>> 1) + (data_in_right >>> 3);
                    data_out_right <= (temp_right > 32767) ? 16'd32767 : 
                                     (temp_right < -32768) ? -16'd32768 : temp_right[15:0];
                end
                4'd9: begin
                    temp_right = data_in_right + (data_in_right >>> 1) + (data_in_right >>> 2);
                    data_out_right <= (temp_right > 32767) ? 16'd32767 : 
                                     (temp_right < -32768) ? -16'd32768 : temp_right[15:0];
                end
                default: begin
                    data_out_right <= data_in_right;
                end
            endcase
        end
    end

endmodule