import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

async def reset_dut(rst_ni, duration_ns):
    rst_ni.value = 1
    await Timer(duration_ns, unit="ns")
    rst_ni.value = 0
    await Timer(duration_ns, unit="ns")

@cocotb.test()
async def test_uart_loopback(dut):
    """Test UART transmit and receive"""
    clock = Clock(dut.clk_i, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # Set baud rate (fast for simulation)
    # CLK = 100MHz (10ns), UART = 10MHz -> Divisor = 9
    dut.bit_div_i.value = 9
    dut.stop_bits_i.value = 0 # 1 stop bit

    await reset_dut(dut.rst_i, 20)

    # Initial state
    assert dut.tx_busy_o.value == 0
    assert dut.rx_ready_o.value == 0
    dut.rxd_i.value = 1

    # Transmit a byte
    test_byte = 0xA5
    dut.data_i.value = test_byte
    dut.wr_i.value = 1
    await RisingEdge(dut.clk_i)
    dut.wr_i.value = 0

    await RisingEdge(dut.clk_i)
    assert dut.tx_busy_o.value == 1

    # Loopback txd_o to rxd_i
    async def loopback():
        while True:
            await RisingEdge(dut.clk_i)
            dut.rxd_i.value = dut.txd_o.value

    cocotb.start_soon(loopback())

    # Wait for transmission to complete (approx 10 bits * 10 divisor * 10ns = 1000ns)
    # Plus some overhead
    for _ in range(200):
        await RisingEdge(dut.clk_i)
        if dut.rx_ready_o.value == 1:
            break

    assert dut.rx_ready_o.value == 1
    assert dut.data_o.value == test_byte
    assert dut.rx_err_o.value == 0

    # Read the data
    dut.rd_i.value = 1
    await RisingEdge(dut.clk_i)
    dut.rd_i.value = 0
    await RisingEdge(dut.clk_i)
    assert dut.rx_ready_o.value == 0

@cocotb.test()
async def test_uart_baud_div(dut):
    """Test UART with different baud divisor"""
    clock = Clock(dut.clk_i, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # Divisor = 4
    dut.bit_div_i.value = 4
    dut.stop_bits_i.value = 0

    await reset_dut(dut.rst_i, 20)
    dut.rxd_i.value = 1

    # Transmit
    test_byte = 0x5A
    dut.data_i.value = test_byte
    dut.wr_i.value = 1
    await RisingEdge(dut.clk_i)
    dut.wr_i.value = 0

    # Loopback
    async def loopback():
        while True:
            await RisingEdge(dut.clk_i)
            dut.rxd_i.value = dut.txd_o.value
    cocotb.start_soon(loopback())

    # Wait
    for _ in range(100):
        await RisingEdge(dut.clk_i)
        if dut.rx_ready_o.value == 1:
            break

    assert dut.rx_ready_o.value == 1
    assert dut.data_o.value == test_byte
