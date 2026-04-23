import struct
from typing import Callable, Optional
from litex.tools.remote.comm_uart import CommUART

##################################################################
# LiteXBusInterface: LiteX UART -> Bus master interface
##################################################################
class LiteXBusInterface:
    """
    LiteXBusInterface provides a bus master interface over a serial port
    using the LiteX/Etherbone protocol.
    """
    def __init__(self, iface: str = '/dev/ttyUSB1', baud: int = 115200, csr_csv: str = "csr.csv"):
        self.interface = iface
        self.baud = baud
        self.csr_csv = csr_csv
        self.client: Optional[CommUART] = None
        self.prog_cb: Optional[Callable[[int, int], None]] = None

    def set_progress_cb(self, prog_cb: Callable[[int, int], None]):
        """Set progress callback."""
        self.prog_cb = prog_cb

    def connect(self):
        """Open connection."""
        self.client = CommUART(
            port=self.interface,
            baudrate=self.baud,
            csr_csv=self.csr_csv,
            debug=False
        )
        self.client.open()

    def read32(self, addr: int) -> int:
        """Read a 32-bit word from a specified address."""
        if self.client is None:
            self.connect()
        return self.client.read(addr)

    def write32(self, addr: int, value: int):
        """Write a 32-bit word to a specified address."""
        if self.client is None:
            self.connect()
        self.client.write(addr, value)

    def write(self, addr: int, data: bytes | bytearray, length: int, addr_incr: bool = True, max_block_size: int = -1):
        """Write a block of data to a specified address."""
        if self.client is None:
            self.connect()

        # CommUART handles block transfers
        burst = "incr" if addr_incr else "fixed"

        # LiteX CSRs and memory are 32-bit word aligned.
        # For non-aligned starts or ends, we should ideally do RMW.
        # But for simplicity and common use cases (DDR), we usually expect alignment.
        # Let's at least handle the end padding by reading the last word first if it's partial.

        if (addr % 4) != 0:
            # This is harder to handle with the current CommUART.write(addr, values)
            # if we want to be performant. For now, assume 4-byte aligned start.
            pass

        actual_data = bytearray(data[:length])
        if (length % 4) != 0:
            last_word_addr = addr + (length // 4) * 4
            try:
                last_word = self.read32(last_word_addr)
            except:
                last_word = 0

            last_word_bytes = bytearray(struct.pack('<I', last_word))
            padding_needed = 4 - (length % 4)
            for i in range(padding_needed):
                actual_data.append(last_word_bytes[(length % 4) + i])

        # Prepare list of 32-bit integers using struct for performance
        num_words = len(actual_data) // 4
        values = list(struct.unpack(f'<{num_words}I', actual_data))

        self.client.write(addr, values, burst=burst)

        if self.prog_cb:
            self.prog_cb(length, length)

    def read(self, addr: int, length: int, addr_incr: bool = True, max_block_size: int = -1) -> bytearray:
        """Read a block of data from a specified address."""
        if self.client is None:
            self.connect()

        burst = "incr" if addr_incr else "fixed"
        num_words = (length + 3) // 4
        values = self.client.read(addr, length=num_words, burst=burst)

        # Use struct for performance
        data = bytearray(struct.pack(f'<{len(values)}I', *values))

        if self.prog_cb:
            self.prog_cb(length, length)

        return data[:length]

    def read_gpio(self) -> int:
        """Read GPIO bus (mapping to leds.out for example, or common CSR)."""
        if self.client is None:
            self.connect()
        try:
            return self.client.regs.leds_out.read()
        except:
            return 0

    def write_gpio(self, value: int):
        """Write a value to GPIO."""
        if self.client is None:
            self.connect()
        try:
            self.client.regs.leds_out.write(value)
        except:
            pass
