# vivado.tcl
#	RK-XCKU5P-F simple example
#	Version 1.0
#
# Copyright (C) 2026 H.Poetzl

set ODIR .
set NAME uart
set_param messaging.defaultLimit 10000
set_param place.sliceLegEffortLimit 2000
# set_param board.repoPaths [list /opt/Xilinx/XilinxBoardStore/2025.2/boards]

# STEP#1: setup design sources and constraints

read_vhdl -vhdl2008 ../vivado_pkg.vhd

read_verilog ../dbg_bridge_fifo.v
read_verilog ../dbg_bridge_uart.v
read_verilog ../dbg_bridge.v

read_vhdl -vhdl2008 ../async_div.vhd
read_vhdl -vhdl2008 ../top.vhd

read_xdc ../rk-xcku5p-f.xdc


set_property PART xcku5p-ffvb676-2-i [current_project]
# set_property board_part em.avnet.com:microzed_7020:part0:1.1 [current_project]
set_property TARGET_LANGUAGE VHDL [current_project]

# STEP#2: configure IPs

# Create AXI BRAM Controller
create_ip -name axi_bram_ctrl -vendor xilinx.com -library ip -version 4.1 -module_name axi_bram_ctrl_0
set_property -dict [list \
  CONFIG.DATA_WIDTH {32} \
  CONFIG.ID_WIDTH {4} \
  CONFIG.MEM_DEPTH {16384} \
  CONFIG.PROTOCOL {AXI4} \
  CONFIG.SINGLE_PORT_BRAM {1} \
] [get_ips axi_bram_ctrl_0]

generate_target all [get_ips axi_bram_ctrl_0]
synth_ip [get_ips axi_bram_ctrl_0]

# Create Block Memory Generator IP
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name blk_mem_gen_0
set_property -dict [list \
  CONFIG.Memory_Type {Single_Port_RAM} \
  CONFIG.Enable_32bit_Address {false} \
  CONFIG.Use_Byte_Write_Enable {true} \
  CONFIG.Byte_Size {8} \
  CONFIG.Write_Width_A {32} \
  CONFIG.Write_Depth_A {65536} \
  CONFIG.Read_Width_A {32} \
  CONFIG.Enable_A {Use_ENA_Pin} \
  CONFIG.Use_RSTA_Pin {true} \
] [get_ips blk_mem_gen_0]

generate_target all [get_ips blk_mem_gen_0]
synth_ip [get_ips blk_mem_gen_0]

# STEP#3: run synthesis, write checkpoint design

synth_design -top top -flatten rebuilt
write_checkpoint -force $ODIR/post_synth

# STEP#4: run placement and logic optimzation, write checkpoint design

opt_design -propconst -sweep -retarget -remap

place_design -directive Quick
phys_opt_design -critical_cell_opt -critical_pin_opt -placement_opt -hold_fix -restruct_opt -retime
power_opt_design
write_checkpoint -force $ODIR/post_place

# STEP#5: run router, write checkpoint design

route_design -directive Quick
write_checkpoint -force $ODIR/post_route


report_timing -no_header -path_type summary -max_paths 1000 -slack_lesser_than 0 -setup
report_timing -no_header -path_type summary -max_paths 1000 -slack_lesser_than 0 -hold

# STEP#6: generate a bitstream

# set_property BITSTREAM.GENERAL.COMPRESS False [current_design]
set_property BITSTREAM.CONFIG.USERID "DEADC0DE" [current_design]
set_property BITSTREAM.CONFIG.USR_ACCESS TIMESTAMP [current_design]
# set_property BITSTREAM.READBACK.ACTIVERECONFIG Yes [current_design]

# write_bitstream -force -bin_file $ODIR/cmv_io.bit
write_bitstream -force -logic_location_file $ODIR/$NAME.bit
# write_cfgmem -force -interface SMAPx32 -format BIN -disablebitswap \
	-loadbit "up 0x0 $ODIR/$NAME.bit" $ODIR/$NAME.bin

# STEP#7: generate reports

report_clocks

report_utilization -hierarchical -file utilization.rpt
report_clock_utilization -file utilization.rpt -append
report_datasheet -file datasheet.rpt
report_timing_summary -file timing.rpt

report_operating_conditions -file conditions.rpt
report_power -file power.rpt

report_timing -no_header -path_type summary -max_paths 1000 -slack_lesser_than 0 -setup
report_timing -no_header -path_type summary -max_paths 1000 -slack_lesser_than 0 -hold

# source ../vivado_program.tcl
# start_gui
exit
