import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

async def reset_dut(rst_ni, duration_ns):
    rst_ni.value = 1
    await Timer(duration_ns, unit="ns")
    rst_ni.value = 0
    await Timer(duration_ns, unit="ns")

async def uart_send_byte(dut, byte, bit_div):
    # Start bit
    dut.uart_rxd_i.value = 0
    await Timer(bit_div * 10, unit="ns")
    # Data bits
    for i in range(8):
        dut.uart_rxd_i.value = (byte >> i) & 1
        await Timer(bit_div * 10, unit="ns")
    # Stop bit
    dut.uart_rxd_i.value = 1
    await Timer(bit_div * 10, unit="ns")

async def uart_recv_byte(dut, bit_div):
    # Wait for start bit
    while dut.uart_txd_o.value == 1:
        await RisingEdge(dut.clk_i)

    # Wait to middle of start bit
    await Timer(bit_div * 5, unit="ns")
    # Wait to middle of first data bit
    await Timer(bit_div * 10, unit="ns")

    byte = 0
    for i in range(8):
        byte |= (int(dut.uart_txd_o.value) << i)
        await Timer(bit_div * 10, unit="ns")

    # Stop bit
    # await Timer(bit_div * 10, unit="ns")
    return byte

@cocotb.test()
async def test_bridge_peek(dut):
    """Test bridge peek (read) operation"""
    clock = Clock(dut.clk_i, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # Fast UART for simulation
    # CLK=14.7456MHz (approx 67.8ns)
    # But I'm using 10ns clock (100MHz)
    # For 10MHz UART, bit_div = 9
    bit_div = 10

    # If I use CLK_FREQ=100_000_000 and UART_SPEED=10_000_000
    # bit_div_i = (CLK_FREQ/UART_SPEED) - 1 = 9

    await reset_dut(dut.rst_i, 20)
    dut.uart_rxd_i.value = 1
    dut.mem_arready_i.value = 1
    dut.mem_rvalid_i.value = 0

    # REQ_READ = 0x11
    # LEN = 0x00 (1 word)
    # ADDR = 0x12345678

    cocotb.start_soon(uart_send_byte(dut, 0x11, bit_div))
    await Timer(bit_div * 10 * 11, unit="ns") # wait for send to finish
    cocotb.start_soon(uart_send_byte(dut, 0x00, bit_div))
    await Timer(bit_div * 10 * 11, unit="ns")
    cocotb.start_soon(uart_send_byte(dut, 0x12, bit_div))
    await Timer(bit_div * 10 * 11, unit="ns")
    cocotb.start_soon(uart_send_byte(dut, 0x34, bit_div))
    await Timer(bit_div * 10 * 11, unit="ns")
    cocotb.start_soon(uart_send_byte(dut, 0x56, bit_div))
    await Timer(bit_div * 10 * 11, unit="ns")
    cocotb.start_soon(uart_send_byte(dut, 0x78, bit_div))
    await Timer(bit_div * 10 * 11, unit="ns")

    # Wait for AXI read request
    while dut.mem_arvalid_o.value == 0:
        await RisingEdge(dut.clk_i)

    assert dut.mem_araddr_o.value == 0x12345678

    # Provide AXI response
    dut.mem_rdata_i.value = 0xDEADBEEF
    dut.mem_rvalid_i.value = 1
    await RisingEdge(dut.clk_i)
    dut.mem_rvalid_i.value = 0

    # Receive bytes from UART
    dut._log.info("Waiting for UART response...")
    b0 = await uart_recv_byte(dut, bit_div)
    dut._log.info(f"Got B0: {b0:02x}")
    b1 = await uart_recv_byte(dut, bit_div)
    dut._log.info(f"Got B1: {b1:02x}")
    b2 = await uart_recv_byte(dut, bit_div)
    dut._log.info(f"Got B2: {b2:02x}")
    b3 = await uart_recv_byte(dut, bit_div)
    dut._log.info(f"Got B3: {b3:02x}")

    read_data = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    assert read_data == 0xDEADBEEF
