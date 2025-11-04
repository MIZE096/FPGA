module echo_fifo (
  input clk,
  input rst,
  input wr_en,
  input [15:0] wr_data,
  output wr_full,
  output almost_full,
  output [14:0] wr_water_level,
  input rd_en,
  output [15:0] rd_data,
  output rd_empty
);

// 使用16位宽度，32768深度的FIFO以获得足够的延迟
async_fifo #(
  .DATA_WIDTH(16),
  .ADDR_WIDTH(15),  // 2^15 = 32768
  .FULL_AHEAD(1),
  .SHOWAHEAD_EN(1)
) fifo_inst (
  .reset(rst),
  // 写端口
  .wrclk(clk),
  .wren(wr_en),
  .wrdata(wr_data),
  .full(wr_full),
  .almost_full(almost_full),
  .wrusedw(wr_water_level),
  // 读端口
  .rdclk(clk),
  .rden(rd_en),
  .rddata(rd_data),
  .empty(rd_empty)
);

endmodule