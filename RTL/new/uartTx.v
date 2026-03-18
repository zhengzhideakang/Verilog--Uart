/*
 * @Author       : Xu Xiaokang
 * @Email        : XudaKang_up@qq.com
 * @Date         : 2022-04-22 11:01:56
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2026-03-18 00:39:31
 * @Filename     : uartTx.v
 * @Description  : UART 发送器，支持在线更改波特率及多种停止位宽度
*/

/*
! 模块功能:
* 思路:
* 1.
~ 注意:
~ 1.
% 其它
%
! 版本更新记录
* 版本号 |  发布时间    | 修改说明
* V1.0  | 2022-04-22 | 初始发布
* V2.0  | 2026-03-13 | 状态机改为现代 case(state) 写法；增加在线更改波特率功能
*/

`default_nettype none

module uartTx
#(
  parameter integer CLK_FREQ_MHZ    = 100,    // 时钟频率(MHz)，默认100
  parameter integer BUAD_INIT_VALUE = 115200, // 初始波特率 115200
  parameter integer DATA_BITS = 8,      // 数据位宽度，可选5, 6, 7, 8(默认)
  parameter PARITY    = "NONE", // 校验，可选"NONE"(默认), "ODD", "EVEN", "MARK", "SPACE"
  parameter STOP_BITS = "1"     // 停止位宽度，可选"1"(默认), "1.5", "2"
)(
  // FPGA发送数据与波特率控制接口
  /*
  * uart_tx_begin 控制UART单次发送开始, 上升沿有效, 仅在 uart_tx_is_busy 为低时起作用
  * 在连续写入时可使用 uart_tx_end 信号作为下一次UART发送的开始信号
  * 也可以使用 uart_tx_is_busy 的下降沿作为下一次UART发送的开始信号,
  * uart_tx_end 与 uart_tx_is_busy 的下降沿其实完全重合
  % 建议使用uart_tx_end, 它是寄存器输出信号, 时序性能更好, 此时发送间隔为1个clk周期
  % 更建议使用 uart_tx_end 经寄存器打一拍之后的信号作为开始信号, 时序余量更充足, 此时发送间隔为2个clk周期
  */
  input  wire [15:0]            clk_freq_div_baud, // 时钟频率与波特率的比值
  input  wire                   uart_tx_begin,     // 指示单次发送开始，上升沿有效
  input  wire [DATA_BITS-1 : 0] uart_tx_data,      // 要发送的数据
  output wire                   uart_tx_is_busy,   // 指示发送正在进行
  output reg                    uart_tx_end,       // 指示单次发送完成，仅持续一个clk周期

  // 硬线连接
  output reg  uart_tx,

  input  wire clk,
  input  wire rstn
);


//++ 参数合法性检查 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam CLK_FREQ_DIV_BAUD_INIT_VALUE = CLK_FREQ_MHZ * 1000 * 1000 / BUAD_INIT_VALUE;

initial begin
  if (CLK_FREQ_MHZ < 10 || CLK_FREQ_MHZ > 300)
    $error("10 <= CLK_FREQ_MHZ must <= 300");
  // 检查波特率初始值
  if (CLK_FREQ_DIV_BAUD_INIT_VALUE < 1)
    $error("CLK_FREQ_DIV_BAUD_INIT_VALUE must >= 1");
  // 检查数据位
  if (DATA_BITS < 5 || DATA_BITS > 8)
    $error("DATA_BITS must be 5, 6, 7, or 8");
  // 检查校验位
  if (PARITY != "NONE"
      && PARITY != "ODD"
      && PARITY != "EVEN"
      && PARITY != "MARK"
      && PARITY != "SPACE"
      )
    $error("PARITY Must be \"NONE\", \"ODD\", \"EVEN\", \"MARK\", or \"SPACE\"");
  // 检查停止位
  if (STOP_BITS != "1" && STOP_BITS != "1.5" && STOP_BITS != "2")
    $error("STOP_BITS must be \"1\", \"1.5\", or \"2\"");
end
//-- 参数合法性检查 ------------------------------------------------------------


//++ 输入寄存与信号预处理 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
reg uart_tx_begin_r1;
always @(posedge clk) begin
  uart_tx_begin_r1 <= uart_tx_begin;
end

wire uart_tx_begin_pedge = uart_tx_begin && ~uart_tx_begin_r1;

// 锁存当前帧要发送的数据
(* mark_debug *)reg [DATA_BITS-1 : 0] uart_tx_data_locked;
always @(posedge clk) begin
  if (uart_tx_begin_pedge)
    uart_tx_data_locked <= uart_tx_data;
  else
    uart_tx_data_locked <= uart_tx_data_locked;
end

// 真实的发送开始信号（仅当空闲且检测到上升沿时有效）
(* mark_debug *)wire this_tx_begin = ~uart_tx_is_busy && uart_tx_begin_pedge;
//-- 输入寄存与信号预处理 ------------------------------------------------------------

//++ 三段式状态机-状态定义 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//~ 状态定义
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
//-- 三段式状态机-状态定义 ------------------------------------------------------------


//++ 三段式状态机-状态跳转 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
(* mark_debug *)wire start_bit_end ;
(* mark_debug *)wire data_bit_end  ;
(* mark_debug *)wire parity_bit_end;
(* mark_debug *)wire stop_bit_end  ;

always @(*) begin
  next = state;
  case (state)
    IDLE:
      if (this_tx_begin)
        next = START_BIT;
    START_BIT:
      if (start_bit_end)
        next = DATA_BIT;
    DATA_BIT:
      if (data_bit_end)
        next = (PARITY == "NONE") ? STOP_BIT : PARITY_BIT;
    PARITY_BIT:
      if (parity_bit_end)
        next = STOP_BIT;
    STOP_BIT:
      if (stop_bit_end)
        next = IDLE;
    default: next = IDLE;
  endcase
end
//-- 三段式状态机-状态跳转 ------------------------------------------------------------


//++ 位时钟计数器 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
(* mark_debug *)reg [15:0] one_bit_clk_cnt_max; // 位时钟计数最大值, 复位时幅初始值, 而在发送开始时刻, 更新新值
always @(posedge clk) begin
  if (~rstn)
    one_bit_clk_cnt_max <= CLK_FREQ_DIV_BAUD_INIT_VALUE - 1'b1;
  else
    case (state)
      IDLE:
        if (this_tx_begin && clk_freq_div_baud >= 'd1)
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
//-- 位时钟计数器 ------------------------------------------------------------


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


//++ 生成校验位结束信号 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
assign parity_bit_end = state == PARITY_BIT && one_bit_clk_cnt == one_bit_clk_cnt_max;
//-- 生成校验位结束信号 ------------------------------------------------------------


//++ 生成停止位结束信号 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
generate
if (STOP_BITS == "1") begin
  assign stop_bit_end = state == STOP_BIT && one_bit_clk_cnt == one_bit_clk_cnt_max;
end else if (STOP_BITS == "1.5") begin
  reg stop_bit_cnt;
  always @(posedge clk) begin
    case (state)
      STOP_BIT:
        if (one_bit_clk_cnt == one_bit_clk_cnt_max)
          stop_bit_cnt <= 1'b1;
      default: stop_bit_cnt <= 1'b0;
    endcase
  end

  assign stop_bit_end = state == STOP_BIT
                        && stop_bit_cnt
                        && one_bit_clk_cnt == one_bit_clk_cnt_max >> 1
                        ;
end else begin
  reg stop_bit_cnt;
  always @(posedge clk) begin
    case (state)
      STOP_BIT:
        if (one_bit_clk_cnt == one_bit_clk_cnt_max)
          stop_bit_cnt <= 1'b1;
      default: stop_bit_cnt <= 1'b0;
    endcase
  end

  assign stop_bit_end = state == STOP_BIT
                        && stop_bit_cnt
                        && one_bit_clk_cnt == one_bit_clk_cnt_max
                        ;
end
endgenerate
//-- 生成停止位结束信号 ------------------------------------------------------------


//++ 生成奇偶校验位 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
(* mark_debug *)wire parity_value;

generate
if (PARITY == "ODD") begin  // 奇校验: 数据+校验位中1的个数为奇数, 即数据位中1数量为奇数时, 校验位为0; 否则为0
  assign parity_value = ~(^uart_tx_data_locked);
end else if (PARITY == "EVEN") begin // 偶校验：数据+校验位中1的个数为偶数
  assign parity_value = ^uart_tx_data_locked;
end else if (PARITY == "MARK") begin // 标志校验：校验位恒为1
  assign parity_value = 1'b1;
end else if (PARITY == "SPACE") begin // 空号校验：校验位恒为0
  assign parity_value = 1'b0;
end else begin // "NONE" 或其他，校验位恒为0（发送时不会进入PARITY_BIT状态）
  assign parity_value = 1'b0;
end
endgenerate
//-- 生成奇偶校验位 ------------------------------------------------------------


//++ uart_tx引脚赋值 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
(* mark_debug *)wire tx_data_bit = uart_tx_data_locked[data_bit_cnt];
always @(posedge clk) begin
  uart_tx <= 1'b1; // IDLE 和 STOP_BIT 均保持高电平
  case (state)
    START_BIT:  uart_tx <= 1'b0;
    DATA_BIT:   uart_tx <= tx_data_bit;
    PARITY_BIT: uart_tx <= parity_value;
    default: ;
  endcase
end
//-- uart_tx引脚赋值 ------------------------------------------------------------


//++ 输出发送状态指示信号 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
assign uart_tx_is_busy = (state != IDLE);
always @(posedge clk) begin
  uart_tx_end <= stop_bit_end; // 发送完成于停止位结束后延时一个时钟
end
//-- 输出发送状态指示信号 ------------------------------------------------------------


endmodule
`resetall