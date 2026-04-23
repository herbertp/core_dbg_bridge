#!/usr/bin/env python3
import sys
import argparse

from bus_interface import BusInterface

def print_progress(iteration, total, prefix='Progress', suffix='', decimals=1, bar_length=50):
    if total == 0:
        return
    percents = f"{100 * (iteration / float(total)):.{decimals}f}"
    filled_length = int(round(bar_length * iteration / float(total)))
    bar = 'X' * filled_length + ' ' * (bar_length - filled_length)

    sys.stderr.write(f'\r{prefix} |{bar}| {percents}% {suffix}')
    sys.stderr.flush()

    if iteration == total:
        sys.stderr.write('\n')
        sys.stderr.flush()

def main():
    parser = argparse.ArgumentParser(description="Dump memory to stdout as raw binary data")
    parser.add_argument('-d', dest='device',  default='/dev/ttyUSB1',             help='Serial Device')
    parser.add_argument('-b', dest='baud',    default=4000000,       type=int,    help='Baud rate')
    parser.add_argument('-a', dest='address', required=True,                      help='Address to dump from')
    parser.add_argument('-s', dest='size',    required=True,                      help='Size to dump')
    args = parser.parse_args()

    # We use 'litex' as requested, but BusInterface allows others.
    # The requirement said LiteX support is enough for now.
    bus_if = BusInterface('litex', args.device, args.baud)

    try:
        addr = int(args.address, 0)
        size = int(args.size, 0)
    except ValueError as e:
        sys.stderr.write(f"Error: Invalid address or size format: {e}\n")
        sys.exit(1)

    # Chunk size for large transfers to avoid excessive memory usage.
    # 1MB is a good compromise between overhead and memory usage.
    chunk_size = 1024 * 1024

    remaining = size
    current_addr = addr

    print_progress(0, size)

    try:
        while remaining > 0:
            this_chunk = min(remaining, chunk_size)
            data = bus_if.read(current_addr, this_chunk)

            sys.stdout.buffer.write(data)

            current_addr += this_chunk
            remaining -= this_chunk

            print_progress(size - remaining, size)

        sys.stdout.buffer.flush()
    except KeyboardInterrupt:
        sys.stderr.write("\nAborted by user\n")
        sys.exit(1)
    except Exception as e:
        sys.stderr.write(f"\nError during dump: {e}\n")
        sys.exit(1)

if __name__ == "__main__":
    main()
