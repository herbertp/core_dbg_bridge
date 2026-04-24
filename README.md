### UART -> AXI Debug Bridge

Github:   [http://github.com/ultraembedded/cores](https://github.com/ultraembedded/cores/tree/master/dbg_bridge)

This component provides a bridge from a standard UART interface (8N1) to a AXI4 bus master & GPIO interface.  
This can be very useful for FPGA dev boards featuring a FTDI UART interface where loading memories, peeking, poking SoC state is required.

##### Testing

Used extensively on various Xilinx FPGAs over the years.

##### Configuration
* CLK_FREQ - Clock (clk_i) frequency (in Hz).
* UART_SPEED - UART baud rate (bps)
* AXI_ID - AXI ID to be used for transactions

##### Software
Included python based utils provide peek and poke access, plus binary load / dump support.

Examples:
```
# Read a memory location (0x0)
./sw/peek.py -d /dev/ttyUSB1 -b 115200 -a 0x0

# Write a memory word (0x0 = 0x12345678)
./sw/poke.py -d /dev/ttyUSB1 -b 115200 -a 0x0 -v 0x12345678
```

#### LiteX Crossover UART Usage

The LiteX based examples (e.g., `litex_xcku5p`) use a crossover UART. This allows multiple clients to share the same physical UART for both a CPU console and a memory bridge.

1.  **Start the LiteX Server:**
    In a dedicated terminal, start the server to manage the physical UART connection:
    ```bash
    litex_server --uart --uart-port /dev/ttyUSB1 --uart-baudrate 4000000
    ```

2.  **Access the CPU Console:**
    In another terminal, connect to the server's console port:
    ```bash
    litex_term crossover
    ```
    (Note: `litex_term` connects to `localhost:1234` by default when the port is specified as `crossover`).

3.  **Use the Software Tools:**
    The provided tools in `sw/` automatically detect the TCP address and connect via the server:
    ```bash
    # Read DDR4 location
    ./sw/peek.py -d localhost:1234 -a 0x0
    ```