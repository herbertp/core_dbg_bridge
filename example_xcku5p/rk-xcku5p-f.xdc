
# 200MHz System Clock (Bank 65)
set_property PACKAGE_PIN T24 [get_ports sys_clk_p]
set_property PACKAGE_PIN U24 [get_ports sys_clk_n]
create_clock -period 5.000 -name sys_clk [get_ports sys_clk_p]
set_property IOSTANDARD DIFF_SSTL12 [get_ports {sys_clk_*}]

# Debug UART (Bank 84)
set_property PACKAGE_PIN AD13 [get_ports uart_rxd_i]
set_property PACKAGE_PIN AC14 [get_ports uart_txd_o]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_*}]

# User LEDs (Bank 86) - Active High
set_property PACKAGE_PIN H9  [get_ports {led[0]}] ;# LED1
set_property PACKAGE_PIN J9  [get_ports {led[1]}] ;# LED2
set_property PACKAGE_PIN G11 [get_ports {led[2]}] ;# LED3
set_property PACKAGE_PIN H11 [get_ports {led[3]}] ;# LED4
set_property IOSTANDARD LVCMOS33 [get_ports {led}]

# User Buttons (Bank 86) - Active Low (0 when pressed)
set_property PACKAGE_PIN K9  [get_ports {key[0]}] ;# KEY1
set_property PACKAGE_PIN K10 [get_ports {key[1]}] ;# KEY2
set_property PACKAGE_PIN J10 [get_ports {key[2]}] ;# KEY3
set_property PACKAGE_PIN J11 [get_ports {key[3]}] ;# KEY4
set_property IOSTANDARD LVCMOS33 [get_ports {key}]

