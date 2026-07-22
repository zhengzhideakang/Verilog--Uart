/*
 * @Author       : Xu Xiaokang
 * @Email        : XudaKang_up@qq.com
 * @Date         : 2022-05-05 11:11:22
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2026-06-11 00:52:10
 * @Filename     : uartDriverWithTxFIFO.v
 * @Description  : UART驱动, 包括发送和接收
*/

/*
! 模块功能:
* 思路:
  1.
*/

module uartDriverWithTxFIFO
#(
  parameter integer TX_FIFO_ADDR_WIDTH = 4, // 发送FIFO地址深度
  parameter RAM_STYLE = "distributed", // RAM类型, 可选"block", "distributed"(默认)
  parameter integer CLK_FREQ_MHZ    = 100,    // 时钟频率(MHz)，默认100
  parameter integer BAUD_INIT_VALUE = 115200, // 初始波特率 115200
  parameter integer DATA_BITS = 8,  // 数据位宽度，可选5, 6, 7, 8(默认)
  parameter PARITY    = "NONE",     // 校验，可选"NONE"(默认), "ODD", "EVEN", "MARK", "SPACE"
  parameter STOP_BITS = "1"   ,     // 停止位宽度，可选"1"(默认), "1.5", "2"
  parameter [0:0] RS485_MODE_EN = 0 // 1表示半双工, 0表示全双工
)(
  input  wire [15:0] clk_freq_div_baud, // 时钟频率与波特率的比值

  input  wire [DATA_BITS-1:0] uart_tx_fifo_din,
  input  wire                 uart_tx_fifo_wr_en,
  output wire                 uart_tx_fifo_full,
  output wire                 uart_tx_is_busy,   // 指示发送正在进行
  output wire                 uart_tx_end,       // 指示单次发送完成，仅持续一个clk周期

  output wire [DATA_BITS-1 : 0] uart_rx_data,       // 接收到的数据
  output wire                   uart_rx_data_valid, // 接收完成脉冲
  output wire                   uart_rx_is_busy,    // 接收正在进行
  output wire                   uart_rx_parity_err, // 奇偶校验错误

  output wire uart_tx_485_de, // 发送过程指示信号, 用于485这种半双工通信的发送使能

  output wire uart_tx,
  input  wire uart_rx,

  input  wire clk,
  input  wire rstn
);


//++ 输入发送FIFO ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
wire [DATA_BITS-1:0] uart_tx_fifo_dout;
wire                 uart_tx_fifo_rd_en;
wire                 uart_tx_fifo_empty;
syncFIFO #(
  .DATA_WIDTH (DATA_BITS         ),
  .ADDR_WIDTH (TX_FIFO_ADDR_WIDTH),
  .RAM_STYLE  (RAM_STYLE         ),
  .FWFT_EN    (1                 )
) syncFIFO_u0 (
  .din          (uart_tx_fifo_din   ),
  .wr_en        (uart_tx_fifo_wr_en ),
  .full         (uart_tx_fifo_full  ),
  .almost_full  (                   ),
  .dout         (uart_tx_fifo_dout  ),
  .rd_en        (uart_tx_fifo_rd_en ),
  .empty        (uart_tx_fifo_empty ),
  .almost_empty (                   ),
  .clk          (clk                ),
  .rst          (~rstn              )
);
//-- 输入发送FIFO ------------------------------------------------------------


//++ 实例化UART驱动模块 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
wire uart_tx_begin;
wire [DATA_BITS-1:0] uart_tx_data;
assign uart_tx_data = uart_tx_fifo_dout[DATA_BITS-1 : 0];

uartDriver # (
  .CLK_FREQ_MHZ   (CLK_FREQ_MHZ   ),
  .BAUD_INIT_VALUE(BAUD_INIT_VALUE),
  .DATA_BITS      (DATA_BITS      ),
  .PARITY         (PARITY         ),
  .STOP_BITS      (STOP_BITS      )
) uartDriver_inst (
  .clk_freq_div_baud (clk_freq_div_baud ),
  .uart_tx_begin     (uart_tx_begin     ),
  .uart_tx_data      (uart_tx_data      ),
  .uart_tx_is_busy   (uart_tx_is_busy   ),
  .uart_tx_end       (uart_tx_end       ),
  .uart_rx_data      (uart_rx_data      ),
  .uart_rx_data_valid(uart_rx_data_valid),
  .uart_rx_is_busy   (uart_rx_is_busy   ),
  .uart_rx_parity_err(uart_rx_parity_err),
  .uart_tx_485_de    (uart_tx_485_de    ),
  .uart_tx           (uart_tx           ),
  .uart_rx           (uart_rx           ),
  .clk               (clk               ),
  .rstn              (rstn              )
);
//-- 实例化UART驱动模块 ------------------------------------------------------------


//++ 发送数据FIFO接口连接 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
reg uart_tx_fifo_rd_en_tmp;
always @(posedge clk) begin
  uart_tx_fifo_rd_en_tmp <= uart_tx_begin;
end

assign uart_tx_fifo_rd_en = ~uart_tx_fifo_empty && uart_tx_fifo_rd_en_tmp;

generate
if (RS485_MODE_EN) begin
  assign uart_tx_begin = ~uart_tx_fifo_empty
                        && ~uart_tx_is_busy
                        && ~uart_rx_is_busy; // 半双工模式下, 接收时不发送
end else begin
  assign uart_tx_begin = ~uart_tx_fifo_empty && ~uart_tx_is_busy;
end
endgenerate
//-- 发送数据FIFO接口连接 ------------------------------------------------------------


endmodule