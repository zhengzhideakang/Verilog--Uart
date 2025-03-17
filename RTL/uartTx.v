/*
 * @Author       : Xu Xiaokang
 * @Email        : XudaKang_up@qq.com
 * @Date         : 2022-04-22 11:01:56
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2024-09-20 23:13:18
 * @Filename     :
 * @Description  :
*/

/*
! 模块功能: UART发送
* 思路:
  1.根据波特率, 计算出要传输一位需要的时钟周期数
  2.当uart发送处于空闲期时(uart_tx_ready为1), 接收到tdata_valid高电平，开始发送，此时锁存要发送的数据
  3.按发送的阶段建立状态机，空闲位 -> 开始位 -> 数据位 -> 校验位 -> 停止位 -> (空闲位) -> 下一帧开始位
*/

module uartTx
#(
  parameter CLK_FREQ_MHZ = 100,    // 时钟频率(MHz), 默认100
  parameter BAUD         = 115200, // 任意波特率, 9600, 19200, 38400, 57600, 115200(默认), 230400, 460800, 921600等
  parameter DATA_BITS    = 8,      // 数据位宽度, 可选5, 6, 7, 8(默认)
  parameter PARITY       = "NONE", // 校验, 可选"NONE"(默认), "ODD", "EVEN", "MARK", "SPACE"
  parameter STOP_BITS    = 1       // 停止位宽度, 可选1(默认), 1.5, 2
)(
  output reg  uart_tx_is_busy, // 指示发送正在进行

  // 发送数据接口, 类似AXI-stream接口
  input  wire [DATA_BITS - 1 : 0]  tdata,       // 要发送的数据
  input  wire                      tdata_valid, // 指示发送数据有效, 此信号高电平有效
  output reg                       uart_tx_ready, // 发送准备就绪

  output reg  uart_tx,

  input  wire clk,
  input  wire rstn
);


//++ 生成发送开始信号 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
wire uart_tx_begin;
assign uart_tx_begin = tdata_valid && uart_tx_ready; // 发送开始
//-- 生成发送开始信号 ------------------------------------------------------------


//++ UART发送全程计数 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// 波特率对应的clk计数值, 当无法整除时, 小数部分被舍去, 所以真实的波特率 >= 设定波特率, 但误差通常小于1%
localparam CLK_DIV_UARTCLK = CLK_FREQ_MHZ * 1000 * 1000 / BAUD;

localparam START_BIT_CLK_CNT_MAX = CLK_DIV_UARTCLK * 1 - 1;                             // 开始位时钟计数最大值
localparam DATA_BIT_CLK_CNT_MAX  = START_BIT_CLK_CNT_MAX + CLK_DIV_UARTCLK * DATA_BITS; // 数据位时钟计数最大值

// 校验位时钟计数最大值
localparam PARITY_BIT_CLK_CNT_MAX   = DATA_BIT_CLK_CNT_MAX + (PARITY == "NONE" ? 0: CLK_DIV_UARTCLK);
localparam integer STOP_BIT_CLK_CNT_MAX = PARITY_BIT_CLK_CNT_MAX + CLK_DIV_UARTCLK * STOP_BITS; // 停止位时钟计数最大值

reg [$clog2(STOP_BIT_CLK_CNT_MAX + 1) - 1 : 0] clk_cnt; // 输入clk时钟计数, 通过clk_cnt的值来判断发送处于哪个阶段
always @(posedge clk) begin
  if (~rstn)
    clk_cnt <= 'd0;
  else if (~uart_tx_ready && clk_cnt < STOP_BIT_CLK_CNT_MAX)
    clk_cnt <= clk_cnt + 1'b1;
  else
    clk_cnt <= 'd0;
end
//-- UART发送全程计数 ------------------------------------------------------------


//++ 状态机 状态定义与状态跳转 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//~ 三段式状态机
//* 状态定义
localparam IDLE = 5'b00001;
localparam STATE_BIT = 5'b00010;
localparam DATA_BIT = 5'b00100;
localparam PARITY_BIT = 5'b01000;
localparam STOP_BIT = 5'b10000;

//* 初始态与状态跳转
reg [4 : 0] state;
reg [4 : 0] next;
always @(posedge clk, negedge rstn) begin
  if (~rstn) state <= IDLE;
  else       state <= next;
end

