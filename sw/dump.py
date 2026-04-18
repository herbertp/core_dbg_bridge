#!/usr/bin/env python3
import sys
import argparse

from bus_interface import BusInterface

##################################################################
# Print iterations progress
##################################################################
def print_progress(iteration, total, prefix='', suffix='', decimals=1, bar_length=50):
    percents = f"{100 * (iteration / float(total)):.{decimals}f}"
    filled_length = int(round(bar_length * iteration / float(total)))
    bar = 'X' * filled_length + ' ' * (bar_length - filled_length)

    print(f'\r{prefix} |{bar}| {percents}% {suffix}', end='', flush=True)

    if iteration == total:
        print()

##################################################################
# Main
##################################################################
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-t', dest='type',    default='uart',                     help='Device type (uart|socket)')
    parser.add_argument('-d', dest='device',  default='/dev/ttyUSB1',             help='Serial Device')
    parser.add_argument('-b', dest='baud',    default=1000000,       type=int,    help='Baud rate')
    parser.add_argument('-o', dest='filename',required=True,                      help='Output filename')
    parser.add_argument('-a', dest='address', default="0",                        help='Address to dump from (default to 0x0)')
    parser.add_argument('-s', dest='size',    required=True,         type=int,    help='Size to dump')
    args = parser.parse_args()

    bus_if = BusInterface(args.type, args.device, args.baud)
    bus_if.set_progress_cb(print_progress)

    addr = int(args.address, 0)
    print(f"Dump: {args.size} bytes from 0x{addr:08x}")

    # Read from target
    data = bus_if.read(addr, args.size)

    # Write to file
    with open(args.filename, mode='wb') as f:
        f.write(data)

if __name__ == "__main__":
   main()
