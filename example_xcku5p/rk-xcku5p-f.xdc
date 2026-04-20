
# 200MHz System Clock (Bank 65)
set_property PACKAGE_PIN T24 [get_ports sys_clk_p]
set_property PACKAGE_PIN U24 [get_ports sys_clk_n]
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

# 40 Pin Connector IOs (Bank 86)
set_property PACKAGE_PIN D10 [get_ports {io_n[0]}] ;# IO1_N
set_property PACKAGE_PIN D11 [get_ports {io_p[0]}] ;# IO1_P
set_property PACKAGE_PIN E10 [get_ports {io_n[1]}] ;# IO2_N
set_property PACKAGE_PIN E11 [get_ports {io_p[1]}] ;# IO2_P
set_property PACKAGE_PIN B11 [get_ports {io_n[2]}] ;# IO3_N
set_property PACKAGE_PIN C11 [get_ports {io_p[2]}] ;# IO3_P
set_property PACKAGE_PIN C9  [get_ports {io_n[3]}] ;# IO4_N
set_property PACKAGE_PIN D9  [get_ports {io_p[3]}] ;# IO4_P
set_property PACKAGE_PIN A9  [get_ports {io_n[4]}] ;# IO5_N
set_property PACKAGE_PIN B9  [get_ports {io_p[4]}] ;# IO5_P
set_property PACKAGE_PIN A10 [get_ports {io_n[5]}] ;# IO6_N
set_property PACKAGE_PIN B10 [get_ports {io_p[5]}] ;# IO6_P

# 40 Pin Connector IOs (Bank 87)
set_property PACKAGE_PIN A12 [get_ports {io_n[6]}]  ;# IO7_N
set_property PACKAGE_PIN A13 [get_ports {io_p[6]}]  ;# IO7_P
set_property PACKAGE_PIN A14 [get_ports {io_n[7]}]  ;# IO8_N
set_property PACKAGE_PIN B14 [get_ports {io_p[7]}]  ;# IO8_P
set_property PACKAGE_PIN C13 [get_ports {io_n[8]}]  ;# IO9_N
set_property PACKAGE_PIN C14 [get_ports {io_p[8]}]  ;# IO9_P
set_property PACKAGE_PIN B12 [get_ports {io_n[9]}]  ;# IO10_N
set_property PACKAGE_PIN C12 [get_ports {io_p[9]}]  ;# IO10_P
set_property PACKAGE_PIN D13 [get_ports {io_n[10]}] ;# IO11_N
set_property PACKAGE_PIN D14 [get_ports {io_p[10]}] ;# IO11_P
set_property PACKAGE_PIN E12 [get_ports {io_n[11]}] ;# IO12_N
set_property PACKAGE_PIN E13 [get_ports {io_p[11]}] ;# IO12_P
set_property PACKAGE_PIN F13 [get_ports {io_n[12]}] ;# IO13_N
set_property PACKAGE_PIN F14 [get_ports {io_p[12]}] ;# IO13_P
set_property PACKAGE_PIN F12 [get_ports {io_n[13]}] ;# IO14_N
set_property PACKAGE_PIN G12 [get_ports {io_p[13]}] ;# IO14_P
set_property PACKAGE_PIN G14 [get_ports {io_n[14]}] ;# IO15_N
set_property PACKAGE_PIN H14 [get_ports {io_p[14]}] ;# IO15_P
set_property PACKAGE_PIN J14 [get_ports {io_n[15]}] ;# IO16_N
set_property PACKAGE_PIN J15 [get_ports {io_p[15]}] ;# IO16_P
set_property PACKAGE_PIN H13 [get_ports {io_n[16]}] ;# IO17_N
set_property PACKAGE_PIN J13 [get_ports {io_p[16]}] ;# IO17_P

# I/O Standard Configuration
set_property IOSTANDARD LVCMOS33 [get_ports {io_p}]
set_property IOSTANDARD LVCMOS33 [get_ports {io_n}]


# DDR4 Memory Constraints
set_property PACKAGE_PIN AE25 [ get_ports "c0_ddr4_dm_dbi_n[0]" ]
set_property PACKAGE_PIN AE22 [ get_ports "c0_ddr4_dm_dbi_n[1]" ]
set_property PACKAGE_PIN AD20 [ get_ports "c0_ddr4_dm_dbi_n[2]" ]
set_property PACKAGE_PIN Y20  [ get_ports "c0_ddr4_dm_dbi_n[3]" ]

set_property PACKAGE_PIN AC26 [ get_ports "c0_ddr4_dqs_t[0]" ]
set_property PACKAGE_PIN AD26 [ get_ports "c0_ddr4_dqs_c[0]" ]
set_property PACKAGE_PIN AA22 [ get_ports "c0_ddr4_dqs_t[1]" ]
set_property PACKAGE_PIN AB22 [ get_ports "c0_ddr4_dqs_c[1]" ]
set_property PACKAGE_PIN AC18 [ get_ports "c0_ddr4_dqs_t[2]" ]
set_property PACKAGE_PIN AD18 [ get_ports "c0_ddr4_dqs_c[2]" ]
set_property PACKAGE_PIN AB17 [ get_ports "c0_ddr4_dqs_t[3]" ]
set_property PACKAGE_PIN AC17 [ get_ports "c0_ddr4_dqs_c[3]" ]

