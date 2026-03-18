/*
 * @Author       : Xu Xiaokang
 * @Email        :
 * @Date         : 2026-03-12 22:37:07
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2026-03-18 23:01:56
 * @Filename     : hpcTop.v
 * @Description  : HPC核心板顶层模块
*/

/*
! 模块功能: hpc板最顶层模块
* 思路:
* 1.
~ 注意:
~ 1.
% 其它
*/

`default_nettype none

module hpcTop
#(
  parameter [1:0] FUNCTION_SELECT = 1 // 功能选择, 可选0=集控; 1=主控; 2=从控; 3=未定义
)(
  /*
  * ===================================================================
  * =========================== 核心板相关信号 ===========================
  * ===================================================================
  */
  //~ LED灯
  output wire led0, // 绿色运行灯
  output wire led1, // 红色故障灯

  //~ UART调试口, 外部连接UART转USB芯片, 最大波特率6Mbps
  output wire fpga_uart_tx,
  input  wire fpga_uart_rx,

  //~ 外部输入始终与复位
  input wire fpga_clk,
  input wire fpga_arstn // 外部电压监控, 作为FPGA的输入异步复位
);


//++ 实例化全局时钟与复位模块 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam CLK_FREQ_MHZ = 100;
wire clk;
wire rstn;
globalClkAndRst #(
  .FPGA_SOFT (), // 可选"Vivado"(默认), "Quartus", "TD", "PDS"
  .POWER_ON_RSTN_CLK_WIDTH() // 上电复位持续(2^POWER_ON_RSTN_CLK_WIDTH)个clk周期, 默认为3
) globalClkAndRst_inst (
  .clk   (clk), // output PLL 时钟
  .rstn       (rstn    ), // output 同步复位
  .arstn      (        ), // output 异步复位
  .fpga_clk   (fpga_clk), // input 板卡上FPGA的全局输入时钟
  .fpga_arstn (fpga_arstn) //* input 外部异步复位 必须连接或者赋值1'b1, 不连接则rst和arstn恒为低电平
);
//-- 实例化全局时钟与复位模块 ------------------------------------------------------------


//++ LED驱动 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam LED_CLK_CNT_MAX = CLK_FREQ_MHZ * 1000 * 1000;
reg [$clog2(LED_CLK_CNT_MAX+1)-1 : 0] led_clk_cnt;
always @(posedge clk) begin
  if (~rstn)
    led_clk_cnt <= 'd0;
  else if (led_clk_cnt < LED_CLK_CNT_MAX)
    led_clk_cnt <= led_clk_cnt + 1'b1;
  else
    led_clk_cnt <= 'd0;
end

assign led0 = led_clk_cnt < LED_CLK_CNT_MAX / 2;
assign led1 = led_clk_cnt > LED_CLK_CNT_MAX / 2;
//-- LED驱动 ------------------------------------------------------------


//++ 实例化UART驱动 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam BUAD_INIT_VALUE = 6000000; // 初始波特率, 默认115200
localparam DATA_BITS       = 6     ; // 数据位宽度，可选5, 6, 7, 8(默认)
localparam PARITY          = "EVEN"; // 校验，可选"NONE"(默认), "ODD", "EVEN", "MARK", "SPACE"
localparam STOP_BITS       = "2" ; // 停止位宽度，可选"1"(默认), "1.5", "2"

wire [15:0] clk_freq_div_baud;
wire uart_tx_is_busy;
wire uart_tx_end;
wire [DATA_BITS - 1 : 0] uart_rx_data;
wire uart_rx_data_valid;
wire uart_rx_is_busy;
wire uart_rx_parity_err;
wire uart_tx_485_de;
// uartDriver # (
//     .CLK_FREQ_MHZ    (CLK_FREQ_MHZ    ),
//     .BUAD_INIT_VALUE (BUAD_INIT_VALUE ),
//     .DATA_BITS       (DATA_BITS       ),
//     .PARITY          (PARITY          ),
//     .STOP_BITS       (STOP_BITS       )
// ) uartDriver_inst (
//     .clk_freq_div_baud (clk_freq_div_baud ),
//     .uart_tx_begin     (uart_rx_data_valid),
//     .uart_tx_data      (uart_rx_data      ),
//     .uart_tx_is_busy   (uart_tx_is_busy   ),
//     .uart_tx_end       (uart_tx_end       ),
//     .uart_rx_data      (uart_rx_data      ),
//     .uart_rx_data_valid(uart_rx_data_valid),
//     .uart_rx_is_busy   (uart_rx_is_busy   ),
//     .uart_rx_parity_err(uart_rx_parity_err),
//     .uart_tx_485_de    (uart_tx_485_de    ),
//     .uart_tx           (uart_txd           ),
//     .uart_rx           (uart_rxd           ),
//     .clk               (clk               ),
//     .rstn              (rstn              )
// );

wire uart_tx_fifo_full;
wire uart_tx_fifo_wr_en_vio;
reg uart_tx_fifo_wr_en_vio_r1;
always @(posedge clk) begin
  uart_tx_fifo_wr_en_vio_r1 <= uart_tx_fifo_wr_en_vio;
end

wire uart_tx_fifo_wr_en_vio_pedge = uart_tx_fifo_wr_en_vio && ~uart_tx_fifo_wr_en_vio_r1;

uartDriverWithTxFIFO # (
    .TX_FIFO_ADDR_WIDTH (5              ),
    .RAM_STYLE          ("block"        ),
    .CLK_FREQ_MHZ       (CLK_FREQ_MHZ   ),
    .BUAD_INIT_VALUE    (BUAD_INIT_VALUE),
    .DATA_BITS          (DATA_BITS      ),
    .PARITY             (PARITY         ),
    .STOP_BITS          (STOP_BITS      ),
    .RS485_MODE_EN      (               )
) uartDriverWithTxFIFO_inst (
    .clk_freq_div_baud  (clk_freq_div_baud  ),
    .uart_tx_fifo_din   (uart_rx_data       ),
    .uart_tx_fifo_wr_en (uart_rx_data_valid),
    .uart_tx_fifo_full  (uart_tx_fifo_full  ),
    .uart_tx_is_busy    (uart_tx_is_busy    ),
    .uart_tx_end        (uart_tx_end        ),
    .uart_rx_data       (uart_rx_data       ),
    .uart_rx_data_valid (uart_rx_data_valid ),
    .uart_rx_is_busy    (uart_rx_is_busy    ),
    .uart_rx_parity_err (uart_rx_parity_err ),
    .uart_tx_485_de     (uart_tx_485_de     ),
    .uart_tx            (fpga_uart_tx       ),
    .uart_rx            (fpga_uart_rx       ),
    .clk                (clk                ),
    .rstn               (rstn               )
);

//-- 实例化UART驱动 ------------------------------------------------------------


//++ VIO ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

vio_0 vio_0_u0 (
  .clk        (clk       ),
  .probe_out0 (clk_freq_div_baud)
);
//-- VIO ------------------------------------------------------------


endmodule
`resetall