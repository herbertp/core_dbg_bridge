# LiteX Adaptation for RK-XCKU5P-F

This directory contains the LiteX/Migen adaptation for the RK-XCKU5P-F V1.2 board.

## Environment Setup

1. Install the required Python packages:
```bash
pip install migen litex litedram liteeth litepcie litescope litespi litesdcard pythondata-cpu-vexriscv pythondata-software-picolibc pythondata-software-compiler-rt pyyaml requests serial pyserial
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

The SoC is configured with a VexRiscv CPU and a standard serial UART at 115200 baud. The BIOS will automatically perform DDR4 training on startup.

Python tools in the `sw/` directory can still be used if the SoC is built with `uartbone` or if a bridge is active. By default, the UART is dedicated to the CPU console.
