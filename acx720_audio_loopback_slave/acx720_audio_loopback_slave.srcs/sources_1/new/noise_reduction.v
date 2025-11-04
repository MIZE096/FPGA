module advanced_noise_reduction
#(  
    parameter DATA_WIDTH = 16
)
(
    input                       clk,
    input                       sck,
    input                       rst_n,
    input                       noise_reduction_enable,
    input   signed [DATA_WIDTH - 1:0]  data_in,
    output reg signed [DATA_WIDTH - 1:0]  data_out
);

    // 参数定义
    parameter NOISE_FLOOR = 16'd800;     // 噪声门限
    parameter ATTENUATION_FACTOR = 16'd4; // 衰减因子
    
    // 移动平均滤波器
    reg signed [15:0] data_buffer [0:7];
    reg [2:0] write_ptr;
    reg signed [18:0] sum; // 扩大位宽防止溢出
    
    // 帧能量计算相关
    reg signed [31:0] frame_energy;
    reg [5:0] energy_counter;
    reg signed [15:0] energy_buffer [0:63];
    reg [5:0] energy_write_ptr;
    
    // 移动平均值寄存器
    reg signed [15:0] moving_avg;
    
    integer i;
    
    // 初始化
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr <= 3'b0;
            sum <= 0;
            frame_energy <= 0;
            energy_counter <= 0;
            energy_write_ptr <= 0;
            moving_avg <= 0;
            for (i = 0; i < 8; i = i + 1) begin
                data_buffer[i] <= 0;
            end
            for (i = 0; i < 64; i = i + 1) begin
                energy_buffer[i] <= 0;
            end
            data_out <= 0;
        end else begin
            // 更新移动平均缓冲区
            sum <= sum - data_buffer[write_ptr] + data_in;
            data_buffer[write_ptr] <= data_in;
            write_ptr <= write_ptr + 1;
            
            // 计算移动平均值
            moving_avg <= sum[18:3]; // 除以8
            
            // 更新能量缓冲区
            energy_buffer[energy_write_ptr] <= (data_in > 0) ? data_in : -data_in;
            energy_write_ptr <= energy_write_ptr + 1;
            
            // 每64个样本计算一次帧能量
            if (energy_counter == 63) begin
                energy_counter <= 0;
                frame_energy <= 0;
                for (i = 0; i < 64; i = i + 1) begin
                    frame_energy <= frame_energy + energy_buffer[i];
                end
            end else begin
                energy_counter <= energy_counter + 1;
            end
            
            // 应用降噪算法
            if (noise_reduction_enable) begin
                // 噪声门限处理
                if ((data_in > -NOISE_FLOOR && data_in < NOISE_FLOOR) || 
                    (frame_energy < (64 * NOISE_FLOOR * 2))) begin
                    // 小信号或低能量帧使用移动平均进行平滑
                    data_out <= moving_avg;
                end else begin
                    // 大信号保留细节，轻微平滑
                    data_out <= (data_in * 3 + moving_avg) / 4;
                end
            end else begin
                // 降噪关闭，直接输出
                data_out <= data_in;
            end
        end
    end

endmodule