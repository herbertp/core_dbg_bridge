import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

async def reset_dut(rst_ni, duration_ns):
    rst_ni.value = 1
    await Timer(duration_ns, units="ns")
    rst_ni.value = 0
    await Timer(duration_ns, units="ns")

@cocotb.test()
async def test_fifo_basic(dut):
    """Test basic FIFO functionality: push, pop, empty, full"""
    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut.rst_i, 20)

    # Initial state
    assert dut.valid_o.value == 0
    assert dut.accept_o.value == 1

    # Push one element
    dut.data_in_i.value = 0xAA
    dut.push_i.value = 1
    await RisingEdge(dut.clk_i)
    dut.push_i.value = 0
    await RisingEdge(dut.clk_i)

    assert dut.valid_o.value == 1
    assert dut.data_out_o.value == 0xAA

    # Pop element
    dut.pop_i.value = 1
    await RisingEdge(dut.clk_i)
    dut.pop_i.value = 0
    await RisingEdge(dut.clk_i)

    assert dut.valid_o.value == 0

@cocotb.test()
async def test_fifo_full(dut):
    """Test FIFO full condition"""
    clock = Clock(dut.clk_i, 10, units="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut.rst_i, 20)

    depth = 4 # Default depth

    for i in range(depth):
        assert dut.accept_o.value == 1
        dut.data_in_i.value = i
        dut.push_i.value = 1
        await RisingEdge(dut.clk_i)

    dut.push_i.value = 0
    await RisingEdge(dut.clk_i)

    assert dut.accept_o.value == 0
    assert dut.valid_o.value == 1

    for i in range(depth):
        assert dut.valid_o.value == 1
        assert dut.data_out_o.value == i
        dut.pop_i.value = 1
        await RisingEdge(dut.clk_i)
        dut.pop_i.value = 0
        await Timer(1, unit="ns") # Allow combinational outputs to settle

    assert dut.valid_o.value == 0
    assert dut.accept_o.value == 1
