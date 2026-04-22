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

source ../helper.tcl

# STEP#1: setup design sources and constraints

read_vhdl -vhdl2008 ../vivado_pkg.vhd

read_verilog ../../src_v/dbg_bridge.v
read_verilog ../../src_v/dbg_bridge_fifo.v
read_verilog ../../src_v/dbg_bridge_uart.v

read_vhdl -vhdl2008 ../async_div.vhd
read_vhdl -vhdl2008 ../top.vhd

read_xdc ../rk-xcku5p-f.xdc


set_property PART xcku5p-ffvb676-2-i [current_project]
# set_property board_part em.avnet.com:microzed_7020:part0:1.1 [current_project]
set_property TARGET_LANGUAGE VHDL [current_project]

# STEP#2: configure IPs

# Create DDR4 IP
generate_ip ddr4 xilinx.com ip 2.2 ddr4_0 [list \
  CONFIG.C0.DDR4_MemoryPart {MT40A512M16LY-075} \
  CONFIG.C0.DDR4_DataWidth {32} \
  CONFIG.C0.DDR4_InputClockPeriod {5000} \
  CONFIG.C0.DDR4_AxiSelection {true} \
  CONFIG.C0.DDR4_AxiDataWidth {256} \
  CONFIG.C0.DDR4_AxiAddressWidth {31} \
  CONFIG.C0.DDR4_AxiIDWidth {4} \
  CONFIG.C0.DDR4_Ordering {Normal} \
  CONFIG.C0.DDR4_AxiArbitrationScheme {RD_PRI_REG} \
  CONFIG.C0.DDR4_Ecc {false} \
  CONFIG.ADDN_UI_CLKOUT1_FREQ_HZ {100} \
]

# Create AXI Clock Converter
generate_ip axi_clock_converter xilinx.com ip 2.1 axi_clock_converter_0 [list \
  CONFIG.ADDR_WIDTH {31} \
  CONFIG.DATA_WIDTH {256} \
  CONFIG.ID_WIDTH {4} \
]

# Create AXI Data Width Converter
generate_ip axi_dwidth_converter xilinx.com ip 2.1 axi_dwidth_converter_0 [list \
  CONFIG.ADDR_WIDTH {31} \
  CONFIG.SI_DATA_WIDTH {32} \
  CONFIG.MI_DATA_WIDTH {256} \
  CONFIG.SI_ID_WIDTH {4} \
]

# STEP#3: run synthesis, write checkpoint design

synth_design -top top -flatten rebuilt
write_checkpoint -force $ODIR/post_synth

# STEP#4: run placement and logic optimzation, write checkpoint design

opt_design -propconst -sweep -retarget -remap

place_design -directive Explore
phys_opt_design -critical_cell_opt -critical_pin_opt -placement_opt -hold_fix -restruct_opt -retime
power_opt_design
write_checkpoint -force $ODIR/post_place

# STEP#5: run router, write checkpoint design

route_design -directive Explore
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
