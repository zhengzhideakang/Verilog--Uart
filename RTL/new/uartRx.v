/*
 * @Author       : Xu Xiaokang
 * @Email        : xuxiaokang_up@qq.com
 * @Date         : 2022-05-03 20:12:16
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2026-03-18 00:38:42
 * @Filename     :
 * @Description  :
*/

/*
! 模块功能: UART接收
* 思路:
  1.按接收的阶段建立状态机, 空闲位 -> 开始位 -> 数据位 -> 校验位 -> 停止位 -> (空闲位) -> 开始位, 两帧之间可能没有空闲位
  2.当检测到uart_rx下降沿时, 从空闲位进入开始位, 并进行计数, 依据计数值依次进入数据位/校验位/停止位
  3.在每个数据位的中点采样接收数据
  4.依据接收数据计算得到校验值, 并与接收到的校验值比较, 不一致则在拉高rdata_valid的同时拉高rdata_error
  5.注意收发侧波特率不是完全一致的, 因为很多情况下, 模块时钟频率无法整除波特率(如100M时钟与115200的波特率), 接收需要允许一定的波特率偏差
! 版本更新记录
* 版本号 |  发布时间    | 修改说明
* V1.0  | 2022-05-02 | 初始发布
* V2.0  | 2026-03-13 | 状态机改为现代 case(state) 写法；增加在线更改波特率功能
*/

