/*
 * @Author       : Xu Xiaokang
 * @Email        : xuxiaokang_up@qq.com
 * @Date         : 2024-09-14 11:40:11
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2024-09-21 00:54:59
 * @Filename     :
 * @Description  :
*/

/*
! 模块功能: uartRTUseFIFO实例化参考
*/


//++ 实例化Uart收发模块 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
wire [7:0] uart_rdata;
wire uart_rdata_valid;
wire uart_rdata_error;
wire uart_tx_fifo_full;

uartRTUseFIFO #(
  .CLK_FREQ_MHZ       (100   ), // 时钟频率(MHz), 默认100
  .BAUD               (115200), // 任意波特率, 9600, 19200, 38400, 57600, 115200(默认), 230400, 460800, 921600等
  .DATA_BITS          (8     ), // 数据位宽度,可选5, 6, 7, 8(默认)
  .PARITY             ("NONE"), // 校验, 可选"NONE"(默认), "ODD", "EVEN", "MARK", "SPACE"
  .STOP_BITS          (1     ), // 停止位宽度, 可选1(默认), 1.5, 2
  .RS485_MODE_EN      (0     )  // 485半双工模式使能, 默认0表示全双工模式, 1表示半双工模式
) uartRTUseFIFO_u0 (
  .uart_tx_fifo_din   (uart_rdata                            ),
  .uart_tx_fifo_wr_en (uart_rdata_valid && ~uart_tx_fifo_full),
  .uart_tx_fifo_full  (uart_tx_fifo_full ),
  .uart_tx_485_de     (                  ),
  .uart_rdata         (uart_rdata        ),
  .uart_rdata_valid   (uart_rdata_valid  ),
  .uart_rdata_error   (uart_rdata_error  ),
  .uart_tx            (uart_tx           ),
  .uart_rx            (uart_rx           ),
  .clk                (clk               ),
  .rstn               (rstn              )
);
//-- 实例化Uart收发模块 ------------------------------------------------------------