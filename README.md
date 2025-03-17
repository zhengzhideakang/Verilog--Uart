# Verilog功能模块--Uart

Gitee与Github同步：

[Verilog功能模块--Uart: 串口通信模块 (gitee.com)](https://gitee.com/xuxiaokang/verilog-function-module--uart)

[zhengzhideakang/Verilog--Uart: 串口通信模块 (github.com)](https://github.com/zhengzhideakang/Verilog--Uart)

## 简介

一种通用的Uart收发模块，可实现Uart协议所支持的任意波特率，任意位宽数据（5~8），任意校验位（无校验、奇校验、偶校验、1校验、0校验），任意停止位（1、1.5、2）的数据传输。此模块内部集成了FIFO，以消除发送端和接收端波特率不一致导致的累计误差。此模块经过多次测试与实际使用验证，可实现连续10万+数据无间隔连续发送与接收无错误。

## 模块框图

<img src="https://picgo-dakang.oss-cn-hangzhou.aliyuncs.com/img/uartRTUseFIFO.svg" alt="uartRTUseFIFO" />

## 其它请参考：

[Verilog功能模块——Uart收发 – 徐晓康的博客 (myhardware.top)](https://www.myhardware.top/verilog功能模块-uart收发/)

## 其它平台

微信公众号：`徐晓康的博客`

<img src="https://picgo-dakang.oss-cn-hangzhou.aliyuncs.com/img/%E5%BE%90%E6%99%93%E5%BA%B7%E7%9A%84%E5%8D%9A%E5%AE%A2%E5%85%AC%E4%BC%97%E5%8F%B7%E4%BA%8C%E7%BB%B4%E7%A0%81.jpg" alt="徐晓康的博客公众号二维码" />
