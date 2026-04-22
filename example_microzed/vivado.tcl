# vivado.tcl
#	MicroZed simple example
#	Version 1.0
#
# Copyright (C) 2013-2026 H.Poetzl

set ODIR .
set NAME uart
set_param messaging.defaultLimit 10000
set_param place.sliceLegEffortLimit 2000
set_param board.repoPaths [list /opt/Xilinx/XilinxBoardStore/2025.2/boards]

# STEP#1: setup design sources and constraints

read_vhdl ../vivado_pkg.vhd

read_vhdl ../async_div.vhd
read_vhdl ../ps7_stub.vhd
read_vhdl ../top.vhd

read_verilog ../../src_v/dbg_bridge.v
read_verilog ../../src_v/dbg_bridge_fifo.v
read_verilog ../../src_v/dbg_bridge_uart.v

read_xdc ../top.xdc

set_property PART xc7z020clg400-1 [current_project]
set_property BOARD_PART avnet.com:microzed_7020:part0:1.3 [current_project]
set_property TARGET_LANGUAGE VHDL [current_project]

# STEP#2: configure IPs

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

set_property BITSTREAM.GENERAL.COMPRESS True [current_design]
set_property BITSTREAM.CONFIG.USERID "DEADC0DE" [current_design]
set_property BITSTREAM.CONFIG.USR_ACCESS TIMESTAMP [current_design]
set_property BITSTREAM.READBACK.ACTIVERECONFIG Yes [current_design]

# write_bitstream -force -bin_file $ODIR/cmv_io.bit
write_bitstream -force -logic_location_file $ODIR/$NAME.bit
write_cfgmem -force -interface SMAPx32 -format BIN -disablebitswap \
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
