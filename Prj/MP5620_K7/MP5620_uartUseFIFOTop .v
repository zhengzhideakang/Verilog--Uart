/*
 * @Author       : Xu Dakang
 * @Email        : XudaKang_up@qq.com
 * @Date         : 2022-04-20 09:34:40
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2024-09-21 00:51:03
 * @Filename     :
 * @Description  :
*/

/*
! 模块功能: uart收发，实现环路测试，即将接收到的数据发出来
! Vivado工程，使用的测试板卡为MDY MP5620, 片上FPGA型号K7, Uart转USB芯片型号CP2102
* 思路:
  1.
*/

module MP5620_uartUseFIFOTop
(
  output wire uart_tx,
  input  wire uart_rx,

  input wire fpga_clk_p,
  input wire fpga_clk_n
);


//++ 时钟与复位 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
wire clk;
wire locked;
clk_wiz_0  clk_wiz_0_u0 (
  .clk_in1_p (fpga_clk_p),
  .clk_in1_n (fpga_clk_n),
  .locked    (locked    ),
  .clk_out1  (clk       )
);


localparam RSTN_CLK_WIDTH = 3;
reg [RSTN_CLK_WIDTH + 1 : 0] rstn_cnt;
always @(posedge clk) begin // 使用最慢的时钟
  if (locked)
    if (~(&rstn_cnt))
      rstn_cnt <= rstn_cnt + 1'b1;
    else
      rstn_cnt <= rstn_cnt;
  else
    rstn_cnt <= 'd0;
end

/*
  初始为0, locked为高后经过2^RSTN_CLK_WIDTH个clk周期, rstn为1,
  再过2^RSTN_CLK_WIDTH个clk周期, rstn为0,
  在过2^RSTN_CLK_WIDTH个clk周期后, rstn为1, 后续会保持1
  总的来说, 复位低电平有效持续(2^RSTN_CLK_WIDTH)个clk周期
*/
wire rstn = rstn_cnt[RSTN_CLK_WIDTH];
//-- 时钟与复位 ------------------------------------------------------------


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


endmodule