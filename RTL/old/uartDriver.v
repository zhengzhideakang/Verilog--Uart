/*
 * @Author       : Xu Xiaokang
 * @Email        : XudaKang_up@qq.com
 * @Date         : 2022-05-05 11:11:22
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2025-12-12 23:32:31
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
  parameter CLK_FREQ_MHZ = 100,    // 时钟频率(MHz), 默认100
  parameter BAUD         = 115200, // 任意波特率, 9600, 19200, 38400, 57600, 115200(默认), 230400, 460800, 921600等
  parameter DATA_BITS    = 8,      // 数据位宽度, 可选5, 6, 7, 8(默认)
  parameter PARITY       = "NONE", // 校验, 可选"NONE"(默认), "ODD", "EVEN", "MARK", "SPACE"
  parameter STOP_BITS    = 1,      // 停止位宽度, 可选1(默认), 1.5, 2
  parameter RS485_MODE_EN = 0      // 485半双工模式使能, 默认0表示全双工模式, 1表示半双工模式
)(
  output wire                     uart_tx_is_busy, // 发送正在进行
  input  wire [DATA_BITS - 1 : 0] uart_tdata,      // 要发送的数据
  input  wire                     uart_tdata_valid,// 指示发送数据有效; 此信号上升沿有效
  output wire                     uart_tx_ready,   // 发送准备就绪

  output wire         uart_tx_485_de, // 发送过程指示信号, 用于485这种半双工通信的发送使能

  output wire [7 : 0] uart_rdata,       // 接收到的数据
  output wire         uart_rdata_valid, // 接收到的数据有效; 此信号上升沿有效
  output wire         uart_rdata_error, // 接收过程未通过校验

  output wire uart_tx,
  input  wire uart_rx,

  input  wire clk,
  input  wire rstn
);


//++ 实例化串口发送模块 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
uartTx #(
  .CLK_FREQ_MHZ    (CLK_FREQ_MHZ   ),
  .BAUD            (BAUD           ),
  .DATA_BITS       (DATA_BITS      ),
  .PARITY          (PARITY         ),
  .STOP_BITS       (STOP_BITS      )
) uartTx_u0 (
  .uart_tx_is_busy (uart_tx_is_busy ),
  .tdata           (uart_tdata      ),
  .tdata_valid     (uart_tdata_valid),
  .uart_tx_ready   (uart_tx_ready   ),
  .uart_tx         (uart_tx         ),
  .clk             (clk             ),
  .rstn            (rstn            )
);
//-- 实例化串口发送模块 ------------------------------------------------------------


//++ 实例化串口接收模块 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
wire uart_rx_is_busy;

uartRx #(
  .CLK_FREQ_MHZ    (CLK_FREQ_MHZ   ),
  .BAUD            (BAUD           ),
  .DATA_BITS       (DATA_BITS      ),
  .PARITY          (PARITY         ),
  .STOP_BITS       (STOP_BITS      )
) uartRx_u0 (
  .uart_rx_is_busy (uart_rx_is_busy ),
  .rdata           (uart_rdata      ),
  .rdata_valid     (uart_rdata_valid),
  .rdata_error     (uart_rdata_error),
  .uart_rx         (uart_rx         ),
  .clk             (clk             ),
  .rstn            (rstn            )
);
//-- 实例化串口接收模块 ------------------------------------------------------------


//++ 485半双工收发使能控制 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// 主机发送优先, 当收发均空闲时, 有待发送数据过来, 进入发送状态, 拉高de
// 如果已经在接收状态, 那么必须等待这一帧数据接收完毕
assign uart_tx_485_de = uart_tx_is_busy && ~uart_rx_is_busy;
//-- 485半双工收发使能控制 ------------------------------------------------------------


endmodule