set_property PACKAGE_PIN AF24 [ get_ports "c0_ddr4_dq[0]" ]
set_property PACKAGE_PIN AF25 [ get_ports "c0_ddr4_dq[1]" ]
set_property PACKAGE_PIN AD24 [ get_ports "c0_ddr4_dq[2]" ]
set_property PACKAGE_PIN AB26 [ get_ports "c0_ddr4_dq[3]" ]
set_property PACKAGE_PIN AC24 [ get_ports "c0_ddr4_dq[4]" ]
set_property PACKAGE_PIN AB25 [ get_ports "c0_ddr4_dq[5]" ]
set_property PACKAGE_PIN AD25 [ get_ports "c0_ddr4_dq[6]" ]
set_property PACKAGE_PIN AB24 [ get_ports "c0_ddr4_dq[7]" ]
set_property PACKAGE_PIN AC21 [ get_ports "c0_ddr4_dq[8]" ]
set_property PACKAGE_PIN AD23 [ get_ports "c0_ddr4_dq[9]" ]
set_property PACKAGE_PIN AD21 [ get_ports "c0_ddr4_dq[10]" ]
set_property PACKAGE_PIN AC22 [ get_ports "c0_ddr4_dq[11]" ]
set_property PACKAGE_PIN AB21 [ get_ports "c0_ddr4_dq[12]" ]
set_property PACKAGE_PIN AE23 [ get_ports "c0_ddr4_dq[13]" ]
set_property PACKAGE_PIN AE21 [ get_ports "c0_ddr4_dq[14]" ]
set_property PACKAGE_PIN AC23 [ get_ports "c0_ddr4_dq[15]" ]
set_property PACKAGE_PIN AE16 [ get_ports "c0_ddr4_dq[16]" ]
set_property PACKAGE_PIN AD19 [ get_ports "c0_ddr4_dq[17]" ]
set_property PACKAGE_PIN AD16 [ get_ports "c0_ddr4_dq[18]" ]
set_property PACKAGE_PIN AF17 [ get_ports "c0_ddr4_dq[19]" ]
set_property PACKAGE_PIN AC19 [ get_ports "c0_ddr4_dq[20]" ]
set_property PACKAGE_PIN AF19 [ get_ports "c0_ddr4_dq[21]" ]
set_property PACKAGE_PIN AF18 [ get_ports "c0_ddr4_dq[22]" ]
set_property PACKAGE_PIN AE17 [ get_ports "c0_ddr4_dq[23]" ]
set_property PACKAGE_PIN AA20 [ get_ports "c0_ddr4_dq[24]" ]
set_property PACKAGE_PIN AA18 [ get_ports "c0_ddr4_dq[25]" ]
set_property PACKAGE_PIN AA19 [ get_ports "c0_ddr4_dq[26]" ]
set_property PACKAGE_PIN Y18  [ get_ports "c0_ddr4_dq[27]" ]
set_property PACKAGE_PIN AB20 [ get_ports "c0_ddr4_dq[28]" ]
set_property PACKAGE_PIN Y17  [ get_ports "c0_ddr4_dq[29]" ]
set_property PACKAGE_PIN AB19 [ get_ports "c0_ddr4_dq[30]" ]
set_property PACKAGE_PIN AA17 [ get_ports "c0_ddr4_dq[31]" ]

set_property PACKAGE_PIN Y22  [ get_ports "c0_ddr4_adr[0]" ]
set_property PACKAGE_PIN Y25  [ get_ports "c0_ddr4_adr[1]" ]
set_property PACKAGE_PIN W23  [ get_ports "c0_ddr4_adr[2]" ]
set_property PACKAGE_PIN V26  [ get_ports "c0_ddr4_adr[3]" ]
set_property PACKAGE_PIN R26  [ get_ports "c0_ddr4_adr[4]" ]
set_property PACKAGE_PIN U26  [ get_ports "c0_ddr4_adr[5]" ]
set_property PACKAGE_PIN R21  [ get_ports "c0_ddr4_adr[6]" ]
set_property PACKAGE_PIN W25  [ get_ports "c0_ddr4_adr[7]" ]
set_property PACKAGE_PIN R20  [ get_ports "c0_ddr4_adr[8]" ]
set_property PACKAGE_PIN Y26  [ get_ports "c0_ddr4_adr[9]" ]
set_property PACKAGE_PIN R25  [ get_ports "c0_ddr4_adr[10]" ]
set_property PACKAGE_PIN V23  [ get_ports "c0_ddr4_adr[11]" ]
set_property PACKAGE_PIN AA24 [ get_ports "c0_ddr4_adr[12]" ]
set_property PACKAGE_PIN W26  [ get_ports "c0_ddr4_adr[13]" ]
set_property PACKAGE_PIN P23  [ get_ports "c0_ddr4_adr[14]" ]
set_property PACKAGE_PIN AA25 [ get_ports "c0_ddr4_adr[15]" ]
set_property PACKAGE_PIN T25  [ get_ports "c0_ddr4_adr[16]" ]

set_property PACKAGE_PIN V24 [ get_ports "c0_ddr4_ck_t[0]" ]
set_property PACKAGE_PIN W24 [ get_ports "c0_ddr4_ck_c[0]" ]

set_property PACKAGE_PIN R22 [ get_ports "c0_ddr4_bg[0]" ]
set_property PACKAGE_PIN P25 [ get_ports "c0_ddr4_cs_n[0]" ]
set_property PACKAGE_PIN P21 [ get_ports "c0_ddr4_ba[0]" ]
set_property PACKAGE_PIN P20 [ get_ports "c0_ddr4_cke[0]" ]
set_property PACKAGE_PIN R23 [ get_ports "c0_ddr4_odt[0]" ]
set_property PACKAGE_PIN P26 [ get_ports "c0_ddr4_ba[1]" ]
set_property PACKAGE_PIN P24 [ get_ports "c0_ddr4_act_n" ]

set_property PACKAGE_PIN P19  [ get_ports "c0_ddr4_reset_n" ]
