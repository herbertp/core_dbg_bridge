# Vivado Non-Project Mode Build Script
# Target: Kintex Ultrascale+

set outputDir ./out
file mkdir $outputDir

# 1. Setup the project / files
# Specify the part
set_part xcku5p-ffvb676-2-e

# Read VHDL source files
read_vhdl -vhdl2008 [glob ../src_vhdl/*.vhd]
read_vhdl -vhdl2008 top.vhd

# 2. Configure IPs
# Create AXI BRAM Controller
create_ip -name axi_bram_ctrl -vendor xilinx.com -library ip -version 4.1 -module_name axi_bram_ctrl_0
set_property -dict [list \
  CONFIG.DATA_WIDTH {32} \
  CONFIG.ID_WIDTH {4} \
  CONFIG.MEM_DEPTH {4096} \
  CONFIG.PROTOCOL {AXI4} \
  CONFIG.SINGLE_PORT_BRAM {1} \
] [get_ips axi_bram_ctrl_0]

generate_target all [get_ips axi_bram_ctrl_0]
synth_ip [get_ips axi_bram_ctrl_0]

# 3. Synthesis
synth_design -top top -part xcku5p-ffvb676-2-e
write_checkpoint -force $outputDir/post_synth.dcp
report_timing_summary -file $outputDir/post_synth_timing_summary.rpt
report_utilization -file $outputDir/post_synth_util.rpt

# 4. Implementation (optional, depending on user needs)
# opt_design
# place_design
# route_design
# write_bitstream -force $outputDir/top.bit
