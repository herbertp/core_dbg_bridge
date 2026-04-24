import serial
from typing import Callable, Optional

##################################################################
# UartBusInterface: UART -> Bus master interface
##################################################################
class UartBusInterface:
    """
    UartBusInterface provides a bus master interface over a serial port.
    """
    def __init__(self, iface: str = '/dev/ttyUSB1', baud: int = 4000000):
        self.interface = iface
        self.baud = baud
        self.uart: Optional[serial.Serial] = None
        self.prog_cb: Optional[Callable[[int, int], None]] = None
        self.CMD_WRITE = 0x10
        self.CMD_READ = 0x11
        self.MAX_SIZE = 255
        self.BLOCK_SIZE = 128
        self.GPIO_ADDR = 0xF0000000
        self.STS_ADDR = 0xF0000004

    def set_progress_cb(self, prog_cb: Callable[[int, int], None]):
        """Set progress callback."""
        self.prog_cb = prog_cb

    def connect(self):
        """Open serial connection."""
        self.uart = serial.Serial(
            port=self.interface,
            baudrate=self.baud,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            bytesize=serial.EIGHTBITS,
            timeout=1.0  # Add timeout to avoid hanging
        )

        # Check status register
        value = self.read32(self.STS_ADDR)
        if (value & 0xFFFF0000) != 0xcafe0000:
            raise Exception(f"Target not responding correctly (0x{value:08x}), check interface / baud rate...")

    def read32(self, addr: int) -> int:
        """Read a 32-bit word from a specified address."""
        if self.uart is None:
            self.connect()

        # Send read command
        cmd = bytearray([
            self.CMD_READ,
            4,
            (addr >> 24) & 0xFF,
            (addr >> 16) & 0xFF,
            (addr >> 8)  & 0xFF,
            (addr >> 0)  & 0xFF
        ])
        self.uart.write(cmd)

        resp = self.uart.read(4)
        if len(resp) < 4:
            raise Exception("Timeout reading from UART")

        value = 0
        for idx, b in enumerate(resp):
            value |= (b << (idx * 8))

        return value

    def write32(self, addr: int, value: int):
        """Write a 32-bit word to a specified address."""
        if self.uart is None:
            self.connect()

        # Send write command
        cmd = bytearray([
            self.CMD_WRITE,
            4,
            (addr >> 24) & 0xFF,
            (addr >> 16) & 0xFF,
            (addr >> 8)  & 0xFF,
            (addr >> 0)  & 0xFF,
            (value >> 0) & 0xFF,
            (value >> 8) & 0xFF,
            (value >> 16) & 0xFF,
            (value >> 24) & 0xFF
        ])
        self.uart.write(cmd)

    def write(self, addr: int, data: bytes | bytearray, length: int, addr_incr: bool = True, max_block_size: int = -1):
        """Write a block of data to a specified address."""
        if self.uart is None:
            self.connect()

        idx = 0
        remainder = length

        if self.prog_cb:
            self.prog_cb(0, length)

        if max_block_size == -1:
            max_block_size = self.BLOCK_SIZE

        while remainder > 0:
            l = min(max_block_size, remainder)

            cmd = bytearray(2 + 4 + l)
            cmd[0] = self.CMD_WRITE
            cmd[1] = l & 0xFF
            cmd[2] = (addr >> 24) & 0xFF
            cmd[3] = (addr >> 16) & 0xFF
            cmd[4] = (addr >> 8)  & 0xFF
            cmd[5] = (addr >> 0)  & 0xFF

            cmd[6:6+l] = data[idx:idx+l]
            idx += l

            # Write to serial port
            self.uart.write(cmd)

            if self.prog_cb:
                self.prog_cb(idx, length)

            if addr_incr:
                addr += l
            remainder -= l

    def read(self, addr: int, length: int, addr_incr: bool = True, max_block_size: int = -1) -> bytearray:
        """Read a block of data from a specified address."""
        if self.uart is None:
            self.connect()

        idx = 0
        data = bytearray(length)

        if self.prog_cb:
            self.prog_cb(0, length)

        if max_block_size == -1:
            max_block_size = self.BLOCK_SIZE

        # Pipelined read parameters
        # max_in_flight * 6 bytes (cmd) must fit in target RX FIFO (64 bytes)
        # 8 * 6 = 48 bytes < 64.
        max_in_flight = 8

        commands_issued = 0
        bytes_requested = 0
        bytes_received = 0

        current_read_addr = addr
        pending_lengths = []

        while bytes_received < length:
            # Fill pipeline
            while commands_issued < max_in_flight and bytes_requested < length:
                l = min(max_block_size, length - bytes_requested)

                cmd = bytearray([
                    self.CMD_READ,
                    l & 0xFF,
                    (current_read_addr >> 24) & 0xFF,
                    (current_read_addr >> 16) & 0xFF,
                    (current_read_addr >> 8)  & 0xFF,
                    (current_read_addr >> 0)  & 0xFF
                ])

                self.uart.write(cmd)

                pending_lengths.append(l)
                bytes_requested += l
                commands_issued += 1
                if addr_incr:
                    current_read_addr += l

            # Receive one block
            if pending_lengths:
                l = pending_lengths.pop(0)
                resp = self.uart.read(l)
                if len(resp) < l:
                    raise Exception(f"Timeout reading from UART (expected {l}, got {len(resp)})")

                data[bytes_received:bytes_received+l] = resp
                bytes_received += l
                commands_issued -= 1

                if self.prog_cb:
                    self.prog_cb(bytes_received, length)

        return data

    def read_gpio(self) -> int:
        """Read GPIO bus."""
        return self.read32(self.GPIO_ADDR)

    def write_gpio(self, value: int):
        """Write a byte to GPIO."""
        self.write32(self.GPIO_ADDR, value)
