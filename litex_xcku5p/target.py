
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
from litex.soc.interconnect import axi, stream

from litedram.modules import MT40A512M16
from litedram.phy import usddrphy
from litedram.frontend.axi import LiteDRAMAXI2Native

# Monkeypatch VexRiscv to support caching for ROM/SRAM at high addresses ---------------------------
from litex.soc.cores.cpu.vexriscv import VexRiscv
VexRiscv.io_regions = {0xf0000000: 0x10000000} # Only CSRs are uncached

# AXI CDC Helper -----------------------------------------------------------------------------------

class AXIClockDomainCrossing(LiteXModule):
    def __init__(self, master, slave, cd_from, cd_to):
        for channel in ["aw", "w", "b", "ar", "r"]:
            m_chan = getattr(master, channel)
            s_chan = getattr(slave, channel)
            layout = m_chan.description
            if channel in ["b", "r"]:
                cdc = stream.ClockDomainCrossing(layout, cd_to, cd_from)
                self.submodules += cdc
                self.comb += [
                    s_chan.connect(cdc.sink),
                    cdc.source.connect(m_chan)
                ]
            else:
                cdc = stream.ClockDomainCrossing(layout, cd_from, cd_to)
                self.submodules += cdc
                self.comb += [
                    m_chan.connect(cdc.sink),
                    cdc.source.connect(s_chan)
                ]

# CRG ----------------------------------------------------------------------------------------------

class _CRG(LiteXModule):
    def __init__(self, platform, sys_clk_freq):
        self.rst          = Signal()
        self.cd_sys       = ClockDomain("sys")    # 150MHz (Main SoC / CPU)
        self.cd_dram      = ClockDomain("dram")   # 300MHz (DDR4 Controller)
        self.cd_dram4x    = ClockDomain("dram4x") # 1200MHz (DDR4 PHY)
        self.cd_dram4x_dqs= ClockDomain("dram4x_dqs")
        self.cd_ic        = ClockDomain("ic")

        # # #

        # Clock from board (200MHz Differential)
        clk200 = platform.request("clk200")
        clk200_se = Signal()
        self.specials += Instance("IBUFDS",
            i_I  = clk200.p,
            i_IB = clk200.n,
            o_O  = clk200_se
        )

        self.pll = pll = USMMCM(speedgrade=-2)
        self.comb += pll.reset.eq(self.rst)
        pll.register_clkin(clk200_se, 200e6)
        pll.create_clkout(self.cd_sys,        sys_clk_freq)
        pll.create_clkout(self.cd_dram,       2*sys_clk_freq)
        pll.create_clkout(self.cd_dram4x,     8*sys_clk_freq)
        pll.create_clkout(self.cd_dram4x_dqs, 8*sys_clk_freq, phase=90)

        # LiteDRAM UI clock is dram domain
        self.comb += self.cd_ic.clk.eq(self.cd_dram.clk)
        self.comb += self.cd_ic.rst.eq(self.cd_dram.rst)

        # IDelayCtrl
        self.specials += Instance("IDELAYCTRL",
            p_SIM_DEVICE = "ULTRASCALE",
            i_REFCLK     = self.cd_dram.clk, # 300MHz
            i_RST        = self.cd_sys.rst
        )

# BaseSoC ------------------------------------------------------------------------------------------

