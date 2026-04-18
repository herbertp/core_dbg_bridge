import socket
from typing import Callable, Optional

##################################################################
# SocketInterface: Socket -> Bus master
##################################################################
class SocketInterface:
    """
    SocketInterface provides a bus master interface over a UDP socket.
    """
    def __init__(self, port_num: str = '2000'):
        self.server_addr = ('localhost', int(port_num))
        self.sock: Optional[socket.socket] = None
        self.prog_cb: Optional[Callable[[int, int], None]] = None
        self.CMD_WRITE = 0x10
        self.CMD_READ = 0x11
        self.MAX_SIZE = 255
        self.BLOCK_SIZE = 128

    def set_progress_cb(self, prog_cb: Callable[[int, int], None]):
        """Set progress callback."""
        self.prog_cb = prog_cb

    def connect(self):
        """Create socket."""
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.settimeout(1.0) # Add timeout for robustness

    def read32(self, addr: int) -> int:
        """Read a 32-bit word from a specified address."""
        if self.sock is None:
            self.connect()

        # Send read command
        cmd = bytearray([
            self.CMD_READ,
            4,
            (addr >> 24) & 0xFF,
            (addr >> 16) & 0xFF,
            (addr >>  8) & 0xFF,
            (addr >>  0) & 0xFF
        ])
        self.sock.sendto(cmd, self.server_addr)

        try:
            resp, _ = self.sock.recvfrom(4)
        except socket.timeout:
            raise Exception("Timeout reading from socket")

        if len(resp) < 4:
            raise Exception(f"Short read from socket (expected 4, got {len(resp)})")

        value = 0
        for idx, b in enumerate(resp):
            value |= (b << (idx * 8))

        return value

    def write32(self, addr: int, value: int):
        """Write a 32-bit word to a specified address."""
        if self.sock is None:
            self.connect()

        # Send write command
        cmd = bytearray([
            self.CMD_WRITE,
            4,
            (addr >> 24) & 0xFF,
            (addr >> 16) & 0xFF,
            (addr >>  8) & 0xFF,
            (addr >>  0) & 0xFF,
            (value >> 0) & 0xFF,
            (value >> 8) & 0xFF,
            (value >> 16) & 0xFF,
            (value >> 24) & 0xFF
        ])
        self.sock.sendto(cmd, self.server_addr)
        try:
            self.sock.recvfrom(1)
        except socket.timeout:
            raise Exception("Timeout waiting for write acknowledgment from socket")

    def write(self, addr: int, data: bytes | bytearray, length: int, addr_incr: bool = True, max_block_size: int = -1):
        """Write a block of data to a specified address."""
        if self.sock is None:
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

            # Write to socket
            self.sock.sendto(cmd, self.server_addr)
            try:
                self.sock.recvfrom(1)
            except socket.timeout:
                raise Exception("Timeout waiting for block write acknowledgment from socket")

            if self.prog_cb:
                self.prog_cb(idx, length)

            if addr_incr:
                addr += l
            remainder -= l

    def read(self, addr: int, length: int, addr_incr: bool = True, max_block_size: int = -1) -> bytearray:
        """Read a block of data from a specified address."""
        if self.sock is None:
            self.connect()

        idx = 0
        remainder = length
        data = bytearray(length)

        if self.prog_cb:
            self.prog_cb(0, length)

        if max_block_size == -1:
            max_block_size = self.BLOCK_SIZE

        while remainder > 0:
            l = min(max_block_size, remainder)

            cmd = bytearray([
                self.CMD_READ,
                l & 0xFF,
                (addr >> 24) & 0xFF,
                (addr >> 16) & 0xFF,
                (addr >> 8)  & 0xFF,
                (addr >> 0)  & 0xFF
            ])

            # Write to socket
            self.sock.sendto(cmd, self.server_addr)

            # Read block response
            try:
                resp, _ = self.sock.recvfrom(l)
            except socket.timeout:
                raise Exception("Timeout reading block from socket")

            if len(resp) < l:
                raise Exception(f"Short read from socket (expected {l}, got {len(resp)})")

            data[idx:idx+l] = resp
            idx += l

            if self.prog_cb:
                self.prog_cb(idx, length)

            if addr_incr:
                addr += l
            remainder -= l

        return data

    def read_gpio(self) -> int:
        """Read GPIO bus."""
        return self.read32(0xF0000000)

    def write_gpio(self, value: int):
        """Write a byte to GPIO."""
        self.write32(0xF0000000, value)
