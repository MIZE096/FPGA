module audio_lookback(
    input clk,                    
    input reset_n,  
    input button_s1,             // 按钮S1输入 - 未使用
    input button_s2,             // 按钮S2输入 - 未使用
    input button_s3,             // 按钮S3输入 - 音量减小
    input button_s4,             // 按钮S4输入 - 音量增大
    input uart_rx,               // 串口接收
    output reg led1,             // 回声消除指示灯LED1
    output reg led2,             // 降噪指示灯LED2
    output reg led3,             // 回声效果指示灯LED3
    output reg led4,             // 音量增大指示灯LED4
    output reg led5,             // 音量减小指示灯LED5
    output led0,                 // 初始化完成指示灯LED0
                                  
    inout iic_0_scl,              
    inout iic_0_sda,   
    
    input I2S_DI,
    output I2S_RCLK,
    output I2S_BCLK,
    output I2S_DO,
    output I2S_MCLK
);

    parameter DATA_WIDTH = 32;     

    wire locked;
    
    // 时钟生成
    clk_wiz_0 instance_name
    (
        .clk_out1(I2S_MCLK),     // output clk_out1
        .resetn(reset_n),        // input resetn
        .locked(locked),         // output locked
        .clk_in1(clk)            // input clk_in1
    );
    
    // BCLK分频
    clk_div4 clk_div4(
        .clk_in(I2S_MCLK),       // 输入时钟
        .rst_n(reset_n),         // 复位信号
        .clk_out(I2S_BCLK)       // 输出时钟
    );

    // LRCK生成
    reg[10:0] lrclk_cnt;
    reg i2s_lrck;
    always@(negedge I2S_BCLK or negedge reset_n)
    if(!reset_n) begin
        lrclk_cnt <= 11'd0;
        i2s_lrck <= 1'd0;
    end
    else if(~locked) begin
        lrclk_cnt <= 11'd0;
        i2s_lrck <= 1'd0;
    end
    else if(lrclk_cnt == 11'd64 - 1) begin          
        lrclk_cnt <= 11'd0;
        i2s_lrck <= ~i2s_lrck;
    end
    else begin
        lrclk_cnt <= lrclk_cnt + 1'd1;
        i2s_lrck <= i2s_lrck;
    end

    assign I2S_RCLK = i2s_lrck;

    // ES8388初始化
    wire Init_Done;
    es8388_Init es8388_Init(
        .Clk(clk),
        .Rst_n(reset_n),
        .I2C_Init_Done(Init_Done),
        .i2c_sclk(iic_0_scl),
        .i2c_sdat(iic_0_sda)
    );
    
    assign led0 = Init_Done;

    // 串口接收相关信号
    wire [7:0] rx_data_byte;
    wire byte_rx_done;
    reg uart_echo_enable;        // 串口控制的回声消除使能
    reg uart_noise_reduction_enable; // 串口控制的降噪使能
    reg uart_echo_effect_enable;     // 串口控制的回声效果使能
    
    // 串口音量控制相关信号
    reg uart_volume_up;
    reg uart_volume_down;
    reg [23:0] uart_volume_up_led_counter;
    reg [23:0] uart_volume_down_led_counter;
    reg uart_volume_up_led;
    reg uart_volume_down_led;
    
    // 串口接收模块实例化
    uart_byte_rx uart_rx_inst(
        .Clk(clk),
        .Rst_n(reset_n),
        .baud_set(3'd4),         // 115200波特率
        .uart_rx(uart_rx),
        .data_byte(rx_data_byte),
        .Rx_Done(byte_rx_done)
    );
    
    // 串口命令处理
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            uart_echo_enable <= 1'b0;
            uart_noise_reduction_enable <= 1'b0;
            uart_echo_effect_enable <= 1'b0;
            uart_volume_up <= 1'b0;
            uart_volume_down <= 1'b0;
            uart_volume_up_led_counter <= 24'd0;
            uart_volume_down_led_counter <= 24'd0;
            uart_volume_up_led <= 1'b0;
            uart_volume_down_led <= 1'b0;
        end else begin
            // 音量控制LED计数器
            if (uart_volume_up_led_counter > 0) begin
                uart_volume_up_led_counter <= uart_volume_up_led_counter - 1'b1;
                uart_volume_up_led <= 1'b1;
            end else begin
                uart_volume_up_led <= 1'b0;
            end
            
            if (uart_volume_down_led_counter > 0) begin
                uart_volume_down_led_counter <= uart_volume_down_led_counter - 1'b1;
                uart_volume_down_led <= 1'b1;
            end else begin
                uart_volume_down_led <= 1'b0;
            end
            
            // 串口命令处理
            if (byte_rx_done) begin
                case(rx_data_byte)
                    8'h01: uart_echo_enable <= ~uart_echo_enable;           // 切换回声消除状态
                    8'h02: uart_noise_reduction_enable <= ~uart_noise_reduction_enable; // 切换降噪状态
                    8'h03: uart_echo_effect_enable <= ~uart_echo_effect_enable;         // 切换回声效果状态
                    8'h0E: begin // 14 - 增大音量
                        uart_volume_up <= 1'b1;
                        uart_volume_up_led_counter <= 24'd2500000; // 50ms点亮
                    end
                    8'h0F: begin // 15 - 减小音量
                        uart_volume_down <= 1'b1;
                        uart_volume_down_led_counter <= 24'd2500000; // 50ms点亮
                    end
                    default: begin
                        // 保持其他命令不变
                    end
                endcase
            end else begin
                // 在下一个周期清除串口音量控制信号
                uart_volume_up <= 1'b0;
                uart_volume_down <= 1'b0;
            end
        end
    end

    // 音量控制相关信号
    wire volume_up_led;
    wire volume_down_led;
    wire [3:0] volume_level;     // 4位支持0-9级别
    wire signed [15:0] volume_adjusted_left;
    wire signed [15:0] volume_adjusted_right;
    
    // 最终的使能信号（仅由串口控制）
    wire final_echo_enable = uart_echo_enable;
    wire final_noise_reduction_enable = uart_noise_reduction_enable;
    wire final_echo_effect_enable = uart_echo_effect_enable;
    
    // 合并LED指示信号
    wire combined_volume_up_led = volume_up_led | uart_volume_up_led;
    wire combined_volume_down_led = volume_down_led | uart_volume_down_led;
    
    // LED控制和状态寄存器
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // LED指示灯初始化
            led1 <= 1'b0;
            led2 <= 1'b0;
            led3 <= 1'b0;
            led4 <= 1'b0;
            led5 <= 1'b0;
        end else begin
            // LED控制：仅由串口控制
            led1 <= final_echo_enable;           // LED1 - 回声消除
            led2 <= final_noise_reduction_enable; // LED2 - 降噪
            led3 <= final_echo_effect_enable;    // LED3 - 回声效果
            
            // 音量控制LED指示（合并按钮和串口）
            led4 <= combined_volume_up_led;      // LED4 - 音量增大指示
            led5 <= combined_volume_down_led;    // LED5 - 音量减小指示
        end
    end

    // 音频数据处理
    reg adcfifo_read;
    wire [DATA_WIDTH - 1:0] adcfifo_readdata;
    wire adcfifo_empty;

    reg dacfifo_write;
    reg [DATA_WIDTH - 1:0] dacfifo_writedata;
    wire dacfifo_full;
    
    // 回声消除相关信号
    wire signed [15:0] echo_data_out_left;
    wire signed [15:0] echo_data_out_right;
    
    // 降噪相关信号
    wire signed [15:0] noise_reduced_left;
    wire signed [15:0] noise_reduced_right;
    
    // 新的回声效果相关信号
    wire signed [15:0] echo_effect_left;
    wire signed [15:0] echo_effect_right;
    wire echo_effect_valid;
    
    // 中间处理信号
    wire signed [15:0] processed_left;
    wire signed [15:0] processed_right;
    
    // 回声消除模块实例化
    echo_cancellation echo_cancellation_inst (
        .sck(I2S_BCLK),
        .clk(clk),
        .rst_n(reset_n),
        .echo_enable(final_echo_enable),
        .data_in_left(adcfifo_readdata[31:16]),
        .data_in_right(adcfifo_readdata[15:0]),
        .data_out_left(echo_data_out_left),
        .data_out_right(echo_data_out_right)
    );
    
    // 选择回声消除后的数据或原始数据
    assign processed_left = final_echo_enable ? echo_data_out_left : adcfifo_readdata[31:16];
    assign processed_right = final_echo_enable ? echo_data_out_right : adcfifo_readdata[15:0];
    
    // 降噪模块实例化 - 左声道
    advanced_noise_reduction noise_reduction_left (
        .clk(clk),
        .sck(I2S_BCLK),
        .rst_n(reset_n),
        .noise_reduction_enable(final_noise_reduction_enable),
        .data_in(processed_left),
        .data_out(noise_reduced_left)
    );
    
    // 降噪模块实例化 - 右声道
    advanced_noise_reduction noise_reduction_right (
        .clk(clk),
        .sck(I2S_BCLK),
        .rst_n(reset_n),
        .noise_reduction_enable(final_noise_reduction_enable),
        .data_in(processed_right),
        .data_out(noise_reduced_right)
    );
    
    // 极简回声效果模块实例化
    simple_echo_effect echo_effect_inst (
        .clk(clk),
        .sck(I2S_BCLK),
        .rst_n(reset_n),
        .echo_effect_enable(final_echo_effect_enable),
        .data_in_left(noise_reduced_left),
        .data_in_right(noise_reduced_right),
        .data_valid(adcfifo_read),
        .data_out_left(echo_effect_left),
        .data_out_right(echo_effect_right),
        .data_out_valid(echo_effect_valid)
    );
        
    // 音量控制模块实例化
    volume_control volume_control_inst (
        .clk(clk),
        .sck(I2S_BCLK),
        .rst_n(reset_n),
        .volume_up(button_s4),           // S4用于音量增大
        .volume_down(button_s3),         // S3用于音量减小
        .uart_volume_up(uart_volume_up), // 串口音量增大
        .uart_volume_down(uart_volume_down), // 串口音量减小
        .data_in_left(final_echo_effect_enable ? echo_effect_left : noise_reduced_left),
        .data_in_right(final_echo_effect_enable ? echo_effect_right : noise_reduced_right),
        .data_out_left(volume_adjusted_left),
        .data_out_right(volume_adjusted_right),
        .volume_level(volume_level),
        .volume_up_led(volume_up_led),
        .volume_down_led(volume_down_led)
    );
    
    // 最终数据选择
    always @(*) begin
        dacfifo_writedata = {volume_adjusted_left, volume_adjusted_right};
    end

    // ADC FIFO读取控制
    always @ (posedge clk or negedge reset_n)
    begin
        if (~reset_n)
        begin
            adcfifo_read <= 1'b0;
        end
        else if (~adcfifo_empty)
        begin
            adcfifo_read <= 1'b1;
        end
        else
        begin
            adcfifo_read <= 1'b0;
        end
    end

    // DAC FIFO写入控制
    always @ (posedge clk or negedge reset_n)
    begin
        if(~reset_n)
            dacfifo_write <= 1'd0;
        else if(~dacfifo_full && (~adcfifo_empty)) begin
            dacfifo_write <= 1'd1;
        end
        else begin
            dacfifo_write <= 1'd0;
        end
    end

    // I2S接收模块
    i2s_rx 
    #(
        .DATA_WIDTH(DATA_WIDTH) 
    ) i2s_rx_inst
    (
        .reset_n(reset_n),
        .bclk(I2S_BCLK),
        .adclrc(I2S_RCLK),
        .adcdat(I2S_DI),
        .adcfifo_rdclk(clk),
        .adcfifo_read(adcfifo_read),
        .adcfifo_empty(adcfifo_empty),
        .adcfifo_readdata(adcfifo_readdata)
    );
    
    // I2S发送模块
    i2s_tx
    #(
         .DATA_WIDTH(DATA_WIDTH)
    ) i2s_tx_inst
    (
         .reset_n(reset_n),
         .dacfifo_wrclk(clk),
         .dacfifo_wren(dacfifo_write),
         .dacfifo_wrdata(dacfifo_writedata),
         .dacfifo_full(dacfifo_full),
         .bclk(I2S_BCLK),
         .daclrc(I2S_RCLK),
         .dacdat(I2S_DO)
    );

endmodule