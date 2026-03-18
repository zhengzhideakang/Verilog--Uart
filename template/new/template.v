/*
 * @Author       : Xu Xiaokang
 * @Email        :
 * @Date         : 2026-03-15 02:46:04
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2026-03-18 23:54:31
 * @Filename     :
 * @Description  :
*/


//++ 实例化UART驱动 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam BUAD_INIT_VALUE = 115200; // 初始波特率, 默认 115200
localparam DATA_BITS       = 8     ; // 数据位宽度，可选5, 6, 7, 8(默认)
localparam PARITY          = "NONE"; // 校验，可选"NONE"(默认), "ODD", "EVEN", "MARK", "SPACE"
localparam STOP_BITS       = "1"   ; // 停止位宽度，可选"1"(默认), "1.5", "2"

wire [15:0] clk_freq_div_baud;
wire uart_tx_begin;
wire [DATA_BITS-1:0] uart_tx_data;
wire uart_tx_is_busy;
wire uart_tx_end;
wire [DATA_BITS-1:0] uart_rx_data;
wire uart_rx_data_valid;
wire uart_rx_is_busy;
wire uart_rx_parity_err;
wire uart_tx_485_de;

uartDriver #(
  .CLK_FREQ_MHZ    (CLK_FREQ_MHZ    ),
  .BUAD_INIT_VALUE (BUAD_INIT_VALUE ),
  .DATA_BITS       (DATA_BITS       ),
  .PARITY          (PARITY          ),
  .STOP_BITS       (STOP_BITS       )
) uartDriver_inst (
  .clk_freq_div_baud  (clk_freq_div_baud  ),
  .uart_tx_begin      (uart_tx_begin      ),
  .uart_tx_data       (uart_tx_data       ),
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


//++ 实例化UART TxWithFIFO 驱动 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam BUAD_INIT_VALUE = 115200; // 初始波特率, 默认 115200
localparam DATA_BITS       = 8     ; // 数据位宽度，可选5, 6, 7, 8(默认)
localparam PARITY          = "NONE"; // 校验，可选"NONE"(默认), "ODD", "EVEN", "MARK", "SPACE"
localparam STOP_BITS       = "1"   ; // 停止位宽度，可选"1"(默认), "1.5", "2"
localparam RS485_MODE_EN   = 0     ; // 1表示半双工, 0表示全双工

wire [23:0] clk_freq_div_baud;
wire [DATA_BITS-1:0] uart_tx_fifo_din;
wire uart_tx_fifo_wr_en;
wire uart_tx_fifo_full;
wire uart_tx_is_busy;
wire uart_tx_end;
wire [DATA_BITS-1:0] uart_rx_data;
wire uart_rx_data_valid;
wire uart_rx_is_busy;
wire uart_rx_parity_err;
wire uart_tx_485_de;

uartDriverWithTxFIFO #(
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
  .uart_tx_fifo_wr_en (uart_tx_fifo_wr_en ),
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
//-- 实例化UART TxWithFIFO 驱动 ------------------------------------------------------------