`default_nettype none

module uartRx
#(
  parameter integer CLK_FREQ_MHZ    = 100,    // 时钟频率(MHz)，默认100
  parameter integer BUAD_INIT_VALUE = 115200, // 初始波特率 115200
  parameter integer DATA_BITS = 8,            // 数据位宽度，可选5, 6, 7, 8(默认)
  parameter         PARITY    = "NONE"        // 校验，可选"NONE"(默认), "ODD", "EVEN", "MARK", "SPACE"
)(
  // FPGA接收数据与波特率控制接口
  /*
  * uart_rx 为输入串行数据，空闲时为高。
  * uart_rx_data_valid 在每帧接收完成时产生一个时钟周期的高脉冲，同时 uart_rx_data 输出有效数据。
  * uart_rx_is_busy 为高表示正在接收帧中。
  * uart_rx_parity_err 为高表示奇偶校验错误（仅在启用校验时有效）。
  */
  input  wire [15:0]            clk_freq_div_baud,  // 时钟频率与波特率的比值
  output reg  [DATA_BITS-1 : 0] uart_rx_data,       // 接收到的数据
  output reg                    uart_rx_data_valid, // 接收完成脉冲
  output wire                   uart_rx_is_busy,    // 接收正在进行
  output reg                    uart_rx_parity_err, // 奇偶校验错误

  // 硬线连接
  input  wire uart_rx,           // 串行输入

  // 时钟与复位
  input  wire clk,
  input  wire rstn
);


//++ 参数合法性检查 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam CLK_FREQ_DIV_BAUD_INIT_VALUE = CLK_FREQ_MHZ * 1000 * 1000 / BUAD_INIT_VALUE;

initial begin
  if (CLK_FREQ_MHZ < 10 || CLK_FREQ_MHZ > 300)
    $error("10 <= CLK_FREQ_MHZ must <= 300");
  if (CLK_FREQ_DIV_BAUD_INIT_VALUE < 1)
    $error("CLK_FREQ_DIV_BAUD_INIT_VALUE must >= 1");
  if (DATA_BITS < 5 || DATA_BITS > 8)
    $error("DATA_BITS must be 5, 6, 7, or 8");
  if (PARITY != "NONE" && PARITY != "ODD" && PARITY != "EVEN" &&
      PARITY != "MARK" && PARITY != "SPACE")
    $error("PARITY must be \"NONE\", \"ODD\", \"EVEN\", \"MARK\", or \"SPACE\"");
end
//-- 参数合法性检查 ------------------------------------------------------------


//++ 输入同步与边沿检测 +++++++++++++++++++++++++++++++++++++++++++++++++++++++++
(* mark_debug *)reg uart_rx_r1;
(* mark_debug *)reg uart_rx_r2;
always @(posedge clk) begin
  uart_rx_r1 <= uart_rx;
  uart_rx_r2 <= uart_rx_r1;
end

(* mark_debug *)wire this_rx_begin = ~uart_rx_r2;
//-- 输入同步与边沿检测 ---------------------------------------------------------


//++ 状态机定义 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam IDLE       = 5'd1 << 0;
localparam START_BIT  = 5'd1 << 1;
localparam DATA_BIT   = 5'd1 << 2;
localparam PARITY_BIT = 5'd1 << 3;
localparam STOP_BIT   = 5'd1 << 4;

localparam STATE_WIDTH = 5;
(* mark_debug *)reg [STATE_WIDTH-1:0] state;
(* mark_debug *)reg [STATE_WIDTH-1:0] next;

always @(posedge clk) begin
  if (~rstn)
    state <= IDLE;
  else
    state <= next;
end
//-- 状态机定义 ----------------------------------------------------------------


//++ 状态机转移逻辑 +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
(* mark_debug *)wire sample_point;  // 采样点脉冲（在每位中间）
(* mark_debug *)wire start_bit_end ;
(* mark_debug *)wire data_bit_end  ;
(* mark_debug *)wire parity_bit_end;
(* mark_debug *)wire stop_bit_end  ;
(* mark_debug *)wire stop_bit_ahead_end; // 停止期间, 未计数完成, 下一个开始位就来了

always @(*) begin
  next = state;
  case (state)
    IDLE:
      if (this_rx_begin)
        next = START_BIT;
    START_BIT:
      // 在起始位中间采样，若为高则视为噪声，返回IDLE
      if (sample_point && uart_rx_r2) // 采样点为高，无效起始位
        next = IDLE;
      else if (start_bit_end) //
        next = DATA_BIT;
    DATA_BIT:
      if (data_bit_end)
        next = (PARITY == "NONE") ? STOP_BIT : PARITY_BIT;
    PARITY_BIT:
      if (parity_bit_end)
        next = STOP_BIT;
    STOP_BIT:
      if (stop_bit_end || stop_bit_ahead_end)
        next = IDLE;
    default: next = IDLE;
  endcase
end
//-- 状态机转移逻辑 -------------------------------------------------------------


//++ 位内计数器及采样点 +++++++++++++++++++++++++++++++++++++++++++++++++++++++
(* mark_debug *)reg [15:0] one_bit_clk_cnt_max; // 位时钟计数最大值, 复位时幅初始值, 而在发送开始时刻, 更新新值
always @(posedge clk) begin
  if (~rstn)
    one_bit_clk_cnt_max <= CLK_FREQ_DIV_BAUD_INIT_VALUE - 1'b1;
  else
    case (state)
      IDLE:
        if (this_rx_begin && clk_freq_div_baud >= 'd1)
          one_bit_clk_cnt_max <= clk_freq_div_baud - 1'b1;
      default: ;
    endcase
end

(* mark_debug *)reg [15:0] one_bit_clk_cnt; // 当前位内部的时钟计数
always @(posedge clk) begin
  case (state)
    IDLE:
      one_bit_clk_cnt <= 'd0;
    START_BIT, DATA_BIT, PARITY_BIT, STOP_BIT:
      if (one_bit_clk_cnt < one_bit_clk_cnt_max)
        one_bit_clk_cnt <= one_bit_clk_cnt + 1'b1;
      else
        one_bit_clk_cnt <= 'd0;
    default: one_bit_clk_cnt <= 'd0;
  endcase
end

// 采样点：在 one_bit_clk_cnt 等于 (clk_freq_div_baud_locked >> 1) 时产生（即接近中间位置）
// 注：右移一位相当于除以2，若 clk_freq_div_baud_locked 为奇数，采样点略偏左，但误差在允许范围内
(* mark_debug *)wire [15:0] half_point = one_bit_clk_cnt_max >> 1;
assign sample_point = (state != IDLE) && (one_bit_clk_cnt == half_point);
//-- 位内计数器及采样点 ---------------------------------------------------------


//* =============================================================================
//* 各阶段结束信号生成
//* =============================================================================

//++ 生成开始位结束信号 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
assign start_bit_end = state == START_BIT && one_bit_clk_cnt == one_bit_clk_cnt_max;
//-- 生成开始位结束信号 ------------------------------------------------------------


//++ 生成数据位结束信号 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
(* mark_debug *)reg [2:0] data_bit_cnt;  // 已发送的数据位计数
always @(posedge clk) begin
  case (state)
    IDLE:
      data_bit_cnt <= 'd0;
    DATA_BIT:
      if (one_bit_clk_cnt == one_bit_clk_cnt_max)
        data_bit_cnt <= data_bit_cnt + 1'b1;
    default: ;
  endcase
end

assign data_bit_end = data_bit_cnt == DATA_BITS - 1'b1
                      && one_bit_clk_cnt == one_bit_clk_cnt_max
                      ;
//-- 生成数据位结束信号 ------------------------------------------------------------


//++ 数据位计数及移位寄存器 +++++++++++++++++++++++++++++++++++++++++++++++++++
(* mark_debug *)reg [DATA_BITS-1:0] rx_data_shift_reg;  // 移位寄存器，LSB first

always @(posedge clk) begin
  case (state)
    DATA_BIT:
      if (sample_point)
        rx_data_shift_reg <= {uart_rx_r2, rx_data_shift_reg[DATA_BITS-1:1]}; // LSB first，新位存入最高位
    default: ;
  endcase
end
//-- 数据位计数及移位寄存器 -----------------------------------------------------


//++ 校验位计算 与生成校验位信号 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
(* mark_debug *)reg parity_calculated; // 根据数据和校验方式计算出的期望校验位

generate
if (PARITY == "ODD") begin
  always @(posedge clk) begin
    case (state)
      PARITY_BIT:
        parity_calculated <= ~(^rx_data_shift_reg); // 数据位中1个数为奇数时，校验位应为0
      default: ;
    endcase
  end
end else if (PARITY == "EVEN") begin
  always @(posedge clk) begin
    case (state)
      PARITY_BIT:
        parity_calculated <= (^rx_data_shift_reg); // 数据位中1个数为奇数时，校验位应为1
      default: ;
    endcase
  end
end else if (PARITY == "MARK") begin
  always @(*) parity_calculated = 1'b1;
end else if (PARITY == "SPACE") begin
  always @(*) parity_calculated = 1'b0;
end else begin // "NONE"
  always @(*) parity_calculated = 1'b0; // 未使用
end
endgenerate

assign parity_bit_end = state == PARITY_BIT && one_bit_clk_cnt == one_bit_clk_cnt_max;
//-- 校验位计算 与生成校验位信号 ----------------------------------------------------------------


//++ 生成停止位结束信号 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
assign stop_bit_end = state == STOP_BIT && one_bit_clk_cnt == one_bit_clk_cnt_max;
assign stop_bit_ahead_end = state == STOP_BIT
                          && (one_bit_clk_cnt >= (one_bit_clk_cnt_max >> 1))
                          && ~uart_rx_r2
                          ;
//-- 生成停止位结束信号 ------------------------------------------------------------


//++ 输出接收到的数据 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
reg [STATE_WIDTH-1:0] prev_state;
always @(posedge clk) begin
  prev_state <= state;
end

always @(posedge clk) begin
  case (state)
    STOP_BIT:
      if (state != prev_state)
        uart_rx_data <= rx_data_shift_reg;
    default: ;
  endcase
end

always @(posedge clk) begin
  uart_rx_data_valid <= 1'b0;
  case (state)
    STOP_BIT:
      if (state != prev_state)
        uart_rx_data_valid <= 1'b1;
    default: ;
  endcase
end
//-- 输出接收到的数据 ------------------------------------------------------------


//++ 其它输出信号生成 +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
assign uart_rx_is_busy = (state != IDLE);

generate
if (PARITY != "NONE") begin
  // 采样校验位
  reg sampled_parity;
  always @(posedge clk) begin
    case (state)
      PARITY_BIT:
        if (sample_point)
          sampled_parity <= uart_rx_r2;
      default: ;
    endcase
  end
  always @(posedge clk) begin
    uart_rx_parity_err <= 1'b0;
    case (state)
      STOP_BIT:
        if (stop_bit_end && parity_calculated != sampled_parity)
          uart_rx_parity_err <= 1'b1;
      default: ;
    endcase
  end
end else begin
  always @(*) uart_rx_parity_err = 1'b0;
end
endgenerate

//-- 其它输出信号生成 ---------------------------------------------------------------


endmodule
`resetall