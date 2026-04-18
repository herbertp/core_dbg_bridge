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
    parser.add_argument('-f', dest='filename',required=True,                      help='File to load')
    parser.add_argument('-a', dest='address', default="0",                        help='Address to write to (default to 0x0)')
    parser.add_argument('-s', dest='size',    default=-1,            type=int,    help='Size override')
    parser.add_argument('-v', dest='verify',  default=False, action='store_true', help='Verify write')
    args = parser.parse_args()

    bus_if = BusInterface(args.type, args.device, args.baud)
    bus_if.set_progress_cb(print_progress)

    # Open file
    with open(args.filename, mode='rb') as f:
        data = f.read()

    filesize = len(data)

    # Size override
    if args.size != -1 and filesize > args.size:
        filesize = args.size

    addr = int(args.address, 0)
    print(f"Load: {filesize} bytes to 0x{addr:08x}")

    # Write to target
    bus_if.write(addr, data, filesize)

    # Verification
    if args.verify:
        print("Verify:")
        data_rb = bus_if.read(addr, filesize)

        for i in range(filesize):
            # In Python 3, data[i] is already an int for bytes/bytearray
            exp = data[i] & 0xFF

            if data_rb[i] != exp:
                print(f"Data mismatches @ {addr + i}: {data_rb[i]} != {exp}")
                sys.exit(-1)

        print("Verify: Done")

if __name__ == "__main__":
   main()
