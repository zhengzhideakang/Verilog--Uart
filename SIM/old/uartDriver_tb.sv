/*
 * @Author       : Xu Xiaokang
 * @Email        :
 * @Date         : 2025-12-22 00:20:13
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2025-12-22 01:07:51
 * @Filename     : uartDriver_tb.sv
 * @Description  : UART驱动模块仿真文件
*/

`default_nettype none

module uartDriver_tb();

timeunit 1ns;
timeprecision 100ps;

//++ 实例化驱动模块 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam CLK_FREQ_MHZ = 100;    // 时钟频率(MHz), 默认100
localparam INIT_BUAD    = 115200; // 初始波特率115200
localparam [15:0] CLK_FREQ_DIV_BUAD_INIT_VALUE = CLK_FREQ_MHZ * 1000 * 1000 / INIT_BUAD;
localparam DATA_BITS    = 8;     // 数据位宽度, 可选5, 6, 7, 8(默认)
localparam PARITY       = "NONE";// 校验, 可选"NONE"(默认), "ODD", "EVEN", "MARK", "SPACE"
localparam STOP_BITS    = 1;     // 停止位宽度, 可选1(默认), 1.5, 2

logic                   uart_tx_begin;
logic                   uart_tx_end;
logic [DATA_BITS-1 : 0] uart_tx_data;
logic                   uart_tx_is_busy;
logic [15:0]            clk_freq_div_buad;
logic  uart_tx;
logic clk;
logic rstn;

uartTx # (
  .CLK_FREQ_MHZ                 (CLK_FREQ_MHZ                ),
  .CLK_FREQ_DIV_BUAD_INIT_VALUE (CLK_FREQ_DIV_BUAD_INIT_VALUE),
  .DATA_BITS                    (DATA_BITS                   ),
  .PARITY                       (PARITY                      ),
  .STOP_BITS                    (STOP_BITS                   )
) uartTx_inst (
  .uart_tx_begin     (uart_tx_begin    ),
  .uart_tx_end       (uart_tx_end      ),
  .uart_tx_data      (uart_tx_data     ),
  .uart_tx_is_busy   (uart_tx_is_busy  ),
  .clk_freq_div_buad (clk_freq_div_buad),
  .uart_tx           (uart_tx          ),
  .clk               (clk              ),
  .rstn              (rstn             )
);
//-- 实例化驱动模块 ------------------------------------------------------------


//++ 生成时钟 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam CLKT = 2;
initial begin
  clk = 0;
  forever #(CLKT / 2) clk = ~clk;
end
//-- 生成时钟 ------------------------------------------------------------


initial begin
  rstn = 1'b0;
  uart_tx_begin = 1'b0;
  #(CLKT * 10.2)
  rstn = 1'b1;
  uart_tx_data = 'h46;
  clk_freq_div_buad = 'd10;
  #(CLKT * 10);
  repeat(2) begin
    clk_freq_div_buad = clk_freq_div_buad + 10;
    uart_tx_data = uart_tx_data + 1'b1;
    wait(~uart_tx_is_busy) uart_tx_begin = 1'b1;
    #(CLKT * 1) uart_tx_begin = 1'b0;
    #(CLKT * 10)
    wait(uart_tx_end);
  end
  #(CLKT * 10)
  $stop;
end


endmodule
`resetall