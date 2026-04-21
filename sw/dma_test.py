#!/usr/bin/env python3
import sys
import argparse
import time
import random

from bus_interface import BusInterface

# DMA Register Offsets
DMA_REG_START    = 0x80000000
DMA_REG_SRC_ADDR = 0x80000004
DMA_REG_DST_ADDR = 0x80000008
DMA_REG_LENGTH   = 0x8000000C

def main():
    parser = argparse.ArgumentParser(description="Test script for AXI DMA transfer")
    parser.add_argument('-t', dest='type',   default='uart',          help='Device type (uart|socket)')
    parser.add_argument('-d', dest='device', default='/dev/ttyUSB1',  help='Serial Device')
    parser.add_argument('-b', dest='baud',   default=1000000, type=int, help='Baud rate')
    parser.add_argument('--src', default=0x00000000, type=lambda x: int(x, 0), help='Source address (DDR4)')
    parser.add_argument('--dst', default=0x00010000, type=lambda x: int(x, 0), help='Destination address (DDR4)')
    parser.add_argument('--len', default=0x00001000, type=lambda x: int(x, 0), help='Length in bytes (aligned to 32)')
    args = parser.parse_args()

    bus_if = BusInterface(args.type, args.device, args.baud)

    # 1. Initialize source memory with random data
    print(f"Initializing source memory at 0x{args.src:08x}...")
    test_data = []
    for i in range(0, args.len, 4):
        val = random.getrandbits(32)
        bus_if.write32(args.src + i, val)
        test_data.append(val)

    # 2. Clear destination memory
    print(f"Clearing destination memory at 0x{args.dst:08x}...")
    for i in range(0, args.len, 4):
        bus_if.write32(args.dst + i, 0)

    # 3. Configure DMA
    print(f"Configuring DMA: SRC=0x{args.src:08x}, DST=0x{args.dst:08x}, LEN=0x{args.len:08x}")
    bus_if.write32(DMA_REG_SRC_ADDR, args.src)
    bus_if.write32(DMA_REG_DST_ADDR, args.dst)
    bus_if.write32(DMA_REG_LENGTH, args.len)

    # 4. Start DMA
    print("Starting DMA transfer...")
    start_time = time.time()
    bus_if.write32(DMA_REG_START, 1)

    # 5. Poll for completion
    while True:
        status = bus_if.read32(DMA_REG_START)
        if (status & 1) == 0:
            break
        time.sleep(0.01)

    end_time = time.time()
    duration = end_time - start_time
    print(f"DMA transfer finished in {duration:.4f} seconds.")

    # 6. Verify data
    print("Verifying data...")
    errors = 0
    for i in range(0, args.len, 4):
        val = bus_if.read32(args.dst + i)
        expected = test_data[i // 4]
        if val != expected:
            if errors < 10:
                print(f"Mismatch at 0x{args.dst + i:08x}: Read 0x{val:08x}, Expected 0x{expected:08x}")
            errors += 1

    if errors == 0:
        print("Verification SUCCESS!")
    else:
        print(f"Verification FAILED with {errors} mismatches.")
        sys.exit(1)

if __name__ == "__main__":
    main()
