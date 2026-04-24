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

**Configuration for 2400MT/s:**
The SoC runs at 300MHz to achieve 2400MT/s on the DDR4. To facilitate timing closure, the CPU runs on a separate 150MHz clock domain.

**Memory Map:**
- Main RAM (DDR4): 0x00000000 (2GB)
- ROM: 0x80000000
- SRAM: 0x81000000
- CSR: 0xf0000000
