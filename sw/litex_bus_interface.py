import struct
from typing import Callable, Optional, Union
from litex.tools.remote.comm_uart import CommUART
from litex.tools.litex_client import RemoteClient

##################################################################
# LiteXBusInterface: LiteX UART/TCP -> Bus master interface
##################################################################
class LiteXBusInterface:
    """
    LiteXBusInterface provides a bus master interface over a serial port
    or TCP connection using the LiteX protocol.
    """
    def __init__(self, iface: str = '/dev/ttyUSB1', baud: int = 115200, csr_csv: str = "csr.csv"):
        self.interface = iface
        self.baud = baud
        self.csr_csv = csr_csv
        self.client: Optional[Union[CommUART, RemoteClient]] = None
        self.prog_cb: Optional[Callable[[int, int], None]] = None
        # Max words per UART burst (protocol uses a single byte for length)
        # We use 255 which is the theoretical max, or 128 for more robustness.
        # LiteX uses 8 for writes, but we want performance. Let's use 255.
        self.MAX_WORDS_PER_BURST = 255

    def set_progress_cb(self, prog_cb: Callable[[int, int], None]):
        """Set progress callback."""
        self.prog_cb = prog_cb

    def connect(self):
        """Open connection."""
        if ":" in self.interface:
            # TCP connection (host:port)
            host, port = self.interface.split(":")
            self.client = RemoteClient(
                host=host,
                port=int(port),
                csr_csv=self.csr_csv,
                debug=False
            )
        else:
            # Serial connection
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

        if (addr % 4) != 0:
            raise ValueError(f"LiteX address must be 4-byte aligned (0x{addr:08x})")

        burst = "incr" if addr_incr else "fixed"

        # LiteDRAM and LiteX memory are 32-bit word aligned.
        # Perform RMW for the last word if it's partial.
        actual_data = bytearray(data[:length])
        if (length % 4) != 0:
            last_word_addr = addr + (length // 4) * 4
            try:
                last_word = self.read32(last_word_addr)
            except:
                last_word = 0

            last_word_bytes = struct.pack('<I', last_word)
            actual_data.extend(last_word_bytes[length % 4:])

        # Protocol limit chunking (max 255 words per burst)
        num_words_total = len(actual_data) // 4
        words_written = 0

        while words_written < num_words_total:
            words_to_write = min(self.MAX_WORDS_PER_BURST, num_words_total - words_written)
            chunk_data = actual_data[words_written*4 : (words_written + words_to_write)*4]
            values = list(struct.unpack(f'<{words_to_write}I', chunk_data))

            # Mask to 32-bit unsigned to prevent ValueError in struct.pack later
            values = [v & 0xFFFFFFFF for v in values]

            self.client.write(addr + words_written*4, values, burst=burst)
            words_written += words_to_write

        if self.prog_cb:
            self.prog_cb(length, length)

    def read(self, addr: int, length: int, addr_incr: bool = True, max_block_size: int = -1) -> bytearray:
        """Read a block of data from a specified address."""
        if self.client is None:
            self.connect()

        burst = "incr" if addr_incr else "fixed"

        num_words_total = (length + 3) // 4
        values = []

        words_read = 0
        while words_read < num_words_total:
            words_to_read = min(self.MAX_WORDS_PER_BURST, num_words_total - words_read)
            chunk_values = self.client.read(addr + words_read*4, length=words_to_read, burst=burst)

            if not isinstance(chunk_values, list):
                chunk_values = [chunk_values]

            values.extend(chunk_values)
            words_read += words_to_read

        # Use struct for performance and safety
        data = bytearray()
        for v in values:
            data.extend(struct.pack('<I', v & 0xFFFFFFFF))

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
