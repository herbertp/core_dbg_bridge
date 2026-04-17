import os
from cocotb_test.simulator import run

def test_uart_verilog():
    run(
        verilog_sources=[os.path.abspath("src_v/dbg_bridge_uart.v")],
        toplevel="dbg_bridge_uart",
        module="test_uart",
        simulator="icarus"
    )

def test_uart_vhdl():
    run(
        vhdl_sources=[os.path.abspath("src_vhdl/dbg_bridge_uart.vhd")],
        toplevel="dbg_bridge_uart",
        module="test_uart",
        simulator="ghdl",
        vhdl_version="2008"
    )
