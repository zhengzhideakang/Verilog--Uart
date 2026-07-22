/*
 * @Author       : Xu Xiaokang
 * @Email        : XudaKang_up@qq.com
 * @Date         : 2022-05-05 11:11:22
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2026-06-12 00:12:20
 * @Filename     : uartDriver.v
 * @Description  : UART驱动, 包括发送和接收
*/

/*
! 模块功能:
* 思路:
  1.
*/

module uartDriver
#(
  parameter [0:0] DATA_BITS_EXT_EN = 0, // 数据位宽扩展使能, 1使能, 此时位宽[4, 64]; 0不使能, 位宽[5, 8]
  parameter integer DATA_BITS = 8,  // 数据位宽度，可选5, 6, 7, 8(默认), 或扩展4~64
  parameter PARITY    = "NONE",     // 校验，可选"NONE"(默认), "ODD", "EVEN", "MARK", "SPACE"
  parameter STOP_BITS = "1"   ,     // 停止位宽度，可选"1"(默认), "1.5", "2"
  parameter integer BAUD_INIT_VALUE = 115200, // 初始波特率 115200
  parameter integer CLK_FREQ_MHZ = 100    // 时钟频率(MHz)，默认100
)(
  input  wire [15:0]            clk_freq_div_baud, // 时钟频率与波特率的比值

  input  wire                   uart_tx_begin,     // 指示单次发送开始，上升沿有效
  input  wire [DATA_BITS-1 : 0] uart_tx_data,      // 要发送的数据
  output wire                   uart_tx_is_busy,   // 指示发送正在进行
  output wire                   uart_tx_end,       // 指示单次发送完成，仅持续一个clk周期

  output wire [DATA_BITS-1 : 0] uart_rx_data,       // 接收到的数据
  output wire                   uart_rx_data_valid, // 接收完成脉冲
  output wire                   uart_rx_is_busy,    // 接收正在进行
  output wire                   uart_rx_parity_err, // 奇偶校验错误

  output wire uart_tx_485_de, // 发送过程指示信号, 用于485这种半双工通信的发送使能

  //~ 硬线连接
  output wire uart_tx,
  input  wire uart_rx,

  input  wire clk,
  input  wire rstn
);


//++ 实例化串口发送模块 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
uartTx #(
  .DATA_BITS_EXT_EN (DATA_BITS_EXT_EN ),
  .DATA_BITS        (DATA_BITS        ),
  .PARITY           (PARITY           ),
  .STOP_BITS        (STOP_BITS        ),
  .BAUD_INIT_VALUE  (BAUD_INIT_VALUE  ),
  .CLK_FREQ_MHZ     (CLK_FREQ_MHZ     )
) uartTx_inst (
  .clk_freq_div_baud(clk_freq_div_baud),
  .uart_tx_begin    (uart_tx_begin    ),
  .uart_tx_data     (uart_tx_data     ),
  .uart_tx_is_busy  (uart_tx_is_busy  ),
  .uart_tx_end      (uart_tx_end      ),
  .uart_tx          (uart_tx          ),
  .clk              (clk              ),
  .rstn             (rstn             )
);
//-- 实例化串口发送模块 ------------------------------------------------------------


//++ 实例化串口接收模块 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
uartRx #(
  .DATA_BITS_EXT_EN (DATA_BITS_EXT_EN ),
  .DATA_BITS        (DATA_BITS        ),
  .PARITY           (PARITY           ),
  .BAUD_INIT_VALUE  (BAUD_INIT_VALUE  ),
  .CLK_FREQ_MHZ     (CLK_FREQ_MHZ     )
) uartRx_inst (
  .clk_freq_div_baud (clk_freq_div_baud ),
  .uart_rx_data      (uart_rx_data      ),
  .uart_rx_data_valid(uart_rx_data_valid),
  .uart_rx_is_busy   (uart_rx_is_busy   ),
  .uart_rx_parity_err(uart_rx_parity_err),
  .uart_rx           (uart_rx           ),
  .clk               (clk               ),
  .rstn              (rstn              )
);
//-- 实例化串口接收模块 ------------------------------------------------------------


//++ 485半双工收发使能控制 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// 主机发送优先, 当收发均空闲时, 有待发送数据过来, 进入发送状态, 拉高de
// 如果已经在接收状态, 那么必须等待这一帧数据接收完毕
assign uart_tx_485_de = uart_tx_is_busy && ~uart_rx_is_busy;
//-- 485半双工收发使能控制 ------------------------------------------------------------


endmodule