//* 跳转到下一个状态的条件
always @(*) begin
  next = state;
  case (1'b1)
    state[0]:  if (uart_tx_begin)
                  next = STATE_BIT;
    state[1]:  if (clk_cnt == START_BIT_CLK_CNT_MAX)
                  next = DATA_BIT;
    state[2]:  if (clk_cnt == PARITY_BIT_CLK_CNT_MAX) // 如果没有校验位, 则两最大值相等, 状态会直接跳转到停止位
                  next = STOP_BIT;
                else if (clk_cnt == DATA_BIT_CLK_CNT_MAX)
                  next = PARITY_BIT;
    state[3]:  if (clk_cnt == PARITY_BIT_CLK_CNT_MAX)
                  next = STOP_BIT;
    state[4]:  if (uart_tx_begin) // 计数到最大值的同时发送数据有效, 则跳过空闲位, 直接进入开始位
                  next = STATE_BIT;
                else if (clk_cnt == STOP_BIT_CLK_CNT_MAX)
                  next = IDLE;
    default: next = IDLE;
  endcase
end
//-- 状态机 状态定义与状态跳转 ------------------------------------------------------------


//++ 生成uart_tx_ready信号 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
always @(*) begin
  uart_tx_ready = 1'b1;
  case (1'b1)
    state[0]: ;
    state[1], state[2], state[3]: uart_tx_ready = 1'b0;
    state[4]: if (clk_cnt < STOP_BIT_CLK_CNT_MAX) uart_tx_ready = 1'b0;
    default: ;
  endcase
end
//-- 生成uart_tx_ready信号 ------------------------------------------------------------


//++ 锁存后移位待发送数据 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
reg [DATA_BITS - 1 : 0] tdata_locked;
always @(posedge clk) begin
  if (~rstn)
    tdata_locked <= 'd0;
  else if (uart_tx_begin)
    tdata_locked <= tdata;
  else
    tdata_locked <= tdata_locked;
end


localparam UART_TDATA_PERIOD_CLK_CNT_MAX = CLK_DIV_UARTCLK - 1;
// uart发送数据器件的clk时钟计数, 在数据位期间循环计数到最大值
reg [$clog2(UART_TDATA_PERIOD_CLK_CNT_MAX + 1) - 1 : 0] uart_tdata_period_clk_cnt;
always @(posedge clk) begin
  uart_tdata_period_clk_cnt <= 'd0;
  case (1'b1)
    state[0]:  ;
    state[1]:  ; // 开始位
    state[2]:  if (uart_tdata_period_clk_cnt < UART_TDATA_PERIOD_CLK_CNT_MAX) // 数据位
                  uart_tdata_period_clk_cnt <= uart_tdata_period_clk_cnt + 1'b1;
    state[3]:  ;
    state[4]:  ;
    default: ;
  endcase
end


reg [DATA_BITS - 1 : 0] tdata_locked_copy;
always @(posedge clk) begin
  tdata_locked_copy <= tdata_locked_copy;
  case (1'b1)
    state[0]:  tdata_locked_copy <= 'd0;
    state[1]:  tdata_locked_copy <= tdata_locked;
    state[2]:  if (uart_tdata_period_clk_cnt == UART_TDATA_PERIOD_CLK_CNT_MAX) // 数据位
                  tdata_locked_copy <= tdata_locked_copy >> 1; // 右移, 表示先发低位
    state[3]:  ;
    state[4]:  ;
    default: tdata_locked_copy <= 'd0;
  endcase
end


wire tdata_one_bit = tdata_locked_copy[0]; // 数据位阶段的uart_tx值
//-- 锁存后移位待发送数据 ------------------------------------------------------------


//++ 校验位 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
reg parity_value;

generate
  if (PARITY == "ODD") // 奇校验,指的是数据位和校验位合在一起1的个数为奇数
    always @(posedge clk) begin
      parity_value <= parity_value;
      case (1'b1)
        state[0]:  parity_value <= 1'b1;
        state[1]:  parity_value <= 1'b1;
        // 遇1翻转, 初始值1, 遇1次数为奇数, 则最终值为0
        state[2]:  if (tdata_one_bit && uart_tdata_period_clk_cnt == UART_TDATA_PERIOD_CLK_CNT_MAX)
                      parity_value <= ~parity_value;
        state[3]:  ;
        state[4]:  ;
        default: parity_value <= 1'b1;
      endcase
    end
  else if (PARITY == "EVEN") // 偶校验指的是数据位和校验位合在一起1的个数为偶数
    always @(posedge clk) begin
      parity_value <= parity_value;
      case (1'b1)
        state[0]:  parity_value <= 1'b0;
        state[1]:  parity_value <= 1'b0;
        // 遇1翻转, 初始值0, 遇1次数为偶数, 则最终值为0
        state[2]:  if (tdata_one_bit && uart_tdata_period_clk_cnt == UART_TDATA_PERIOD_CLK_CNT_MAX)
                      parity_value <= ~parity_value;
        state[3]:  ;
        state[4]:  ;
        default: parity_value <= 1'b0;
      endcase
    end
  else if (PARITY == "MARK") // 1校验
    always @(*) begin
      parity_value <= 1'b1;
    end
  else // 无校验或0校验
    always @(*) begin
      parity_value <= 1'b0;
    end
endgenerate
//-- 校验位 ------------------------------------------------------------


//++ uart_tx赋值 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
always @(*) begin
  uart_tx = 1'b1; // 默认高电平
  case (1'b1)
    state[0]:  uart_tx = 1'b1;
    state[1]:  uart_tx = 1'b0; // 开始位
    state[2]:  uart_tx = tdata_one_bit; // 数据位
    state[3]:  uart_tx = parity_value;  // 校验位
    state[4]:  uart_tx = 1'b1; // 停止位
    default: uart_tx = 1'b1;
  endcase
end
//-- uart_tx赋值 ------------------------------------------------------------


//++ 生成busy信号 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
always @(posedge clk) begin
  if (~rstn)
    uart_tx_is_busy <= 1'b0;
  else if (uart_tx_begin)
    uart_tx_is_busy <= 1'b1;
  else if (uart_tx_ready)
    uart_tx_is_busy <= 1'b0;
  else
    uart_tx_is_busy <= uart_tx_is_busy;
end
//-- 生成busy信号 ------------------------------------------------------------


endmodule