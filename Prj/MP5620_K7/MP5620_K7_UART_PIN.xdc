# MP5620_K7_UART_PIN.xdc
# 代码压缩与烧写速度
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]

# 时钟 200MHz
set_property -dict {PACKAGE_PIN AE10 IOSTANDARD DIFF_SSTL15} [get_ports fpga_clk_p]

# UART
set_property -dict {PACKAGE_PIN J23 IOSTANDARD LVCMOS25} [get_ports uart_rx]
set_property -dict {PACKAGE_PIN J24 IOSTANDARD LVCMOS25} [get_ports uart_tx]

