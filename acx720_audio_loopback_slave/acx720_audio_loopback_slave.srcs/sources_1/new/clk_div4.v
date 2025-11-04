module clk_div4(
    input wire clk_in,      // 输入时钟，例如50MHz
    input wire rst_n,       // 复位信号，低电平有效
    output reg clk_out      // 输出时钟，12.5MHz
);

// 计数器寄存器，用于计数输入时钟周期
reg [1:0] cnt;

// 计数器逻辑
always @(posedge clk_in or negedge rst_n) begin
    if (!rst_n) begin
        cnt <= 2'd0;       // 复位时计数器清零
    end else begin
        cnt <= cnt + 2'd1; // 每个时钟周期加1
    end
end

// 分频逻辑：每计数到2时翻转输出时钟
always @(posedge clk_in or negedge rst_n) begin
    if (!rst_n) begin
        clk_out <= 1'b0;   // 复位时输出低电平
    end else begin
        // 当计数器值为2'b10时翻转输出
        if (cnt == 2'd2) begin
            clk_out <= ~clk_out;
        end
    end
end

endmodule