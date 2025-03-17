/*
 * @Author       : Xu Xiaokang
 * @Email        : xuxiaokang_up@qq.com
 * @Date         : 2022-05-03 20:12:16
 * @LastEditors  : Xu Xiaokang
 * @LastEditTime : 2024-09-20 23:02:00
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
*/

module uartRx
#(
  parameter CLK_FREQ_MHZ = 100,    // 时钟频率(MHz), 默认100
  parameter BAUD         = 115200, // 任意波特率, 9600, 19200, 38400, 57600, 115200(默认), 230400, 460800, 921600等
  parameter DATA_BITS    = 8,      // 数据位宽度, 可选5, 6, 7, 8(默认)
  parameter PARITY       = "NONE", // 校验, 可选"NONE"(默认), "ODD", "EVEN", "MARK", "SPACE"
  parameter STOP_BITS    = 1       // 停止位宽度, 可选1(默认), 1.5, 2
)(
  output reg  uart_rx_is_busy, // 指示接收正在进行

  output reg [DATA_BITS - 1 : 0]  rdata,       // 接收到的数据
  output reg                      rdata_valid, // 指示接收数据有效, 高电平有效
  output reg                      rdata_error, // 接收数据错误, 根据接收数据计算的校验值不等于收到的校验值

  input  wire uart_rx,

  input  wire clk,
  input  wire rstn
);


//++ 接收uart_rx信号 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
reg uart_rx_r1;
reg uart_rx_r2;
always @(posedge clk) begin
  uart_rx_r1 <= uart_rx;
  uart_rx_r2 <= uart_rx_r1;
end


wire uart_rx_nedge = ~uart_rx_r1 && uart_rx_r2;

reg uart_rx_ready; // 接收正在进行
wire uart_rx_begin = uart_rx_nedge && uart_rx_ready; // 接收开始
//-- 接收uart_rx信号 ------------------------------------------------------------


//++ 接收过程全程计数 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam UART_CLK_FREQ = CLK_FREQ_MHZ * 1000 * 1000 / BAUD; // UART时钟频率

localparam START_BIT_CLK_CNT_MAX  = UART_CLK_FREQ * 1 - 1;                                         // 开始位时钟计数最大值
localparam DATA_BIT_CLK_CNT_MAX   = START_BIT_CLK_CNT_MAX + UART_CLK_FREQ * DATA_BITS;             // 数据位时钟计数最大值
localparam PARITY_BIT_CLK_CNT_MAX = DATA_BIT_CLK_CNT_MAX + (PARITY == "NONE" ? 0 : UART_CLK_FREQ); // 校验位时钟计数最大值
localparam integer STOP_BIT_CLK_CNT_MAX = PARITY_BIT_CLK_CNT_MAX + UART_CLK_FREQ * STOP_BITS;      // 停止位时钟计数最大值

reg [$clog2(STOP_BIT_CLK_CNT_MAX + 1) - 1 : 0] clk_cnt; // 输入clk时钟计数, 通过clk_cnt的值来判断接收处于哪个阶段
//-- 接收过程全程计数 ------------------------------------------------------------


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
    state[0]:  if (uart_rx_begin)
                  next = STATE_BIT;
    state[1]:  if (clk_cnt == START_BIT_CLK_CNT_MAX)
                  next = DATA_BIT;
    state[2]:  if (clk_cnt == PARITY_BIT_CLK_CNT_MAX) // 如果没有校验位, 则两最大值相等, 状态会直接跳转到停止位
                  next = STOP_BIT;
                else if (clk_cnt == DATA_BIT_CLK_CNT_MAX)
                  next = PARITY_BIT;
    state[3]:  if (clk_cnt == PARITY_BIT_CLK_CNT_MAX)
                  next = STOP_BIT;
    state[4]:  // 当停止位计数超过一半时, 此时下一帧开始位到来, 则跳过空闲位直接跳转到下一帧开始位
                if (uart_rx_begin)
                  next = STATE_BIT;
                else if (clk_cnt == STOP_BIT_CLK_CNT_MAX) // 正常计数到停止位结束后回到空闲位
                  next = IDLE;
    default: next = IDLE;
  endcase
end