class BaseSoC(SoCCore):
    def __init__(self, sys_clk_freq=150e6, **kwargs):
        platform_obj = platform.Platform()

        # Re-map memory for 2GB RAM at 0x0
        self.mem_map = {
            "main_ram": 0x00000000,
            "rom":      0x80000000,
            "sram":     0x81000000,
            "csr":      0xf0000000,
            "vexriscv_debug": 0xf00f0000,
        }

        # SoCCore ----------------------------------------------------------------------------------
        kwargs["cpu_type"] = "None" # Avoid standard CPU integration to control mapping
        kwargs["integrated_rom_size"] = 0
        kwargs["integrated_sram_size"] = 0
        kwargs["integrated_main_ram_size"] = 0
        if "uart_baudrate" not in kwargs:
            kwargs["uart_baudrate"] = 115200
        SoCCore.__init__(self, platform_obj, sys_clk_freq,
            ident          = "LiteX SoC on RK-XCKU5P-F (2400MT/s)",
            **kwargs)

        # CRG --------------------------------------------------------------------------------------
        self.crg = _CRG(platform_obj, sys_clk_freq)

        # CPU --------------------------------------------------------------------------------------
        self.cpu = VexRiscv(platform_obj, variant="standard")
        self.cpu.set_reset_address(self.mem_map["rom"])
        self.comb += self.cpu.interrupt.eq(0)
        if hasattr(self, "ctrl"):
            self.comb += self.cpu.reset.eq(self.ctrl.soc_rst | self.ctrl.cpu_rst)

        # Add CPU buses to SoC
        buses = getattr(self.cpu, "buses", self.cpu.periph_buses)
        for i, bus in enumerate(buses):
            self.bus.add_master(name=f"cpu_bus{i}", master=bus)

        # Add CPU constants for software
        self.add_config("CPU_TYPE_VEXRISCV", check_duplicate=False)
        self.add_config("CPU_VARIANT_STANDARD", check_duplicate=False)
        self.add_config("CPU_FAMILY", "riscv", check_duplicate=False)
        self.add_config("CPU_NAME", "vexriscv", check_duplicate=False)
        self.add_config("CPU_HUMAN_NAME", "VexRiscv", check_duplicate=False)
        self.add_config("CPU_NOP", "nop", check_duplicate=False)
        self.add_config("CPU_RESET_ADDR", self.mem_map["rom"], check_duplicate=False)
        self.add_config("CPU_HAS_ICACHE", check_duplicate=False)
        self.add_config("CPU_HAS_DCACHE", check_duplicate=False)

        # ROM / SRAM -------------------------------------------------------------------------------
        self.add_rom("rom",  self.mem_map["rom"],  0x10000)
        self.add_ram("sram", self.mem_map["sram"], 0x2000)

        # DDR4 -------------------------------------------------------------------------------------
        self.ddrphy = ClockDomainsRenamer({
            "sys": "dram",
            "sys4x": "dram4x",
            "sys4x_dqs": "dram4x_dqs"
        })(usddrphy.USPDDRPHY(platform_obj.request("ddr4"),
            memtype          = "DDR4",
            sys_clk_freq     = 2*sys_clk_freq, # 300MHz
            iodelay_clk_freq = 2*sys_clk_freq)) # 300MHz

        self.add_sdram("sdram",
            phy           = self.ddrphy,
            module        = MT40A512M16(2*sys_clk_freq, "1:4"),
            size          = 0x80000000, # 2GB
            with_soc_interconnect = False # Manual connection with CDC
        )
        # Rename SDRAM clock domains
        self.sdram = ClockDomainsRenamer("dram")(self.sdram)

        # Connect SDRAM to SoC Bus with CDC
        # 1. Request a 256-bit AXI port from SDRAM (in dram domain)
        dram_axi = axi.AXIInterface(data_width=256, address_width=32, id_width=4, clock_domain="dram")
        self.submodules += ClockDomainsRenamer("dram")(LiteDRAMAXI2Native(
            axi          = dram_axi,
            port         = self.sdram.crossbar.get_port(data_width=256),
            base_address = self.mem_map["main_ram"]
        ))

        # 2. Create a matching AXI interface in sys domain
        soc_axi_dram = axi.AXIInterface(data_width=256, address_width=32, id_width=4, clock_domain="sys")

        # 3. Add CDC
        self.submodules += AXIClockDomainCrossing(soc_axi_dram, dram_axi, cd_from="sys", cd_to="dram")

        # 4. Add to SoC bus
        self.bus.add_slave("main_ram", soc_axi_dram, region=SoCRegion(origin=self.mem_map["main_ram"], size=0x80000000))

    def finalize(self):
        # Workaround for empty IRQ locs when cpu is manually instantiated
        if self.irq.locs == {}:
            self.irq.locs["empty"] = 0
        SoCCore.finalize(self)

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
    parser.add_argument("--sys-clk-freq", default=150e6, type=float, help="System (CPU) clock frequency")

    parser.set_defaults(bus_standard="axi")
    parser.set_defaults(uart_name="serial")

    args = parser.parse_args()

    # Workaround for LiteX 2024.12 CSR name extraction bug in sandbox
    from litex.soc.interconnect import csr
    _old_CSRBase_init = csr._CSRBase.__init__
    _unnamed_count = 0
    def _new_CSRBase_init(self, size, name=None, n=None):
        nonlocal _unnamed_count
        if name is None:
            import sys
            import inspect
            frame = sys._getframe(1)
            while frame:
                for key, value in frame.f_locals.items():
                    if value is self:
                        name = key
                        break
                if name: break
                frame = frame.f_back
        if name is None:
            name = f"unnamed{_unnamed_count}"
            _unnamed_count += 1
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
