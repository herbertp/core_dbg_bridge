
from migen import *
from migen.genlib.resetsync import AsyncResetSynchronizer

from litex.gen import *

try:
    from litex_xcku5p import platform
except ImportError:
    import platform

from litex.soc.cores.clock import *
from litex.soc.integration.soc import *
from litex.soc.integration.soc_core import *
from litex.soc.integration.builder import *

from litedram.modules import MT40A512M16
from litedram.phy import usddrphy

# CRG ----------------------------------------------------------------------------------------------

class _CRG(LiteXModule):
    def __init__(self, platform, sys_clk_freq):
        self.rst          = Signal()
        self.cd_sys       = ClockDomain("sys")
        self.cd_sys4x     = ClockDomain("sys4x")
        self.cd_sys4x_dqs = ClockDomain("sys4x_dqs")
        self.cd_ic        = ClockDomain("ic")

        # # #

        # Clock from board
        clk200 = platform.request("clk200")

        self.pll = pll = USMMCM(speedgrade=-2)
        self.comb += pll.reset.eq(self.rst)
        pll.register_clkin(clk200, 200e6)
        pll.create_clkout(self.cd_sys,       sys_clk_freq)
        pll.create_clkout(self.cd_sys4x,     4*sys_clk_freq)
        pll.create_clkout(self.cd_sys4x_dqs, 4*sys_clk_freq, phase=90)

        self.comb += self.cd_ic.clk.eq(self.cd_sys.clk)
        self.comb += self.cd_ic.rst.eq(self.cd_sys.rst)

        # IDelayCtrl
        self.specials += Instance("IDELAYCTRL",
            p_SIM_DEVICE = "ULTRASCALE",
            i_REFCLK     = self.cd_sys4x.clk,
            i_RST        = self.cd_sys4x.rst
        )

# BaseSoC ------------------------------------------------------------------------------------------

class BaseSoC(SoCCore):
    def __init__(self, sys_clk_freq=125e6, **kwargs):
        platform_obj = platform.Platform()

        # SoCCore ----------------------------------------------------------------------------------
        if "cpu_type" not in kwargs:
            kwargs["cpu_type"] = "vexriscv"
        SoCCore.__init__(self, platform_obj, sys_clk_freq,
            ident          = "LiteX SoC on RK-XCKU5P-F",
            **kwargs)

        # CRG --------------------------------------------------------------------------------------
        self.crg = _CRG(platform_obj, sys_clk_freq)

        # DDR4 SDRAM -------------------------------------------------------------------------------
        if not self.integrated_main_ram_size:
            self.ddrphy = usddrphy.USPDDRPHY(platform_obj.request("ddr4"),
                memtype          = "DDR4",
                sys_clk_freq     = sys_clk_freq,
                iodelay_clk_freq = 4*sys_clk_freq) # Match sys4x
            self.add_sdram("sdram",
                phy           = self.ddrphy,
                module        = MT40A512M16(sys_clk_freq, "1:4"),
                size          = 0x40000000, # 1GB (aligned with 0x40000000 default origin)
                l2_cache_size = kwargs.get("l2_size", 8192)
            )

    def do_finalize(self):
        SoCCore.do_finalize(self)
        # Add Tcl constraint to ensure all IDELAYCTRL (including replicated ones) have correct SIM_DEVICE
        self.platform.add_platform_command("set_property SIM_DEVICE ULTRASCALE [get_cells -hierarchical -filter {{REF_NAME == IDELAYCTRL || ORIG_REF_NAME == IDELAYCTRL}}]")

# Build --------------------------------------------------------------------------------------------

def main():
    from litex.soc.integration.soc import LiteXSoCArgumentParser
    parser = LiteXSoCArgumentParser(description="LiteX SoC on RK-XCKU5P-F")
    soc_core_args(parser)
    parser.add_argument("--build", action="store_true", help="Build bitstream")
    parser.add_argument("--load",  action="store_true", help="Load bitstream")
    parser.add_argument("--sys-clk-freq", default=125e6, type=float, help="System clock frequency")

    parser.set_defaults(bus_standard="axi")
    parser.set_defaults(uart_name="serial")
    parser.set_defaults(uart_baudrate=115200)
    parser.set_defaults(integrated_rom_size=0x10000)

    args = parser.parse_args()

    # Workaround for LiteX 2024.12 CSR name extraction bug in sandbox
    from litex.soc.interconnect import csr
    _old_CSRBase_init = csr._CSRBase.__init__
    def _new_CSRBase_init(self, size, name=None, n=None):
        if name is None: name = "unnamed"
        _old_CSRBase_init(self, size, name, n)
    csr._CSRBase.__init__ = _new_CSRBase_init

    soc = BaseSoC(
        sys_clk_freq = args.sys_clk_freq,
        **soc_core_argdict(args)
    )

    builder = Builder(soc, csr_csv="csr.csv", compile_software=True)
    if args.build:
        builder.build(build_name="rk_xcku5p")
    else:
        builder.build(run=False)

    if args.load:
        prog = soc.platform.create_programmer()
        prog.load_bitstream(builder.get_bitstream_filename(mode="sram"))

if __name__ == "__main__":
    main()
