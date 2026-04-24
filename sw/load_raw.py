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
    parser = argparse.ArgumentParser(description="Read binary data from stdin and write to memory")
    parser.add_argument('-t', dest='type',    default='uart',                     help='Device type (uart|socket|litex)')
    parser.add_argument('-d', dest='device',  default='/dev/ttyUSB1',             help='Serial Device')
    parser.add_argument('-b', dest='baud',    default=4000000,       type=int,    help='Baud rate')
    parser.add_argument('-a', dest='address', required=True,                      help='Address to write to')
    parser.add_argument('-s', dest='size',    default=None,                       help='Size limit (optional)')
    args = parser.parse_args()

    bus_if = BusInterface(args.type, args.device, args.baud)

    try:
        addr = int(args.address, 0)
        size_limit = int(args.size, 0) if args.size is not None else None
    except ValueError as e:
        sys.stderr.write(f"Error: Invalid address or size format: {e}\n")
        sys.exit(1)

    chunk_size = 1024 * 1024
    current_addr = addr
    total_written = 0

    if size_limit is not None:
        sys.stderr.write(f"Loading {size_limit} bytes to 0x{addr:08x}\n")
        print_progress(0, size_limit)
    else:
        sys.stderr.write(f"Loading from stdin to 0x{addr:08x} (until EOF)\n")

    try:
        while True:
            read_size = chunk_size
            if size_limit is not None:
                read_size = min(chunk_size, size_limit - total_written)

            if read_size == 0 and size_limit is not None:
                break

            data = sys.stdin.buffer.read(read_size)
            if not data:
                break

            bus_if.write(current_addr, data, len(data))

            total_written += len(data)
            current_addr += len(data)

            if size_limit is not None:
                print_progress(total_written, size_limit)
            else:
                sys.stderr.write(f"\rWritten {total_written} bytes...")
                sys.stderr.flush()

        if size_limit is None:
            sys.stderr.write("\n")

        # Discard remaining data if size limit was reached
        if size_limit is not None and total_written == size_limit:
            sys.stderr.write("Discarding extra data from stdin...\n")
            # Drain stdin without hanging on potentially infinite streams
            sys.stdin.buffer.raw.close()

        sys.stderr.write(f"Successfully written {total_written} bytes.\n")

    except KeyboardInterrupt:
        sys.stderr.write("\nAborted by user\n")
        sys.exit(1)
    except Exception as e:
        sys.stderr.write(f"\nError during load: {e}\n")
        sys.exit(1)

if __name__ == "__main__":
    main()
