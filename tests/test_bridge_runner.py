import os
from cocotb_test.simulator import run

def test_bridge_verilog():
    run(
        verilog_sources=[
            os.path.abspath("src_v/dbg_bridge_fifo.v"),
            os.path.abspath("src_v/dbg_bridge_uart.v"),
            os.path.abspath("src_v/dbg_bridge.v")
        ],
        toplevel="dbg_bridge",
        module="test_bridge",
        simulator="icarus",
        parameters={
            "CLK_FREQ": 100000000,
            "UART_SPEED": 10000000
        }
    )

def test_bridge_vhdl():
    run(
        vhdl_sources=[
            os.path.abspath("src_vhdl/dbg_bridge_fifo.vhd"),
            os.path.abspath("src_vhdl/dbg_bridge_uart.vhd"),
            os.path.abspath("src_vhdl/dbg_bridge.vhd")
        ],
        toplevel="dbg_bridge",
        module="test_bridge",
        simulator="ghdl",
        vhdl_version="2008",
        generics={
            "CLK_FREQ": 100000000,
            "UART_SPEED": 10000000
        }
    )
