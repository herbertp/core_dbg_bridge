#!/usr/bin/env python3

import sys
import os
import time
import struct
import argparse
import json
import re
from typing import List, Optional, Dict

# Add sw/ to path for bus_interface
sys.path.append(os.path.join(os.path.dirname(__file__), "."))
from litex_bus_interface import LiteXBusInterface

# Constants from liblitedram
DFII_CONTROL_SEL      = 0x01
DFII_CONTROL_CKE      = 0x02
DFII_CONTROL_ODT      = 0x04
DFII_CONTROL_RESET_N  = 0x08

DFII_COMMAND_CS       = 0x01
DFII_COMMAND_WE       = 0x02
DFII_COMMAND_CAS      = 0x04
DFII_COMMAND_RAS      = 0x08
DFII_COMMAND_WRDATA   = 0x10
DFII_COMMAND_RDDATA   = 0x20

class DRAMTrainer:
    def __init__(self, interface: str, baud: int, csr_csv: str):
        self.bus = LiteXBusInterface(interface, baud, csr_csv)
        self.regs = None
        self.constants: Dict[str, str] = {}
        self.csr_csv = csr_csv
        self.rdphase = 0
        self.wrphase = 0
        self.num_modules = 4
        self.dfi_bytes = 8

    def load_config(self):
        with open(self.csr_csv, 'r') as f:
            for line in f:
                if line.startswith('constant,'):
                    parts = line.split(',')
                    self.constants[parts[1]] = parts[2]

        bus_width = int(self.constants.get('config_bus_data_width', 32))
        # For DDR4 on US+ it's usually 8 bits per DQS/Module
        self.num_modules = bus_width // 8
        # DFI data width is 2x bus width (Rise/Fall)
        self.dfi_bytes = (bus_width * 2) // 8
        print(f"Configured for {bus_width}-bit bus, {self.num_modules} modules, {self.dfi_bytes} DFI bytes/phase")

    def connect(self):
        self.bus.connect()
        self.regs = self.bus.client.regs
        self.load_config()

    def software_control_on(self):
        print("Switching to Software Control...")
        # Start with everything low
        self.regs.sdram_dfii_control.write(0)
        time.sleep(0.01)
        # RESET_N high
        self.regs.sdram_dfii_control.write(DFII_CONTROL_RESET_N)
        time.sleep(0.01)
        # CKE and ODT high
        self.regs.sdram_dfii_control.write(DFII_CONTROL_CKE | DFII_CONTROL_ODT | DFII_CONTROL_RESET_N)
        time.sleep(0.01)

        # Disable VTC (Voltage/Temperature Compensation) during training
        if hasattr(self.regs, "ddrphy_en_vtc"):
            self.regs.ddrphy_en_vtc.write(0)

    def software_control_off(self):
        print("Switching to Hardware Control...")
        self.regs.sdram_dfii_control.write(DFII_CONTROL_SEL)
        if hasattr(self.regs, "ddrphy_en_vtc"):
            self.regs.ddrphy_en_vtc.write(1)

    def mode_register_write(self, reg: int, value: int):
        self.regs.sdram_dfii_pi0_address.write(value)
        self.regs.sdram_dfii_pi0_baddress.write(reg)
        self.regs.sdram_dfii_pi0_command.write(DFII_COMMAND_RAS | DFII_COMMAND_CAS | DFII_COMMAND_WE | DFII_COMMAND_CS)
        self.regs.sdram_dfii_pi0_command_issue.write(1)

    def init_ddr4(self):
        print("Initializing DDR4...")
        # MR0: RL=10, BL8, DLL Reset
        self.mode_register_write(0, 0x420)
        # MR1: DLL Enable, RTT_NOM=RZQ/6
        self.mode_register_write(1, 0x001)
        # MR2: CWL=9
        self.mode_register_write(2, 0x000)
        # ZQ Calibration Long
        self.regs.sdram_dfii_pi0_address.write(0x400) # A10=1
        self.regs.sdram_dfii_pi0_command.write(DFII_COMMAND_WE | DFII_COMMAND_CS)
        self.regs.sdram_dfii_pi0_command_issue.write(1)
        time.sleep(0.01)

    def lfsr(self, bits: int, prev: int) -> int:
        taps = {32: 0x80200003}
        lsb = prev & 1
        prev >>= 1
        if lsb:
            prev ^= taps[bits]
        return prev & 0xFFFFFFFF

    def get_test_pattern(self, seed: int, phases: int, bytes_per_phase: int) -> List[bytearray]:
        pattern = []
        prv = seed
        for p in range(phases):
            phase_data = bytearray()
            for i in range(bytes_per_phase):
                val = 0
                for bit in range(8):
                    prv = self.lfsr(32, prv)
                    val |= (prv & 1) << bit
                phase_data.append(val)
            pattern.append(phase_data)
        return pattern

    def write_read_check_test_pattern(self, module: int, seed: int) -> int:
        pattern = self.get_test_pattern(seed, SDRAM_PHY_PHASES, self.dfi_bytes)

        # Activate
        self.regs.sdram_dfii_pi0_address.write(0)
        self.regs.sdram_dfii_pi0_baddress.write(0)
        self.regs.sdram_dfii_pi0_command.write(DFII_COMMAND_RAS | DFII_COMMAND_CS)
        self.regs.sdram_dfii_pi0_command_issue.write(1)

        # Write Data
        for p in range(SDRAM_PHY_PHASES):
            val = struct.unpack("<Q", pattern[p])[0] if self.dfi_bytes == 8 else struct.unpack("<I", pattern[p])[0]
            getattr(self.regs, f"sdram_dfii_pi{p}_wrdata").write(val)

        # Write Command
        getattr(self.regs, f"sdram_dfii_pi{self.wrphase}_command").write(DFII_COMMAND_CAS | DFII_COMMAND_WE | DFII_COMMAND_CS | DFII_COMMAND_WRDATA)
        getattr(self.regs, f"sdram_dfii_pi{self.wrphase}_command_issue").write(1)

        # Read Command
        getattr(self.regs, f"sdram_dfii_pi{self.rdphase}_command").write(DFII_COMMAND_CAS | DFII_COMMAND_CS | DFII_COMMAND_RDDATA)
        getattr(self.regs, f"sdram_dfii_pi{self.rdphase}_command_issue").write(1)

        # Precharge
        self.regs.sdram_dfii_pi0_address.write(0x400)
        self.regs.sdram_dfii_pi0_command.write(DFII_COMMAND_RAS | DFII_COMMAND_WE | DFII_COMMAND_CS)
        self.regs.sdram_dfii_pi0_command_issue.write(1)

        errors = 0
        for p in range(SDRAM_PHY_PHASES):
            read_val = getattr(self.regs, f"sdram_dfii_pi{p}_rddata").read()
            read_bytes = struct.pack("<Q", read_val) if self.dfi_bytes == 8 else struct.pack("<I", read_val)

            # Module m: Rise is byte m. Fall is byte (dfi_bytes/2) + m.
            m_rise = module
            m_fall = (self.dfi_bytes // 2) + module

            errors += bin(pattern[p][m_rise] ^ read_bytes[m_rise]).count('1')
            errors += bin(pattern[p][m_fall] ^ read_bytes[m_fall]).count('1')

        return errors

    def read_leveling(self):
        print("Read leveling...")
        self.rdphase = self.regs.ddrphy_rdphase.read()
        self.wrphase = self.regs.ddrphy_wrphase.read()
        print(f"  PHY phases: RD={self.rdphase}, WR={self.wrphase}")

        results = []
        for m in range(self.num_modules):
            print(f"  Module {m}: ", end="")
            best_bitslip = -1
            best_delay = -1
            max_window = 0

            for b in range(SDRAM_PHY_BITSLIPS):
                # Set bitslip
                self.regs.ddrphy_dly_sel.write(1 << m)
                self.regs.ddrphy_rdly_dq_bitslip_rst.write(1)
                for _ in range(b):
                    self.regs.ddrphy_rdly_dq_bitslip.write(1)

                # Scan delays
                working_ranges = []
                current_start = -1

                self.regs.ddrphy_rdly_dq_rst.write(1)
                for d in range(512): # US+ has 512 taps
                    if self.write_read_check_test_pattern(m, 42) == 0:
                        if current_start == -1:
                            current_start = d
                    else:
                        if current_start != -1:
                            working_ranges.append((current_start, d - 1))
                            current_start = -1
                    self.regs.ddrphy_rdly_dq_inc.write(1)

                if current_start != -1:
                    working_ranges.append((current_start, 511))

                # Find largest range for this bitslip
                for start, end in working_ranges:
                    window = end - start
                    if window > max_window:
                        # Verify with more seeds at the center
                        self.regs.ddrphy_rdly_dq_rst.write(1)
                        for _ in range((start + end) // 2):
                            self.regs.ddrphy_rdly_dq_inc.write(1)

                        full_verify = True
                        for seed in [84, 123, 456]:
                            if self.write_read_check_test_pattern(m, seed) != 0:
                                full_verify = False
                                break

                        if full_verify:
                            max_window = window
                            best_bitslip = b
                            best_delay = (start + end) // 2

                sys.stdout.write(".")
                sys.stdout.flush()

            sys.stdout.write("\n")
            if best_bitslip != -1:
                print(f"    RESULT: Bitslip {best_bitslip}, Delay {best_delay} (window {max_window})")
                results.append({"module": m, "bitslip": best_bitslip, "delay": best_delay})
                # Apply result
                self.regs.ddrphy_dly_sel.write(1 << m)
                self.regs.ddrphy_rdly_dq_bitslip_rst.write(1)
                for _ in range(best_bitslip):
                    self.regs.ddrphy_rdly_dq_bitslip.write(1)
                self.regs.ddrphy_rdly_dq_rst.write(1)
                for _ in range(best_delay):
                    self.regs.ddrphy_rdly_dq_inc.write(1)
            else:
                print(f"    ERROR: Module {m} training failed!")
                results.append({"module": m, "bitslip": 0, "delay": 0})

        return results

    def memtest(self, origin: int = 0x00000000, size: int = 0x10000) -> bool:
        print(f"Running Memtest at 0x{origin:08x} (size 0x{size:x})...")
        patterns = [0x55AA55AA, 0x12345678, 0x00000000, 0xFFFFFFFF]

        for pattern in patterns:
            print(f"  Pattern 0x{pattern:08x}...", end="")
            sys.stdout.flush()
            # Write
            for i in range(0, size, 4):
                self.bus.write32(origin + i, (pattern ^ i) & 0xFFFFFFFF)

            # Read back and verify
            errors = 0
            for i in range(0, size, 4):
                val = self.bus.read32(origin + i)
                if val != ((pattern ^ i) & 0xFFFFFFFF):
                    errors += 1
                    if errors < 5:
                        print(f"\n    Error at 0x{origin+i:08x}: read 0x{val:08x}, expected 0x{(pattern^i)&0xFFFFFFFF:08x}")

            if errors == 0:
                print(" OK")
            else:
                print(f" FAILED ({errors} errors)")
                return False

        # Test DMA if available
        if hasattr(self.regs, "memcopy_source"):
            print("  Testing DMA Memcopy...")
            src = origin
            dst = origin + size
            length_beats = size // 32 # 256-bit beats

            # Fill source
            for i in range(0, size, 4):
                self.bus.write32(src + i, (0xDEADBEEF ^ i) & 0xFFFFFFFF)
            # Clear destination
            for i in range(0, size, 4):
                self.bus.write32(dst + i, 0)

            # Start DMA
            self.regs.memcopy_source.write(src // 32)
            self.regs.memcopy_dest.write(dst // 32)
            self.regs.memcopy_length.write(length_beats)
            self.regs.memcopy_ctl.write(1) # start

            # Wait for DMA
            timeout = 100
            while self.regs.memcopy_busy.read() and timeout > 0:
                time.sleep(0.01)
                timeout -= 1

            if timeout == 0:
                print("    DMA Timeout!")
                return False

            # Verify destination
            errors = 0
            for i in range(0, size, 4):
                val = self.bus.read32(dst + i)
                if val != ((0xDEADBEEF ^ i) & 0xFFFFFFFF):
                    errors += 1

            if errors == 0:
                print("    DMA OK")
            else:
                print(f"    DMA FAILED ({errors} errors)")
                return False

        print("  All Memtests PASSED")
        return True

    def train(self):
        self.connect()
        self.software_control_on()

        # Reset PHY
        self.regs.ddrphy_rst.write(1)
        time.sleep(0.01)
        self.regs.ddrphy_rst.write(0)
        time.sleep(0.01)

        self.init_ddr4()
        results = self.read_leveling()

        self.software_control_off()

        if self.memtest():
            print("\nTraining successful!")
            print("\nSane defaults for target.py BaseSoC (add to do_finalize):")
            print("-" * 40)
            print("    def do_finalize(self):")
            print("        SoCCore.do_finalize(self)")
            print("        ...")
            print("        # Sane Defaults from sw/dram_training.py")
            print("        dram_settings = {")
            for res in results:
                print(f"            {res['module']}: {{'bitslip': {res['bitslip']}, 'delay': {res['delay']}}},")
            print("        }")
            print("        for m, settings in dram_settings.items():")
            print("            self.comb += [")
            print("                self.ddrphy._dly_sel.storage.eq(1 << m),")
            print("                self.ddrphy._rdly_dq_bitslip_rst.re.eq(1),")
            print("                self.ddrphy._rdly_dq_rst.re.eq(1),")
            print("            ]")
            print("            for _ in range(settings['bitslip']):")
            print("                self.comb += self.ddrphy._rdly_dq_bitslip.re.eq(1)")
            print("            for _ in range(settings['delay']):")
            print("                self.comb += self.ddrphy._rdly_dq_inc.re.eq(1)")

            print("\nAlternatively, save to dram_settings.json and load in target.py:")
            with open("dram_settings.json", "w") as f:
                json.dump(results, f, indent=4)
            print("dram_settings.json has been created.")
        else:
            print("\nTraining FAILED Verification!")

def main():
    parser = argparse.ArgumentParser(description="DDR4 Remote Training Script")
    parser.add_argument("-d", "--device", default="/dev/ttyUSB1", help="Serial device")
    parser.add_argument("-b", "--baud", type=int, default=115200, help="Baud rate")
    parser.add_argument("-c", "--csr", default="csr.csv", help="CSR CSV file")
    args = parser.parse_args()

    csr_path = args.csr
    if not os.path.exists(csr_path):
        alt_path = os.path.join("litex_xcku5p", args.csr)
        if os.path.exists(alt_path):
            csr_path = alt_path

    trainer = DRAMTrainer(args.device, args.baud, csr_path)
    trainer.train()

if __name__ == "__main__":
    main()
