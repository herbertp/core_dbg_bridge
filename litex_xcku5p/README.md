# LiteX Adaptation for RK-XCKU5P-F

This directory contains the LiteX/Migen adaptation for the RK-XCKU5P-F V1.2 board.

## Environment Setup

1. Install the required Python packages:
```bash
pip install migen litex litedram liteeth litepcie litescope litespi litesdcard pythondata-cpu-vexriscv pyyaml requests serial pyserial
```

2. Ensure you have Xilinx Vivado installed and added to your PATH.

## SoC Generation

To generate the SoC gateware (Verilog, XDC, etc.):

```bash
python3 target.py
```

This will create a `build/` directory containing the generated files.

## Building the Bitstream

To generate the SoC and build the bitstream using Vivado:

```bash
python3 target.py --build
```

## Loading the Bitstream

To load the generated bitstream to the board:

```bash
python3 target.py --load
```

## Using Python Tools

The Python tools in the `sw/` directory have been adapted to support the LiteX native UART bridge protocol. Use the `-t litex` option to select the LiteX interface. These tools provide the same functionality as the original UART-AXI bridge tools but communicate via the LiteX `RemoteClient` (Etherbone over UART).

**Requirements for Software Tools:**
The tools require `csr.csv` to be present in the directory where they are run (a default `csr.csv` is provided in the root of the repository).

Example (Peeking memory at 0x0):
```bash
export PYTHONPATH=$PYTHONPATH:$(pwd)/sw
./sw/peek.py -t litex -d /dev/ttyUSB1 -b 115200 -a 0x0
```

Example (Poking memory at 0x0):
```bash
export PYTHONPATH=$PYTHONPATH:$(pwd)/sw
./sw/poke.py -t litex -d /dev/ttyUSB1 -b 115200 -a 0x0 -v 0x12345678
```

Example (Dumping a block of memory):
```bash
export PYTHONPATH=$PYTHONPATH:$(pwd)/sw
./sw/dump.py -t litex -d /dev/ttyUSB1 -b 115200 -a 0x0 -l 256
```

Example (Loading a binary file to memory):
```bash
export PYTHONPATH=$PYTHONPATH:$(pwd)/sw
./sw/load_bin.py -t litex -d /dev/ttyUSB1 -b 115200 -a 0x0 -f data.bin
```

Note: The LiteX SoC is configured with DDR4 starting at `0x00000000` for backwards compatibility with existing AXI-based address maps.
