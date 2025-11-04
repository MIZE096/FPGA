module simple_multi_16x16 (
  input signed [15:0] a,
  input signed [15:0] b,
  input clk,
  input rst,
  input ce,
  output reg signed [31:0] p
);

reg signed [15:0] a_reg, b_reg;

always @(posedge clk or posedge rst) begin
  if (rst) begin
    a_reg <= 16'd0;
    b_reg <= 16'd0;
    p <= 32'd0;
  end else if (ce) begin
    a_reg <= a;
    b_reg <= b;
    p <= a_reg * b_reg;
  end
end

endmodule