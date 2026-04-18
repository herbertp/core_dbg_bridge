from uart_bus_interface import UartBusInterface
from socket_interface import SocketInterface

##################################################################
# BusInterface: Bus Interface Wrapper
##################################################################
class BusInterface:
    """
    BusInterface provides a common interface for communicating with a target
    device over either UART or a socket connection.
    """
    def __init__(self, iface_type: str = 'uart', iface: str = '/dev/ttyUSB1', baud: int = 115200):
        if iface_type == "uart":
            self.bus = UartBusInterface(iface, baud)
        elif iface_type == "socket":
            self.bus = SocketInterface(iface)
        else:
            self.bus = None

    def set_progress_cb(self, prog_cb):
        """Set progress callback."""
        if self.bus:
            self.bus.set_progress_cb(prog_cb)

    def open(self):
        """Open connection."""
        pass

    def close(self):
        """Close connection."""
        pass

    def write(self, addr: int, data: bytes | bytearray, length: int, addr_incr: bool = True, max_block_size: int = -1):
        """Write a block of data to a specified address."""
        if self.bus:
            self.bus.write(addr, data, length, addr_incr, max_block_size)

    def read(self, addr: int, length: int, addr_incr: bool = True, max_block_size: int = -1) -> bytearray:
        """Read a block of data from a specified address."""
        if self.bus:
            return self.bus.read(addr, length, addr_incr, max_block_size)
        return bytearray()

    def read32(self, addr: int) -> int:
        """Read a 32-bit word from a specified address."""
        if self.bus:
            return self.bus.read32(addr)
        return 0

    def write32(self, addr: int, value: int):
        """Write a 32-bit word to a specified address."""
        if self.bus:
            self.bus.write32(addr, value)
  
    def read_gpio(self) -> int:
        """Read GPIO bus."""
        if self.bus:
            return self.bus.read_gpio()
        return 0

    def write_gpio(self, value: int):
        """Write a value to GPIO."""
        if self.bus:
            self.bus.write_gpio(value)
