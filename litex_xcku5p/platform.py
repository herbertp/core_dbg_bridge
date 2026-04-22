
from litex.build.generic_platform import *
from litex.build.xilinx import XilinxPlatform

# RK-XCKU5P-F Resources ----------------------------------------------------------------------------

_io = [
    # 200MHz System Clock
    ("clk200", 0,
        Subsignal("p", Pins("T24"), IOStandard("DIFF_SSTL12")),
        Subsignal("n", Pins("U24"), IOStandard("DIFF_SSTL12"))
    ),

    # Debug UART
    ("serial", 0,
        Subsignal("rx", Pins("AD13")),
        Subsignal("tx", Pins("AC14")),
        IOStandard("LVCMOS33")
    ),

    # User LEDs
    ("user_led", 0, Pins("H9"),  IOStandard("LVCMOS33")),
    ("user_led", 1, Pins("J9"),  IOStandard("LVCMOS33")),
    ("user_led", 2, Pins("G11"), IOStandard("LVCMOS33")),
    ("user_led", 3, Pins("H11"), IOStandard("LVCMOS33")),

    # User Buttons (Active Low)
    ("user_btn", 0, Pins("K9"),  IOStandard("LVCMOS33")),
    ("user_btn", 1, Pins("K10"), IOStandard("LVCMOS33")),
    ("user_btn", 2, Pins("J10"), IOStandard("LVCMOS33")),
    ("user_btn", 3, Pins("J11"), IOStandard("LVCMOS33")),

    # DDR4 Memory
    ("ddr4", 0,
        Subsignal("a",       Pins(
            "Y22 Y25 W23 V26 R26 U26 R21 W25",
            "R20 Y26 R25 V23 AA24 W26"),
            IOStandard("SSTL12_DCI")),
        Subsignal("ba",      Pins("P21 P26"), IOStandard("SSTL12_DCI")),
        Subsignal("bg",      Pins("R22"), IOStandard("SSTL12_DCI")),
        Subsignal("ras_n",   Pins("T25"), IOStandard("SSTL12_DCI")), # A16
        Subsignal("cas_n",   Pins("AA25"), IOStandard("SSTL12_DCI")), # A15
        Subsignal("we_n",    Pins("P23"), IOStandard("SSTL12_DCI")), # A14
        Subsignal("act_n",   Pins("P24"), IOStandard("SSTL12_DCI")),
        Subsignal("cs_n",    Pins("P25"), IOStandard("SSTL12_DCI")),
        Subsignal("dm",      Pins("AE25 AE22 AD20 Y20"), IOStandard("POD12_DCI")),
        Subsignal("dq",      Pins(
            "AF24 AF25 AD24 AB26 AC24 AB25 AD25 AB24",
            "AC21 AD23 AD21 AC22 AB21 AE23 AE21 AC23",
            "AE16 AD19 AD16 AF17 AC19 AF19 AF18 AE17",
            "AA20 AA18 AA19 Y18  AB20 Y17  AB19 AA17"),
            IOStandard("POD12_DCI"),
            Misc("OUTPUT_IMPEDANCE=RDRV_40_40")),
        Subsignal("dqs_p",   Pins("AC26 AA22 AC18 AB17"), IOStandard("DIFF_POD12_DCI")),
        Subsignal("dqs_n",   Pins("AD26 AB22 AD18 AC17"), IOStandard("DIFF_POD12_DCI")),
        Subsignal("clk_p",   Pins("V24"), IOStandard("DIFF_SSTL12_DCI")),
        Subsignal("clk_n",   Pins("W24"), IOStandard("DIFF_SSTL12_DCI")),
        Subsignal("cke",     Pins("P20"), IOStandard("SSTL12_DCI")),
        Subsignal("odt",     Pins("R23"), IOStandard("SSTL12_DCI")),
        Subsignal("reset_n", Pins("P19"), IOStandard("LVCMOS12")),
        Misc("SLEW=FAST"),
    ),
]

# Platform -----------------------------------------------------------------------------------------

class Platform(XilinxPlatform):
    default_clk_name   = "clk200"
    default_clk_period = 1e9/200e6

    def __init__(self, toolchain="vivado"):
        XilinxPlatform.__init__(self, "xcku5p-ffvb676-2-i", _io, toolchain=toolchain)

    def create_programmer(self):
        return VivadoProgrammer()

    def do_finalize(self, fragment):
        XilinxPlatform.do_finalize(self, fragment)
        self.add_period_constraint(self.lookup_request("clk200", loose=True), 1e9/200e6)
