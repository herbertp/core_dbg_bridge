#!/usr/bin/env python3
import sys
import argparse
import time
import random

from bus_interface import BusInterface

# CDMA Register Map (Offsets)
CDMACR    = 0x00  # Control Register
CDMASR    = 0x04  # Status Register
SA        = 0x18  # Source Address
DA        = 0x20  # Destination Address
BTT       = 0x28  # Bytes to Transfer

# CDMA Bit Fields
CR_RESET  = 1 << 2
SR_IDLE   = 1 << 1

def main():
    parser = argparse.ArgumentParser(description="Test script for AXI CDMA transfer")
    parser.add_argument('-t', dest='type',   default='uart',          help='Device type (uart|socket)')
    parser.add_argument('-d', dest='device', default='/dev/ttyUSB1',  help='Serial Device')
    parser.add_argument('-b', dest='baud',   default=1000000, type=int, help='Baud rate')
    parser.add_argument('-s', dest='src',    default=0x10000000, type=lambda x: int(x,0), help='Source address')
    parser.add_argument('-o', dest='dst',    default=0x20000000, type=lambda x: int(x,0), help='Destination address')
    parser.add_argument('-l', dest='len',    default=1024, type=lambda x: int(x,0), help='Transfer length in bytes')
    args = parser.parse_args()

    bus_if = BusInterface(args.type, args.device, args.baud)
    cdma_base = 0x80000000

    print(f"Preparing DMA transfer: {args.len} bytes from 0x{args.src:08x} to 0x{args.dst:08x}")

    # 1. Write random test pattern to source
    pattern = bytearray([random.getrandbits(8) for _ in range(args.len)])
    print("Writing test pattern to source...")
    bus_if.write(args.src, pattern, args.len)

    # 2. Clear destination
    print("Clearing destination...")
    bus_if.write(args.dst, bytearray([0] * args.len), args.len)

    # 3. Initialize CDMA
    print("Resetting CDMA...")
    bus_if.write32(cdma_base + CDMACR, CR_RESET)
    # Wait for reset to complete
    while bus_if.read32(cdma_base + CDMACR) & CR_RESET:
        time.sleep(0.01)

    # 4. Configure CDMA
    print("Configuring CDMA...")
    bus_if.write32(cdma_base + SA, args.src)
    bus_if.write32(cdma_base + DA, args.dst)

    # 5. Start transfer
    print("Starting transfer...")
    bus_if.write32(cdma_base + BTT, args.len)

    # 6. Poll for completion
    print("Polling for completion...")
    start_time = time.time()
    timeout = 5.0 # seconds
    while True:
        status = bus_if.read32(cdma_base + CDMASR)
        if status & SR_IDLE:
            print("Transfer finished.")
            break
        if time.time() - start_time > timeout:
            print("Timeout waiting for DMA completion!")
            sys.exit(1)
        time.sleep(0.01)

    # 7. Verify data
    print("Verifying data...")
    readback = bus_if.read(args.dst, args.len)
    if readback == pattern:
        print("SUCCESS: Data matches!")
    else:
        print("FAILURE: Data mismatch!")
        # Find first mismatch
        for i in range(args.len):
            if readback[i] != pattern[i]:
                print(f"First mismatch at offset {i}: Expected 0x{pattern[i]:02x}, got 0x{readback[i]:02x}")
                break
        sys.exit(1)

if __name__ == "__main__":
    main()
