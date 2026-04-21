# vivado.tcl
#	RK-XCKU5P-F simple example
#	Version 1.1 - DMA and SmartConnect
#
# Copyright (C) 2026 H.Poetzl

set ODIR .
set NAME uart
set_param messaging.defaultLimit 10000
set_param place.sliceLegEffortLimit 2000

source ../helper.tcl

# STEP#1: setup design sources and constraints

read_vhdl -vhdl2008 ../vivado_pkg.vhd

read_verilog ../dbg_bridge_fifo.v
read_verilog ../dbg_bridge_uart.v
read_verilog ../dbg_bridge.v

read_vhdl -vhdl2008 ../async_div.vhd
read_vhdl -vhdl2008 ../simple_dma.vhd
read_vhdl -vhdl2008 ../top.vhd

read_xdc ../rk-xcku5p-f.xdc


set_property PART xcku5p-ffvb676-2-i [current_project]
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
  CONFIG.ADDN_UI_CLKOUT1_FREQ_HZ {100} \
  CONFIG.C0.DDR4_Ecc {false} \
]

# Create AXI SmartConnect
# S00: Debug Bridge (32-bit, 100MHz)
# S01: DMA Master (256-bit, UI clk)
# M00: DDR4 (256-bit, UI clk)
# M01: DMA Config (32-bit, UI clk)
generate_ip axi_smartconnect xilinx.com ip 1.0 axi_smartconnect_0 [list \
  CONFIG.NUM_SI {2} \
  CONFIG.NUM_MI {2} \
  CONFIG.HAS_ARESETN {1} \
  CONFIG.NUM_CLKS {2} \
  CONFIG.S00_HAS_DATA_FIFO {1} \
  CONFIG.S01_HAS_DATA_FIFO {1} \
  CONFIG.M00_HAS_DATA_FIFO {1} \
  CONFIG.M01_HAS_DATA_FIFO {1} \
  CONFIG.S00_AXI_ADDR_WIDTH {32} \
  CONFIG.S01_AXI_ADDR_WIDTH {32} \
  CONFIG.M00_AXI_ADDR_WIDTH {31} \
  CONFIG.M01_AXI_ADDR_WIDTH {32} \
  CONFIG.C0_ADDR_RANGE_0 {0x00000000} \
  CONFIG.C0_ADDR_RANGE_1 {0x80000000} \
  CONFIG.M00_ADDR_0 {0x0000000000000000} \
  CONFIG.M00_SIZE_0 {0x80000000} \
  CONFIG.M01_ADDR_0 {0x0000000080000000} \
  CONFIG.M01_SIZE_0 {0x00010000} \
]

# Note: In Non-Project Mode, SmartConnect address mapping can be tricky via properties.
# If the above property-based mapping fails, we might need a more manual crossbar approach
# but SmartConnect is generally preferred for its automatic width/clock handling.

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

set_property BITSTREAM.CONFIG.USERID "DEADC0DE" [current_design]
set_property BITSTREAM.CONFIG.USR_ACCESS TIMESTAMP [current_design]

write_bitstream -force -logic_location_file $ODIR/$NAME.bit

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

exit
