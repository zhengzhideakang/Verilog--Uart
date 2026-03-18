/*
 * @Author       : Xu Xiaokang
 * @Email        : XudaKang_up@qq.com
 * @Date         : 2026-03-14
 * @Filename     : tb_uartDriver.v
 * @Description  : UART 发送器测试平台，修正激励生成时序，避免信号竞争
 */

/*
! 模块功能:
* 思路:
* 1.
~ 注意:
~ 1.
% 其它
*/

`default_nettype none

module tb_uartDriver();

//++ 仿真时间尺度 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
timeunit 1ns;
timeprecision 1ps;
//-- 仿真时间尺度 ------------------------------------------------------------


//++ 测试模块实例化 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
parameter CLK_FREQ_MHZ = 10;                    // 时钟频率 100MHz
parameter CLK_FREQ_DIV_BAUD_INIT_VALUE = 868;    // 100MHz/115200 ≈ 868，取整
parameter DATA_BITS    = 8;
parameter PARITY       = "ODD";                 // 可改为 "ODD", "EVEN", "MARK", "SPACE"
parameter STOP_BITS    = "1.5";                     // 可改为 "1.5", "2"

logic uart_tx_begin;
logic uart_tx_end;
logic [DATA_BITS-1 : 0] uart_tx_data;
logic uart_tx_is_busy;
logic [23:0] clk_freq_div_baud = 4;
logic uart_tx;
logic clk;
logic rstn;

uartTx #(
  .CLK_FREQ_MHZ                 (CLK_FREQ_MHZ                ),
  .CLK_FREQ_DIV_BAUD_INIT_VALUE (CLK_FREQ_DIV_BAUD_INIT_VALUE),
  .DATA_BITS                    (DATA_BITS                   ),
  .PARITY                       (PARITY                      ),
  .STOP_BITS                    (STOP_BITS                   )
) uartTx_inst (.*);



logic [DATA_BITS-1 : 0] uart_rx_data;
logic uart_rx_data_valid;
logic uart_rx_is_busy   ;
logic uart_rx_parity_err;
logic uart_rx;

uartRx #(
  .CLK_FREQ_MHZ                 (CLK_FREQ_MHZ                ),
  .CLK_FREQ_DIV_BAUD_INIT_VALUE (CLK_FREQ_DIV_BAUD_INIT_VALUE),
  .DATA_BITS                    (DATA_BITS                   ),
  .PARITY                       (PARITY                      ),
  .STOP_BITS                    (STOP_BITS                   )
) uartRx_inst (.*);

assign uart_rx = uart_tx;
//-- 测试模块实例化 ------------------------------------------------------------


//++ 生成时钟 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam CLKT = 2;
initial begin
  clk = 0;
  forever #(CLKT / 2) clk = ~clk;
end
//-- 生成时钟 ------------------------------------------------------------


//++ 测试过程 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
logic [3:0] uart_tx_end_cnt;
initial begin
  #(CLKT * 0.51);
  rstn = 0;
  #(CLKT * 10);
  rstn = 1;
  wait(uart_tx_end_cnt == 10)
  $finish;
end
//-- 测试过程 ------------------------------------------------------------


//++ 生成测试开始信号和数据 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
logic rstn_r1;
always_ff @(posedge clk) begin
  rstn_r1 <= rstn;
end

logic rstn_pedge;
assign rstn_pedge = rstn && ~rstn_r1;

always_ff @(posedge clk) begin
  if (~rstn)
    uart_tx_begin <= 1'b0;
  else if (rstn_pedge || (~uart_tx_is_busy &&  ~uart_rx_is_busy))
    uart_tx_begin <= 1'b1;
  else
    uart_tx_begin <= 1'b0;
end

always_ff @(posedge clk) begin
  if (~rstn)
    uart_tx_data <= 'd5;
  else if (uart_tx_begin)
    uart_tx_data <= uart_tx_data + 1'b1;
end

// always_ff @(posedge clk) begin
//   if (~rstn)
//     clk_freq_div_baud <= 'd1;
//   else if (uart_tx_begin)
//     clk_freq_div_baud <= clk_freq_div_baud + 1'b1;
// end

always_ff @(posedge clk) begin
  if (~rstn)
    uart_tx_end_cnt <= 0;
  else if (uart_tx_end)
    uart_tx_end_cnt <= uart_tx_end_cnt + 1;
end
//-- 生成测试开始信号和数据 ------------------------------------------------------------


endmodule
`resetall