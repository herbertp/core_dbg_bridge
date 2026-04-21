#!/usr/bin/env python3
import sys
import argparse
import time
import random
import subprocess
import os

# CDMA Register Map (Offsets)
CDMACR    = 0x00  # Control Register
CDMASR    = 0x04  # Status Register
SA        = 0x18  # Source Address
DA        = 0x20  # Destination Address
BTT       = 0x28  # Bytes to Transfer

# CDMA Bit Fields
CR_RESET  = 1 << 2
SR_IDLE   = 1 << 1

def poke(addr, value, args):
    cmd = [sys.executable, 'sw/poke.py', '-t', args.type, '-d', args.device, '-b', str(args.baud), '-a', f"0x{addr:08x}", str(value)]
    subprocess.check_call(cmd)

def peek(addr, args):
    cmd = [sys.executable, 'sw/peek.py', '-t', args.type, '-d', args.device, '-b', str(args.baud), '-a', f"0x{addr:08x}", '-q']
    # peek.py -q returns the value as exit code
    result = subprocess.run(cmd)
    return result.returncode

def main():
    parser = argparse.ArgumentParser(description="Test script for AXI CDMA transfer using peek/poke")
    parser.add_argument('-t', dest='type',   default='uart',          help='Device type (uart|socket)')
    parser.add_argument('-d', dest='device', default='/dev/ttyUSB1',  help='Serial Device')
    parser.add_argument('-b', dest='baud',   default=1000000, type=int, help='Baud rate')
    parser.add_argument('-s', dest='src',    default=0x10000000, type=lambda x: int(x,0), help='Source address')
    parser.add_argument('-o', dest='dst',    default=0x20000000, type=lambda x: int(x,0), help='Destination address')
    parser.add_argument('-l', dest='len',    default=1024, type=lambda x: int(x,0), help='Transfer length in bytes')
    args = parser.parse_args()

    cdma_base = 0x80000000

    print(f"Preparing DMA transfer: {args.len} bytes from 0x{args.src:08x} to 0x{args.dst:08x}")

    # 1. Write some test data to source
    print("Writing test data to source...")
    for i in range(0, min(args.len, 64), 4):
        val = random.getrandbits(32)
        poke(args.src + i, val, args)

    # 2. Clear destination start
    print("Clearing destination start...")
    for i in range(0, min(args.len, 64), 4):
        poke(args.dst + i, 0, args)

    # 3. Initialize CDMA
    print("Resetting CDMA...")
    poke(cdma_base + CDMACR, CR_RESET, args)
    # Wait for reset to complete
    while peek(cdma_base + CDMACR, args) & CR_RESET:
        time.sleep(0.01)

    # 4. Configure CDMA
    print("Configuring CDMA...")
    poke(cdma_base + SA, args.src, args)
    poke(cdma_base + DA, args.dst, args)

    # 5. Start transfer
    print("Starting transfer...")
    poke(cdma_base + BTT, args.len, args)

    # 6. Poll for completion
    print("Polling for completion...")
    start_time = time.time()
    timeout = 5.0 # seconds
    while True:
        status = peek(cdma_base + CDMASR, args)
        if status & SR_IDLE:
            print("Transfer finished.")
            break
        if time.time() - start_time > timeout:
            print("Timeout waiting for DMA completion!")
            sys.exit(1)
        time.sleep(0.05)

    # 7. Verify some data
    print("Verifying data samples...")
    # We only verify the first few words to keep the test reasonably fast with subprocess calls
    for i in range(0, min(args.len, 64), 4):
        src_val = peek(args.src + i, args)
        dst_val = peek(args.dst + i, args)
        if src_val != dst_val:
            print(f"FAILURE: Data mismatch at offset {i}! Expected 0x{src_val:08x}, got 0x{dst_val:08x}")
            sys.exit(1)

    print("SUCCESS: Sampled data matches!")

if __name__ == "__main__":
    # Ensure we are in the repo root or can find sw/
    if not os.path.exists('sw/peek.py'):
        print("Error: sw/peek.py not found. Please run from the repository root.")
        sys.exit(1)
    main()
