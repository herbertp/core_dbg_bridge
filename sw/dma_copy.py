#!/usr/bin/env python3
import sys
import time
import argparse
import csv
import os

from bus_interface import BusInterface

def parse_csr(csr_csv):
    csr = {}
    if not os.path.exists(csr_csv):
        return csr
    with open(csr_csv, 'r') as f:
        reader = csv.reader(f)
        for row in reader:
            if row[0] == 'csr_register':
                csr[row[1]] = int(row[2], 0)
    return csr

def main():
    parser = argparse.ArgumentParser(description="LiteX DMA Copy Script")
    parser.add_argument('-t', dest='type',   default='litex', help='Device type (uart|socket|litex)')
    parser.add_argument('-d', dest='device', default='/dev/ttyUSB1', help='Serial Device')
    parser.add_argument('-b', dest='baud',   default=4000000, type=int, help='Baud rate')
    parser.add_argument('--src', required=True, help='Source byte address (32-byte aligned)')
    parser.add_argument('--dst', required=True, help='Destination byte address (32-byte aligned)')
    parser.add_argument('--len', required=True, help='Length in bytes (32-byte aligned)')
    parser.add_argument('--csr', default='csr.csv', help='LiteX CSR CSV file')
    args = parser.parse_args()

    # Load CSRs
    csr = parse_csr(args.csr)
    if not csr:
        print(f"Error: Could not load CSRs from {args.csr}")
        sys.exit(1)

    try:
        addr_src    = csr['memcopy_source']
        addr_dst    = csr['memcopy_dest']
        addr_len    = csr['memcopy_length']
        addr_ctl    = csr['memcopy_ctl']
        addr_busy   = csr['memcopy_busy']
    except KeyError as e:
        print(f"Error: DMA CSR not found: {e}")
        sys.exit(1)

    bus_if = BusInterface(args.type, args.device, args.baud)

    src_byte = int(args.src, 0)
    dst_byte = int(args.dst, 0)
    len_byte = int(args.len, 0)

    # LiteDRAM native ports use word addresses. 256-bit = 32 bytes.
    if src_byte & 0x1F:
        print(f"Error: Source address 0x{src_byte:08x} is not 32-byte aligned.")
        sys.exit(1)
    if dst_byte & 0x1F:
        print(f"Error: Destination address 0x{dst_byte:08x} is not 32-byte aligned.")
        sys.exit(1)
    if len_byte & 0x1F:
        print(f"Error: Length {len_byte} is not a multiple of 32 bytes.")
        sys.exit(1)

    src_word = src_byte // 32
    dst_word = dst_byte // 32
    len_word = len_byte // 32

    print(f"Configuring DMA: 0x{src_byte:08x} -> 0x{dst_byte:08x} ({len_byte} bytes)")
    print(f"Word addresses: 0x{src_word:08x} -> 0x{dst_word:08x} ({len_word} beats)")

    bus_if.write32(addr_src, src_word)
    bus_if.write32(addr_dst, dst_word)
    bus_if.write32(addr_len, len_word)

    print("Starting DMA transfer...")
    bus_if.write32(addr_ctl, 1) # Start bit

    # Poll for completion
    start_time = time.time()
    while True:
        busy = bus_if.read32(addr_busy)
        if not busy:
            break
        time.sleep(0.01)
        if time.time() - start_time > 10.0: # 10s timeout
            print("Timeout waiting for DMA completion!")
            sys.exit(1)

    end_time = time.time()
    print(f"DMA transfer complete in {end_time - start_time:.4f}s")

if __name__ == "__main__":
    main()
