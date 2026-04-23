
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
from litex.soc.cores.led import LedChaser
from litex.soc.cores.gpio import GPIOIn
from litex.soc.interconnect import stream

from litedram.modules import MT40A512M16
from litedram.phy import usddrphy
from litedram.frontend.dma import LiteDRAMDMAReader, LiteDRAMDMAWriter

from functools import reduce
from operator import xor, and_, or_

# DMA ----------------------------------------------------------------------------------------------

class MemCopyDMA(LiteXModule):
    def __init__(self, reader_port, writer_port):
        self.source = CSRStorage(32, name="source", description="Source address (256-bit word aligned)")
        self.dest   = CSRStorage(32, name="dest", description="Destination address (256-bit word aligned)")
        self.length = CSRStorage(32, name="length", description="Transfer length in 256-bit beats")
        self.ctl    = CSRStorage(name="ctl", fields=[
            CSRField("start", size=1, pulse=True, description="Start DMA transfer"),
        ])
        self.busy   = CSRStatus(name="busy", description="DMA transfer in progress")

        # # #

        # Readers / Writers
        self.reader = reader = LiteDRAMDMAReader(reader_port, fifo_depth=32)
        self.writer = writer = LiteDRAMDMAWriter(writer_port, fifo_depth=32)

        # Internal Registers
        src_addr  = Signal(32)
        dst_addr  = Signal(32)
        remaining = Signal(32)

        # Visualization signals
        self.data_xor = Signal(256)
        self.data_and = Signal(256)
        self.data_or  = Signal(256)

        # Control FSM
        self.fsm = fsm = FSM(reset_state="IDLE")
        fsm.act("IDLE",
            If(self.ctl.fields.start & (self.length.storage != 0),
                NextValue(src_addr,  self.source.storage),
                NextValue(dst_addr,  self.dest.storage),
                NextValue(remaining, self.length.storage),
                NextState("TRANSFER")
            )
        )
        fsm.act("TRANSFER",
            self.busy.status.eq(1),

            # Reader Sink (Address)
            If(remaining != 0,
                reader.sink.valid.eq(1),
                reader.sink.address.eq(src_addr),
                If(reader.sink.ready,
                    NextValue(src_addr, src_addr + 1),
                    NextValue(remaining, remaining - 1)
                )
            ),

            # Data Path & Writer Sink
            # Connect Reader Source to Writer Sink (including address)
            reader.source.connect(writer.sink, omit={"address"}),
            writer.sink.address.eq(dst_addr),

            # Increment Writer Address
            If(writer.sink.valid & writer.sink.ready,
                NextValue(dst_addr, dst_addr + 1),
            ),

            # Termination
            If((remaining == 0) & (writer.sink.valid == 0),
                NextState("FINISH")
            )
        )

        # Beat counters to ensure all data is written
        beats_written = Signal(32)

        self.sync += [
            If(fsm.ongoing("IDLE"),
                beats_written.eq(0)
            ).Elif(fsm.ongoing("TRANSFER"),
                If(writer.sink.valid & writer.sink.ready,
                    beats_written.eq(beats_written + 1),
                    # Visualization capture
                    self.data_xor.eq(writer.sink.data),
                    self.data_and.eq(writer.sink.data),
                    self.data_or.eq(writer.sink.data),
                )
            )
        ]

        fsm.act("FINISH",
            self.busy.status.eq(1),
            If(beats_written == self.length.storage,
                NextState("IDLE")
            )
        )

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

        # Force main ram at 0x00000000 for backwards compatibility
        kwargs["integrated_main_ram_size"] = 0 # Ensure we use LiteDRAM
        SoCCore.mem_map["main_ram"] = 0x00000000
        SoCCore.mem_map["sram"]     = 0x80000000 # Move SRAM out of the way
        SoCCore.mem_map["csr"]      = 0xf0000000 # Move CSR out of the way

        # SoCCore ----------------------------------------------------------------------------------
        SoCCore.__init__(self, platform_obj, sys_clk_freq,
            cpu_type       = None, # Force no CPU
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
                size          = 0x80000000, # 2GB
                l2_cache_size = kwargs.get("l2_size", 8192)
            )

        # Leds -------------------------------------------------------------------------------------
        user_leds = platform_obj.request_all("user_led")
        chaser_leds = Signal(len(user_leds))
        self.leds = LedChaser(
            pads         = chaser_leds,
            sys_clk_freq = sys_clk_freq)

        # Buttons ----------------------------------------------------------------------------------
        self.buttons = GPIOIn(
            pads         = platform_obj.request_all("user_btn"))

        # DMA --------------------------------------------------------------------------------------
        self.memcopy = MemCopyDMA(
            reader_port = self.sdram.crossbar.get_port(data_width=256),
            writer_port = self.sdram.crossbar.get_port(data_width=256),
        )

        # LED Visualization ------------------------------------------------------------------------
        dma_leds = Signal(4)
        self.comb += [
            dma_leds[0].eq(self.memcopy.busy.status),
            dma_leds[1].eq(reduce(xor, self.memcopy.data_xor)),
            dma_leds[2].eq(reduce(and_, self.memcopy.data_and)),
            dma_leds[3].eq(reduce(or_, self.memcopy.data_or)),
        ]
        for i in range(len(user_leds)):
            if i < 4:
                self.comb += user_leds[i].eq(Mux(self.memcopy.busy.status, dma_leds[i], chaser_leds[i]))
            else:
                self.comb += user_leds[i].eq(chaser_leds[i])

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
    parser.set_defaults(uart_name="uartbone")
    parser.set_defaults(uart_baudrate=4000000)
    parser.set_defaults(integrated_rom_size=0)

    args = parser.parse_args()

    # Workaround for LiteX 2024.12 CSR name extraction bug in sandbox
    from litex.soc.interconnect import csr
    _old_CSRBase_init = csr._CSRBase.__init__
    def _new_CSRBase_init(self, size, name=None, n=None):
        if name is None: name = "unnamed"
        _old_CSRBase_init(self, size, name, n)
    csr._CSRBase.__init__ = _new_CSRBase_init

    # Final check: remove cpu_type from soc_core_argdict to avoid double passing
    kwargs = soc_core_argdict(args)
    if "cpu_type" in kwargs:
        del kwargs["cpu_type"]

    soc = BaseSoC(
        sys_clk_freq = args.sys_clk_freq,
        **kwargs
    )

    builder = Builder(soc, csr_csv="csr.csv", compile_software=False)
    if args.build:
        builder.build(build_name="rk_xcku5p")
    else:
        builder.build(run=False)

    if args.load:
        prog = soc.platform.create_programmer()
        prog.load_bitstream(builder.get_bitstream_filename(mode="sram"))

if __name__ == "__main__":
    main()
