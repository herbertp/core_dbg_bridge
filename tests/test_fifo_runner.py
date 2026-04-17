import os
from cocotb_test.simulator import run

def test_fifo_verilog():
    run(
        verilog_sources=[os.path.abspath("src_v/dbg_bridge_fifo.v")],
        toplevel="dbg_bridge_fifo",
        module="test_fifo",
        simulator="icarus"
    )

def test_fifo_vhdl():
    run(
        vhdl_sources=[os.path.abspath("src_vhdl/dbg_bridge_fifo.vhd")],
        toplevel="dbg_bridge_fifo",
        module="test_fifo",
        simulator="ghdl",
        vhdl_version="2008"
    )
