# FPGA型号:XC7A200Tfbg484-2
# hpcCoreMasterTop.xdc

# 代码压缩与烧写速度
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

# 设置SPI总线的宽度，这要跟硬件对应，不能乱写，一般FLASH有两种配置方式：SPI和BPI，其中SPI的总线宽度有1, 2, 4, 8四种
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]

# 设置配置模式，同样需要和硬件对应
set_property CONFIG_MODE SPIx4 [current_design]

# 设置配置时钟频率，50表示50MHz
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]

# 时钟与复位 20MHz
set_property -dict {PACKAGE_PIN C18 IOSTANDARD LVCMOS33} [get_ports fpga_clk]
set_property -dict {PACKAGE_PIN AB1 IOSTANDARD LVCMOS33} [get_ports fpga_arstn]

# LED
set_property -dict {PACKAGE_PIN A15 IOSTANDARD LVCMOS33} [get_ports led0]
set_property -dict {PACKAGE_PIN A16 IOSTANDARD LVCMOS33} [get_ports led1]

# fpga_uart 调试接口 外部转为了USB(CH343P芯片) 最高波特率6Mbps
set_property -dict {PACKAGE_PIN N13 IOSTANDARD LVCMOS33} [get_ports fpga_uart_rx ]
set_property -dict {PACKAGE_PIN N14 IOSTANDARD LVCMOS33} [get_ports fpga_uart_tx ]



