
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
from litex.soc.cores.cpu import vexriscv
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

        # Monkeypatch VexRiscv to use our preferred memory map
        # This is necessary because LiteX CPUs have hardcoded memory maps that override SoC settings.
        # We must override it as a property since it is defined as one in the base class.
        def get_mem_map(self):
            return {
                "rom":            0x80000000,
                "sram":           0x81000000,
                "main_ram":       0x00000000,
                "csr":            0xf0000000,
                "vexriscv_debug": 0xf00f0000,
            }
        vexriscv.VexRiscv.mem_map = property(get_mem_map)
        # Also ensure IO regions are limited to CSRs to allow caching of high-address ROM/SRAM
        vexriscv.VexRiscv.io_regions = {0xf0000000: 0x10000000}

        # Force main ram at 0x00000000 for backwards compatibility
        kwargs["integrated_main_ram_size"] = 0 # Ensure we use LiteDRAM
        SoCCore.mem_map["main_ram"] = 0x00000000
        SoCCore.mem_map["rom"]      = 0x80000000
        SoCCore.mem_map["sram"]     = 0x81000000
        SoCCore.mem_map["csr"]      = 0xf0000000

        # SoCCore ----------------------------------------------------------------------------------
        SoCCore.__init__(self, platform_obj, sys_clk_freq,
            ident          = "LiteX SoC on RK-XCKU5P-F",
            **kwargs)

        # Force main_ram back to 0x00000000 (VexRiscv might have moved it)
        self.mem_map["main_ram"] = 0x00000000

        # Move CPU's reset address to 0x80000000 (ROM)
        if hasattr(self, "cpu") and self.cpu.human_name != "None":
            self.cpu.set_reset_address(self.mem_map["rom"])

        # UART Bridge ------------------------------------------------------------------------------
        if kwargs.get("uart_name") == "crossover":
            self.add_uartbone(baudrate=kwargs.get("uart_baudrate", 4000000))

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

        # Heartbeat LED (LED 0)
        heartbeat = Signal(32)
        self.sync += heartbeat.eq(heartbeat + 1)
        self.comb += user_leds[0].eq(heartbeat[26])

        # DDR4 Training Done (LED 1)
        self.ddr_done = CSRStorage(description="Set to 1 by BIOS when DDR4 training is done")
        self.comb += user_leds[1].eq(self.ddr_done.storage)

        # Bus Activity (LED 2 & 3)
        read_led  = Signal()
        write_led = Signal()
        read_timer  = Signal(32)
        write_timer = Signal(32)

        # Monitor system bus for activity
        bus = getattr(self, "bus", None)
        if bus is not None:
            if hasattr(bus, "ar"): # AXI
                self.sync += [
                    If(bus.ar.valid & bus.ar.ready,
                        read_timer.eq(sys_clk_freq // 10)
                    ).Elif(read_timer != 0,
                        read_timer.eq(read_timer - 1)
                    ),
                    read_led.eq(read_timer != 0),

                    If(bus.aw.valid & bus.aw.ready,
                        write_timer.eq(sys_clk_freq // 10)
                    ).Elif(write_timer != 0,
                        write_timer.eq(write_timer - 1)
                    ),
                    write_led.eq(write_timer != 0),
                ]

        self.comb += [
            user_leds[2].eq(read_led),
            user_leds[3].eq(write_led),
        ]

        # Buttons ----------------------------------------------------------------------------------
        self.buttons = GPIOIn(
            pads         = platform_obj.request_all("user_btn"))

        # DMA --------------------------------------------------------------------------------------
        self.memcopy = MemCopyDMA(
            reader_port = self.sdram.crossbar.get_port(data_width=256),
            writer_port = self.sdram.crossbar.get_port(data_width=256),
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
    parser.set_defaults(uart_name="crossover")
    parser.set_defaults(uart_baudrate=4000000)
    parser.set_defaults(integrated_rom_size=0x10000)
    parser.set_defaults(integrated_sram_size=0x4000)

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

    soc = BaseSoC(
        sys_clk_freq = args.sys_clk_freq,
        **kwargs
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