always @(posedge clk) begin
  if (~rstn)
    clk_cnt <= 'd0;
  else if (uart_rx_begin)
    clk_cnt <= 'd0;
  else if ((~uart_rx_ready || state[4] == 1'b1) && clk_cnt < STOP_BIT_CLK_CNT_MAX)
    clk_cnt <= clk_cnt + 1'b1;
  else
    clk_cnt <= 'd0;
end
//-- 状态机 状态定义与状态跳转 ------------------------------------------------------------


//++ 生成uart_rx_ready信号 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam integer STOP_BIT_HALF = PARITY_BIT_CLK_CNT_MAX + UART_CLK_FREQ * STOP_BITS / 2; // 停止位时钟计数半值

always @(*) begin
  uart_rx_ready = 1'b1;
  case (1'b1)
    state[0]:  ;
    state[1], state[2], state[3]: uart_rx_ready = 1'b0;
    // 因波特率可能的偏差, 这里停止位计数到一半就开始准备接收下一帧的开始位了
    state[4]: if (clk_cnt < STOP_BIT_HALF) uart_rx_ready = 1'b0;
    default: ;
  endcase
end
//-- 生成uart_rx_ready信号 ------------------------------------------------------------


//++ 接收数据 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
localparam UART_RDATA_PERIOD_CLK_CNT_MAX = UART_CLK_FREQ - 1;
// uart接收数据器件的clk时钟计数, 在数据位和校验位期间循环计数到最大值
reg [$clog2(UART_RDATA_PERIOD_CLK_CNT_MAX + 1) - 1 : 0] uart_rdata_period_clk_cnt;
always @(posedge clk) begin
  uart_rdata_period_clk_cnt <= 'd0;
  case (1'b1)
    state[0]:  ;
    state[1]:  ;
    state[2], state[3]: if (uart_rdata_period_clk_cnt < UART_RDATA_PERIOD_CLK_CNT_MAX) // 数据位和校验位
                            uart_rdata_period_clk_cnt <= uart_rdata_period_clk_cnt + 1'b1;
    state[4]:  ;
    default: ;
  endcase
end


localparam UART_RDATA_SAMPLE_POINT = UART_CLK_FREQ / 2 - 1;
wire sample_point;
assign sample_point = uart_rdata_period_clk_cnt == UART_RDATA_SAMPLE_POINT; // 在每个数据位的正中间采样
always @(posedge clk) begin
  rdata <= rdata;
  case (1'b1)
    state[0]:  rdata <= 'd0;
    state[1]:  rdata <= 'd0;
    state[2]:  if (sample_point)
                  rdata <= {uart_rx_r2, rdata[DATA_BITS - 1 : 1]} ; // 新接收的放到最高位, 然后依次右移, 最先接收的为最低位
    state[3]:  ;
    state[4]:  ;
    default: rdata <= 'd0;
  endcase
end
//-- 接收数据 ------------------------------------------------------------


//++ 比较根据接收数据计算得到的校验值和接收的校验值是否相等 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
reg parity_value; // 根据接收数据计算其校验值

generate
  if (PARITY == "ODD") // 奇校验, 指的是数据位和校验位合在一起1的个数为奇数
    always @(posedge clk) begin
      parity_value <= parity_value;
      case (1'b1)
        state[0]:  parity_value <= 1'b1;
        state[1]:  parity_value <= 1'b1;
        // 遇1翻转, 初始值1, 遇1次数为奇数, 则最终值为0
        state[2]:  if (uart_rx_r2 && sample_point)
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
        state[2]:  if (uart_rx_r2 && sample_point)
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
  else // 0校验
    always @(*) begin
      parity_value <= 1'b0;
    end
endgenerate


// 接收校验位
reg parity_value_rx;
generate
  if (PARITY == "NONE")
    always @(*) begin
      parity_value_rx <= 1'b0;
    end
  else
    always @(posedge clk) begin
      parity_value_rx <= parity_value_rx;
      case (1'b1)
        state[0]:  parity_value_rx <= 1'b0;
        state[1]:  ;
        state[2]:  ;
        state[3]:  if (sample_point) // 在校验位中点接收校验值
                      parity_value_rx <= uart_rx_r2;
        state[4]:  ;
        default: parity_value_rx <= 1'b0;
      endcase
    end
endgenerate


// 比较计算的校验值和接收的校验值是否相等
generate
  if (PARITY == "NONE") // 无校验
    always @(*) begin
      rdata_error <= 1'b0;
    end
  else // 有校验
    always @(posedge clk) begin
      rdata_error <= 1'b0;
      case (1'b1)
        state[0]:  ;
        state[1]:  ;
        state[2]:  ;
        state[3]:  ;
        state[4]:  if (parity_value_rx != parity_value)  // 停止位时, 接收校验值不等于计算校验值
                      rdata_error <= 1'b1;
        default: ;
      endcase
    end
endgenerate
//-- 比较根据接收数据计算得到的校验值和接收的校验值是否相等 ------------------------------------------------------------


//++ 接收数据有效 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
always @(posedge clk) begin
  rdata_valid <= 1'b0;
  case (1'b1)
    state[0]:  ;
    state[1]:  ;
    state[2]:  ;
    state[3]:  ;
    state[4]:  if (clk_cnt == STOP_BIT_CLK_CNT_MAX || uart_rx_begin) rdata_valid <= 1'b1; // 停止位接收数据有效
    default: ;
  endcase
end
//-- 接收数据有效 ------------------------------------------------------------


//++ 生成接收busy信号 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
always @(posedge clk) begin
  if (~rstn)
    uart_rx_is_busy <= 1'b0;
  else if (uart_rx_begin)
    uart_rx_is_busy <= 1'b1;
  else if (uart_rx_ready && rdata_valid)
    uart_rx_is_busy <= 1'b0;
  else
    uart_rx_is_busy <= uart_rx_is_busy;
end
//-- 生成接收busy信号 ------------------------------------------------------------


endmodule