----------------------------------------------------------------------------
--  top.vhd
--	XCKU5P simple VHDL example
--	Version 1.4 - DMA and AXI Crossbar (Cleaned)
--
--  Copyright (C) 2026 H.Poetzl
----------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.ALL;

library unisim;
use unisim.VCOMPONENTS.ALL;

entity top is
    port (
	sys_clk_p : IN std_logic;
	sys_clk_n : IN std_logic;
	led : OUT std_logic_vector(0 TO 3);
	key : IN std_logic_vector(0 TO 3);
        uart_rxd_i : in  std_logic;
        uart_txd_o : out std_logic;
        c0_ddr4_act_n          : out   std_logic;
        c0_ddr4_adr            : out   std_logic_vector(16 downto 0);
        c0_ddr4_ba             : out   std_logic_vector(1 downto 0);
        c0_ddr4_bg             : out   std_logic_vector(0 downto 0);
        c0_ddr4_cke            : out   std_logic_vector(0 downto 0);
        c0_ddr4_odt            : out   std_logic_vector(0 downto 0);
        c0_ddr4_cs_n           : out   std_logic_vector(0 downto 0);
        c0_ddr4_ck_t           : out   std_logic_vector(0 downto 0);
        c0_ddr4_ck_c           : out   std_logic_vector(0 downto 0);
        c0_ddr4_reset_n        : out   std_logic;
        c0_ddr4_dm_dbi_n       : inout std_logic_vector(3 downto 0);
        c0_ddr4_dq             : inout std_logic_vector(31 downto 0);
        c0_ddr4_dqs_t          : inout std_logic_vector(3 downto 0);
        c0_ddr4_dqs_c          : inout std_logic_vector(3 downto 0) );
end entity top;

architecture RTL of top is

    signal clk_100 : std_logic;
    signal ui_clk : std_logic;
    signal ui_rst, ui_rst_n : std_logic;
    signal rst_i, rst_100_n : std_logic;
    signal ddr_rst : std_logic;
    signal calib_complete, dma_busy : std_logic;
    signal done_led, done_led_n : std_logic;
    signal clk_cfg, clk_cfgm : std_logic;

    -- Bridge AXI Master (32-bit, 100MHz)
    signal br_awvalid, br_awready, br_wvalid, br_wready, br_wlast : std_logic;
    signal br_awaddr, br_araddr : std_logic_vector(31 downto 0);
    signal br_awid, br_bid, br_arid, br_rid : std_logic_vector(3 downto 0);
    signal br_awlen, br_arlen : std_logic_vector(7 downto 0);
    signal br_awburst, br_arburst, br_bresp, br_rresp : std_logic_vector(1 downto 0);
    signal br_wdata : std_logic_vector(31 downto 0);
    signal br_wstrb : std_logic_vector(3 downto 0);
    signal br_bvalid, br_bready, br_arvalid, br_arready, br_rvalid, br_rready, br_rlast : std_logic;
    signal br_rdata : std_logic_vector(31 downto 0);

    -- Bridge UI Domain (32-bit, UI clk)
    signal br_ui_awvalid, br_ui_awready, br_ui_wvalid, br_ui_wready, br_ui_wlast : std_logic;
    signal br_ui_awaddr, br_ui_araddr : std_logic_vector(31 downto 0);
    signal br_ui_awid, br_ui_bid, br_ui_arid, br_ui_rid : std_logic_vector(3 downto 0);
    signal br_ui_awlen, br_ui_arlen : std_logic_vector(7 downto 0);
    signal br_ui_awburst, br_ui_arburst, br_ui_bresp, br_ui_rresp : std_logic_vector(1 downto 0);
    signal br_ui_wdata : std_logic_vector(31 downto 0);
    signal br_ui_wstrb : std_logic_vector(3 downto 0);
    signal br_ui_bvalid, br_ui_bready, br_ui_arvalid, br_ui_arready, br_ui_rvalid, br_ui_rready, br_ui_rlast : std_logic;
    signal br_ui_rdata : std_logic_vector(31 downto 0);

    -- Bridge DWC Domain (256-bit, UI clk)
    signal br_dwc_awvalid, br_dwc_awready, br_dwc_wvalid, br_dwc_wready, br_dwc_wlast : std_logic;
    signal br_dwc_awaddr, br_dwc_araddr : std_logic_vector(31 downto 0);
    signal br_dwc_awid, br_dwc_bid, br_dwc_arid, br_dwc_rid : std_logic_vector(3 downto 0);
    signal br_dwc_awlen, br_dwc_arlen : std_logic_vector(7 downto 0);
    signal br_dwc_awburst, br_dwc_arburst, br_dwc_bresp, br_dwc_rresp : std_logic_vector(1 downto 0);
    signal br_dwc_wdata, br_dwc_rdata : std_logic_vector(255 downto 0);
    signal br_dwc_wstrb : std_logic_vector(31 downto 0);
    signal br_dwc_bvalid, br_dwc_bready, br_dwc_arvalid, br_dwc_arready, br_dwc_rvalid, br_dwc_rready, br_dwc_rlast : std_logic;

    -- DMA Master (256-bit, UI clk)
    signal dma_m_awvalid, dma_m_awready, dma_m_wvalid, dma_m_wready, dma_m_wlast : std_logic;
    signal dma_m_awaddr, dma_m_araddr : std_logic_vector(31 downto 0);
    signal dma_m_awlen, dma_m_arlen : std_logic_vector(7 downto 0);
    signal dma_m_awburst, dma_m_arburst, dma_m_bresp, dma_m_rresp : std_logic_vector(1 downto 0);
    signal dma_m_wdata, dma_m_rdata : std_logic_vector(255 downto 0);
    signal dma_m_wstrb : std_logic_vector(31 downto 0);
    signal dma_m_bvalid, dma_m_bready, dma_m_arvalid, dma_m_arready, dma_m_rvalid, dma_m_rready, dma_m_rlast : std_logic;

    -- DMA Slave Config (32-bit, UI clk)
    signal dma_s_awvalid, dma_s_awready, dma_s_wvalid, dma_s_wready : std_logic;
    signal dma_s_awaddr, dma_s_araddr : std_logic_vector(3 downto 0);
    signal dma_s_wdata, dma_s_rdata : std_logic_vector(31 downto 0);
    signal dma_s_wstrb : std_logic_vector(3 downto 0);
    signal dma_s_bvalid, dma_s_bready, dma_s_arvalid, dma_s_arready, dma_s_rvalid, dma_s_rready : std_logic;
    signal dma_s_bresp, dma_s_rresp : std_logic_vector(1 downto 0);

    -- Crossbar MI Config Output (256-bit)
    signal xbar_cfg_awvalid, xbar_cfg_awready, xbar_cfg_wvalid, xbar_cfg_wready, xbar_cfg_wlast : std_logic;
    signal xbar_cfg_awaddr, xbar_cfg_araddr : std_logic_vector(31 downto 0);
    signal xbar_cfg_awid, xbar_cfg_bid, xbar_cfg_arid, xbar_cfg_rid : std_logic_vector(3 downto 0);
    signal xbar_cfg_awlen, xbar_cfg_arlen : std_logic_vector(7 downto 0);
    signal xbar_cfg_awburst, xbar_cfg_arburst, xbar_cfg_bresp, xbar_cfg_rresp : std_logic_vector(1 downto 0);
    signal xbar_cfg_wdata, xbar_cfg_rdata : std_logic_vector(255 downto 0);
    signal xbar_cfg_wstrb : std_logic_vector(31 downto 0);
    signal xbar_cfg_bvalid, xbar_cfg_bready, xbar_cfg_arvalid, xbar_cfg_arready, xbar_cfg_rvalid, xbar_cfg_rready, xbar_cfg_rlast : std_logic;

    -- DDR4 Signals
    signal ddr_awvalid, ddr_awready, ddr_wvalid, ddr_wready, ddr_wlast : std_logic;
    signal ddr_awaddr, ddr_araddr : std_logic_vector(30 downto 0);
    signal ddr_awid, ddr_bid, ddr_arid, ddr_rid : std_logic_vector(3 downto 0);
    signal ddr_awlen, ddr_arlen : std_logic_vector(7 downto 0);
    signal ddr_awburst, ddr_arburst, ddr_bresp, ddr_rresp : std_logic_vector(1 downto 0);
    signal ddr_wdata, ddr_rdata : std_logic_vector(255 downto 0);
    signal ddr_wstrb : std_logic_vector(31 downto 0);
    signal ddr_bvalid, ddr_bready, ddr_arvalid, ddr_arready, ddr_rvalid, ddr_rready, ddr_rlast : std_logic;

    -- Crossbar Aggregation Vectors
    signal s_awid, s_awaddr, s_awlen, s_awsize, s_awburst, s_awlock, s_awcache, s_awprot, s_awqos, s_awvalid, s_awready : std_logic_vector(1 downto 0); -- wrong sizes, fixing below
    signal s_v_awid : std_logic_vector(7 downto 0);
    signal s_v_awaddr : std_logic_vector(63 downto 0);
    signal s_v_awlen : std_logic_vector(15 downto 0);
    signal s_v_awsize : std_logic_vector(5 downto 0);
    signal s_v_awburst : std_logic_vector(3 downto 0);
    signal s_v_awlock : std_logic_vector(1 downto 0);
    signal s_v_awcache : std_logic_vector(7 downto 0);
    signal s_v_awprot : std_logic_vector(5 downto 0);
    signal s_v_awqos : std_logic_vector(7 downto 0);
    signal s_v_awvalid : std_logic_vector(1 downto 0);
    signal s_v_awready : std_logic_vector(1 downto 0);
    signal s_v_wdata : std_logic_vector(511 downto 0);
    signal s_v_wstrb : std_logic_vector(63 downto 0);
    signal s_v_wlast : std_logic_vector(1 downto 0);
    signal s_v_wvalid : std_logic_vector(1 downto 0);
    signal s_v_wready : std_logic_vector(1 downto 0);
    signal s_v_bid : std_logic_vector(7 downto 0);
    signal s_v_bresp : std_logic_vector(3 downto 0);
    signal s_v_bvalid : std_logic_vector(1 downto 0);
    signal s_v_bready : std_logic_vector(1 downto 0);
    signal s_v_arid : std_logic_vector(7 downto 0);
    signal s_v_araddr : std_logic_vector(63 downto 0);
    signal s_v_arlen : std_logic_vector(15 downto 0);
    signal s_v_arsize : std_logic_vector(5 downto 0);
    signal s_v_arburst : std_logic_vector(3 downto 0);
    signal s_v_arlock : std_logic_vector(1 downto 0);
    signal s_v_arcache : std_logic_vector(7 downto 0);
    signal s_v_arprot : std_logic_vector(5 downto 0);
    signal s_v_arqos : std_logic_vector(7 downto 0);
    signal s_v_arvalid : std_logic_vector(1 downto 0);
    signal s_v_arready : std_logic_vector(1 downto 0);
    signal s_v_rid : std_logic_vector(7 downto 0);
    signal s_v_rdata : std_logic_vector(511 downto 0);
    signal s_v_rresp : std_logic_vector(3 downto 0);
    signal s_v_rlast : std_logic_vector(1 downto 0);
    signal s_v_rvalid : std_logic_vector(1 downto 0);
    signal s_v_rready : std_logic_vector(1 downto 0);

    signal m_v_awid : std_logic_vector(7 downto 0);
    signal m_v_awaddr : std_logic_vector(63 downto 0);
    signal m_v_awlen : std_logic_vector(15 downto 0);
    signal m_v_awsize : std_logic_vector(5 downto 0);
    signal m_v_awburst : std_logic_vector(3 downto 0);
    signal m_v_awlock : std_logic_vector(1 downto 0);
    signal m_v_awcache : std_logic_vector(7 downto 0);
    signal m_v_awprot : std_logic_vector(5 downto 0);
    signal m_v_awregion : std_logic_vector(7 downto 0);
    signal m_v_awqos : std_logic_vector(7 downto 0);
    signal m_v_awvalid : std_logic_vector(1 downto 0);
    signal m_v_awready : std_logic_vector(1 downto 0);
    signal m_v_wdata : std_logic_vector(511 downto 0);
    signal m_v_wstrb : std_logic_vector(63 downto 0);
    signal m_v_wlast : std_logic_vector(1 downto 0);
    signal m_v_wvalid : std_logic_vector(1 downto 0);
    signal m_v_wready : std_logic_vector(1 downto 0);
    signal m_v_bid : std_logic_vector(7 downto 0);
    signal m_v_bresp : std_logic_vector(3 downto 0);
    signal m_v_bvalid : std_logic_vector(1 downto 0);
    signal m_v_bready : std_logic_vector(1 downto 0);
    signal m_v_arid : std_logic_vector(7 downto 0);
    signal m_v_araddr : std_logic_vector(63 downto 0);
    signal m_v_arlen : std_logic_vector(15 downto 0);
    signal m_v_arsize : std_logic_vector(5 downto 0);
    signal m_v_arburst : std_logic_vector(3 downto 0);
    signal m_v_arlock : std_logic_vector(1 downto 0);
    signal m_v_arcache : std_logic_vector(7 downto 0);
    signal m_v_arprot : std_logic_vector(5 downto 0);
    signal m_v_arregion : std_logic_vector(7 downto 0);
    signal m_v_arqos : std_logic_vector(7 downto 0);
    signal m_v_arvalid : std_logic_vector(1 downto 0);
    signal m_v_arready : std_logic_vector(1 downto 0);
    signal m_v_rid : std_logic_vector(7 downto 0);
    signal m_v_rdata : std_logic_vector(511 downto 0);
    signal m_v_rresp : std_logic_vector(3 downto 0);
    signal m_v_rlast : std_logic_vector(1 downto 0);
    signal m_v_rvalid : std_logic_vector(1 downto 0);
    signal m_v_rready : std_logic_vector(1 downto 0);

begin

    --------------------------------------------------------------------
    -- DDR4 Instance
    --------------------------------------------------------------------
    ddr_rst <= not key(1);
    u_ddr4 : entity work.ddr4_0
        port map (
            sys_rst => ddr_rst, c0_sys_clk_p => sys_clk_p, c0_sys_clk_n => sys_clk_n,
            c0_init_calib_complete => calib_complete, c0_ddr4_act_n => c0_ddr4_act_n,
            c0_ddr4_adr => c0_ddr4_adr, c0_ddr4_ba => c0_ddr4_ba, c0_ddr4_bg => c0_ddr4_bg,
            c0_ddr4_cke => c0_ddr4_cke, c0_ddr4_odt => c0_ddr4_odt, c0_ddr4_cs_n => c0_ddr4_cs_n,
            c0_ddr4_ck_t => c0_ddr4_ck_t, c0_ddr4_ck_c => c0_ddr4_ck_c, c0_ddr4_reset_n => c0_ddr4_reset_n,
            c0_ddr4_dm_dbi_n => c0_ddr4_dm_dbi_n, c0_ddr4_dq => c0_ddr4_dq,
            c0_ddr4_dqs_t => c0_ddr4_dqs_t, c0_ddr4_dqs_c => c0_ddr4_dqs_c,
            c0_ddr4_ui_clk => ui_clk, c0_ddr4_ui_clk_sync_rst => ui_rst, addn_ui_clkout1 => clk_100,
            c0_ddr4_aresetn => ui_rst_n, c0_ddr4_s_axi_awid => ddr_awid, c0_ddr4_s_axi_awaddr => ddr_awaddr,
            c0_ddr4_s_axi_awlen => ddr_awlen, c0_ddr4_s_axi_awsize => "101", c0_ddr4_s_axi_awburst => ddr_awburst,
            c0_ddr4_s_axi_awlock => "0", c0_ddr4_s_axi_awcache => "0011", c0_ddr4_s_axi_awprot => "000",
            c0_ddr4_s_axi_awqos => "0000", c0_ddr4_s_axi_awvalid => ddr_awvalid, c0_ddr4_s_axi_awready => ddr_awready,
            c0_ddr4_s_axi_wdata => ddr_wdata, c0_ddr4_s_axi_wstrb => ddr_wstrb, c0_ddr4_s_axi_wlast => ddr_wlast,
            c0_ddr4_s_axi_wvalid => ddr_wvalid, c0_ddr4_s_axi_wready => ddr_wready, c0_ddr4_s_axi_bid => ddr_bid,
            c0_ddr4_s_axi_bresp => ddr_bresp, c0_ddr4_s_axi_bvalid => ddr_bvalid, c0_ddr4_s_axi_bready => ddr_bready,
            c0_ddr4_s_axi_arid => ddr_arid, c0_ddr4_s_axi_araddr => ddr_araddr, c0_ddr4_s_axi_arlen => ddr_arlen,
            c0_ddr4_s_axi_arsize => "101", c0_ddr4_s_axi_arburst => ddr_arburst, c0_ddr4_s_axi_arlock => "0",
            c0_ddr4_s_axi_arcache => "0011", c0_ddr4_s_axi_arprot => "000", c0_ddr4_s_axi_arqos => "0000",
            c0_ddr4_s_axi_arvalid => ddr_arvalid, c0_ddr4_s_axi_arready => ddr_arready, c0_ddr4_s_axi_rid => ddr_rid,
            c0_ddr4_s_axi_rdata => ddr_rdata, c0_ddr4_s_axi_rresp => ddr_rresp, c0_ddr4_s_axi_rlast => ddr_rlast,
            c0_ddr4_s_axi_rvalid => ddr_rvalid, c0_ddr4_s_axi_rready => ddr_rready
        );

    --------------------------------------------------------------------
    -- UART Bridge
    --------------------------------------------------------------------
    u_bridge : entity work.dbg_bridge generic map ( CLK_FREQ => 100000000, UART_SPEED => 115200 )
        port map (
            clk_i => clk_100, rst_i => rst_i, uart_rxd_i => uart_rxd_i, uart_txd_o => uart_txd_o,
            mem_awvalid_o => br_awvalid, mem_awready_i => br_awready, mem_awaddr_o => br_awaddr,
            mem_awid_o => br_awid, mem_awlen_o => br_awlen, mem_awburst_o => br_awburst,
            mem_wvalid_o => br_wvalid, mem_wready_i => br_wready, mem_wdata_o => br_wdata,
            mem_wstrb_o => br_wstrb, mem_wlast_o => br_wlast,
            mem_bvalid_i => br_bvalid, mem_bready_o => br_bready, mem_bresp_i => br_bresp, mem_bid_i => br_bid,
            mem_arvalid_o => br_arvalid, mem_arready_i => br_arready, mem_araddr_o => br_araddr,
            mem_arid_o => br_arid, mem_arlen_o => br_arlen, mem_arburst_o => br_arburst,
            mem_rvalid_i => br_rvalid, mem_rready_o => br_rready, mem_rdata_i => br_rdata,
            mem_rresp_i => br_rresp, mem_rid_i => br_rid, mem_rlast_i => br_rlast,
            gpio_inputs_i => (others => '0'), gpio_outputs_o => open
        );

    --------------------------------------------------------------------
    -- DMA
    --------------------------------------------------------------------
    u_dma : entity work.simple_dma
        port map (
            clk_i => ui_clk, rst_i => ui_rst,
            s_axi_awaddr => dma_s_awaddr, s_axi_awvalid => dma_s_awvalid, s_axi_awready => dma_s_awready,
            s_axi_wdata => dma_s_wdata, s_axi_wstrb => dma_s_wstrb, s_axi_wvalid => dma_s_wvalid, s_axi_wready => dma_s_wready,
            s_axi_bresp => dma_s_bresp, s_axi_bvalid => dma_s_bvalid, s_axi_bready => dma_s_bready,
            s_axi_araddr => dma_s_araddr, s_axi_arvalid => dma_s_arvalid, s_axi_arready => dma_s_arready,
            s_axi_rdata => dma_s_rdata, s_axi_rresp => dma_s_rresp, s_axi_rvalid => dma_s_rvalid, s_axi_rready => dma_s_rready,
            m_axi_awaddr => dma_m_awaddr, m_axi_awlen => dma_m_awlen, m_axi_awsize => dma_m_awsize, m_axi_awburst => dma_m_awburst,
            m_axi_awlock => dma_m_awlock, m_axi_awcache => dma_m_awcache, m_axi_awprot => dma_m_awprot, m_axi_awvalid => dma_m_awvalid, m_axi_awready => dma_m_awready,
            m_axi_wdata => dma_m_wdata, m_axi_wstrb => dma_m_wstrb, m_axi_wlast => dma_m_wlast, m_axi_wvalid => dma_m_wvalid, m_axi_wready => dma_m_wready,
            m_axi_bresp => dma_m_bresp, m_axi_bvalid => dma_m_bvalid, m_axi_bready => dma_m_bready,
            m_axi_araddr => dma_m_araddr, m_axi_arlen => dma_m_arlen, m_axi_arsize => dma_m_arsize, m_axi_arburst => dma_m_arburst,
            m_axi_arlock => dma_m_arlock, m_axi_arcache => dma_m_arcache, m_axi_arprot => dma_m_arprot, m_axi_arvalid => dma_m_arvalid, m_axi_arready => dma_m_arready,
            m_axi_rdata => dma_m_rdata, m_axi_rresp => dma_m_rresp, m_axi_rlast => dma_m_rlast, m_axi_rvalid => dma_m_rvalid, m_axi_rready => dma_m_rready,
            busy_o => dma_busy
        );

    --------------------------------------------------------------------
    -- Connectivity
    --------------------------------------------------------------------
    rst_100_n <= not rst_i;
    ui_rst_n <= not ui_rst;

    u_clk_conv : entity work.axi_clock_converter_0
        port map (
            s_axi_aclk => clk_100, s_axi_aresetn => rst_100_n,
            s_axi_awid => br_awid, s_axi_awaddr => br_awaddr, s_axi_awlen => br_awlen, s_axi_awsize => "010",
            s_axi_awburst => br_awburst, s_axi_awlock => "0", s_axi_awcache => "0011", s_axi_awprot => "000",
            s_axi_awregion => "0000", s_axi_awqos => "0000", s_axi_awvalid => br_awvalid, s_axi_awready => br_awready,
            s_axi_wdata => br_wdata, s_axi_wstrb => br_wstrb, s_axi_wlast => br_wlast, s_axi_wvalid => br_wvalid, s_axi_wready => br_wready,
            s_axi_bid => br_bid, s_axi_bresp => br_bresp, s_axi_bvalid => br_bvalid, s_axi_bready => br_bready,
            s_axi_arid => br_arid, s_axi_araddr => br_araddr, s_axi_arlen => br_arlen, s_axi_arsize => "010",
            s_axi_arburst => br_arburst, s_axi_arlock => "0", s_axi_arcache => "0011", s_axi_arprot => "000",
            s_axi_arregion => "0000", s_axi_arqos => "0000", s_axi_arvalid => br_arvalid, s_axi_arready => br_arready,
            s_axi_rid => br_rid, s_axi_rdata => br_rdata, s_axi_rresp => br_rresp, s_axi_rlast => br_rlast, s_axi_rvalid => br_rvalid, s_axi_rready => br_rready,
            m_axi_aclk => ui_clk, m_axi_aresetn => ui_rst_n,
            m_axi_awid => br_ui_awid, m_axi_awaddr => br_ui_awaddr, m_axi_awlen => br_ui_awlen, m_axi_awsize => open,
            m_axi_awburst => br_ui_awburst, m_axi_awlock => open, m_axi_awcache => open, m_axi_awprot => open,
            m_axi_awregion => open, m_axi_awqos => open, m_axi_awvalid => br_ui_awvalid, m_axi_awready => br_ui_awready,
            m_axi_wdata => br_ui_wdata, m_axi_wstrb => br_ui_wstrb, m_axi_wlast => br_ui_wlast, m_axi_wvalid => br_ui_wvalid, m_axi_wready => br_ui_wready,
            m_axi_bid => br_ui_bid, m_axi_bresp => br_ui_bresp, m_axi_bvalid => br_ui_bvalid, m_axi_bready => br_ui_bready,
            m_axi_arid => br_ui_arid, m_axi_araddr => br_ui_araddr, m_axi_arlen => br_ui_arlen, m_axi_arsize => open,
            m_axi_arburst => br_ui_arburst, m_axi_arlock => open, m_axi_arcache => open, m_axi_arprot => open,
            m_axi_arregion => open, m_axi_arqos => open, m_axi_arvalid => br_ui_arvalid, m_axi_arready => br_ui_arready,
            m_axi_rid => br_ui_rid, m_axi_rdata => br_ui_rdata, m_axi_rresp => br_ui_rresp, m_axi_rlast => br_ui_rlast, m_axi_rvalid => br_ui_rvalid, m_axi_rready => br_ui_rready
        );

    u_dwidth_up : entity work.axi_dwidth_converter_0
        port map (
            s_axi_aclk => ui_clk, s_axi_aresetn => ui_rst_n,
            s_axi_awid => br_ui_awid, s_axi_awaddr => br_ui_awaddr, s_axi_awlen => br_ui_awlen, s_axi_awsize => "010",
            s_axi_awburst => br_ui_awburst, s_axi_awlock => "0", s_axi_awcache => "0011", s_axi_awprot => "000",
            s_axi_awregion => "0000", s_axi_awqos => "0000", s_axi_awvalid => br_ui_awvalid, s_axi_awready => br_ui_awready,
            s_axi_wdata => br_ui_wdata, s_axi_wstrb => br_ui_wstrb, s_axi_wlast => br_ui_wlast, s_axi_wvalid => br_ui_wvalid, s_axi_wready => br_ui_wready,
            s_axi_bid => br_ui_bid, s_axi_bresp => br_ui_bresp, s_axi_bvalid => br_ui_bvalid, s_axi_bready => br_ui_bready,
            s_axi_arid => br_ui_arid, s_axi_araddr => br_ui_araddr, s_axi_arlen => br_ui_arlen, s_axi_arsize => "010",
            s_axi_arburst => br_ui_arburst, s_axi_arlock => "0", s_axi_arcache => "0011", s_axi_arprot => "000",
            s_axi_arregion => "0000", s_axi_arqos => "0000", s_axi_arvalid => br_ui_arvalid, s_axi_arready => br_ui_arready,
            s_axi_rid => br_ui_rid, s_axi_rdata => br_ui_rdata, s_axi_rresp => br_ui_rresp, s_axi_rlast => br_ui_rlast, s_axi_rvalid => br_ui_rvalid, s_axi_rready => br_ui_rready,
            m_axi_awid => br_dwc_awid, m_axi_awaddr => br_dwc_awaddr, m_axi_awlen => br_dwc_awlen, m_axi_awsize => open,
            m_axi_awburst => br_dwc_awburst, m_axi_awlock => open, m_axi_awcache => open, m_axi_awprot => open,
            m_axi_awregion => open, m_axi_awqos => open, m_axi_awvalid => br_dwc_awvalid, m_axi_awready => br_dwc_awready,
            m_axi_wdata => br_dwc_wdata, m_axi_wstrb => br_dwc_wstrb, m_axi_wlast => br_dwc_wlast, m_axi_wvalid => br_dwc_wvalid, m_axi_wready => br_dwc_wready,
            m_axi_bid => br_dwc_bid, m_axi_bresp => br_dwc_bresp, m_axi_bvalid => br_dwc_bvalid, m_axi_bready => br_dwc_bready,
            m_axi_arid => br_dwc_arid, m_axi_araddr => br_dwc_araddr, m_axi_arlen => br_dwc_arlen, m_axi_arsize => open,
            m_axi_arburst => br_dwc_arburst, m_axi_arlock => open, m_axi_arcache => open, m_axi_arprot => open,
            m_axi_arregion => open, m_axi_arqos => open, m_axi_arvalid => br_dwc_arvalid, m_axi_arready => br_dwc_arready,
            m_axi_rid => br_dwc_rid, m_axi_rdata => br_dwc_rdata, m_axi_rresp => br_dwc_rresp, m_axi_rlast => br_dwc_rlast, m_axi_rvalid => br_dwc_rvalid, m_axi_rready => br_dwc_rready
        );

    s_v_awid    <= x"00" when dma_m_awvalid = '1' else x"0" & br_dwc_awid;
    s_v_awaddr  <= dma_m_awaddr & br_dwc_awaddr;
    s_v_awlen   <= dma_m_awlen & br_dwc_awlen;
    s_v_awsize  <= "101" & "101";
    s_v_awburst <= dma_m_awburst & br_dwc_awburst;
    s_v_awlock  <= dma_m_awlock & '0';
    s_v_awcache <= "0011" & "0011";
    s_v_awprot  <= "000" & "000";
    s_v_awqos   <= "0000" & "0000";
    s_v_awvalid <= dma_m_awvalid & br_dwc_awvalid;
    br_dwc_awready <= s_v_awready(0);
    dma_m_awready  <= s_v_awready(1);
    s_v_wdata   <= dma_m_wdata & br_dwc_wdata;
    s_v_wstrb   <= dma_m_wstrb & br_dwc_wstrb;
    s_v_wlast   <= dma_m_wlast & br_dwc_wlast;
    s_v_wvalid  <= dma_m_wvalid & br_dwc_wvalid;
    br_dwc_wready <= s_v_wready(0);
    dma_m_wready  <= s_v_wready(1);
    br_dwc_bid    <= s_v_bid(3 downto 0);
    br_dwc_bresp  <= s_v_bresp(1 downto 0);
    dma_m_bresp   <= s_v_bresp(3 downto 2);
    br_dwc_bvalid <= s_v_bvalid(0);
    dma_m_bvalid  <= s_v_bvalid(1);
    s_v_bready    <= dma_m_bready & br_dwc_bready;
    s_v_arid      <= x"00" when dma_m_arvalid = '1' else x"0" & br_dwc_arid;
    s_v_araddr    <= dma_m_araddr & br_dwc_araddr;
    s_v_arlen     <= dma_m_arlen & br_dwc_arlen;
    s_v_arsize    <= "101" & "101";
    s_v_arburst   <= dma_m_arburst & br_dwc_arburst;
    s_v_arlock    <= dma_m_arlock & '0';
    s_v_arcache   <= "0011" & "0011";
    s_v_arprot    <= "000" & "000";
    s_v_arqos     <= "0000" & "0000";
    s_v_arvalid   <= dma_m_arvalid & br_dwc_arvalid;
    br_dwc_arready <= s_v_arready(0);
    dma_m_arready  <= s_v_arready(1);
    br_dwc_rid    <= s_v_rid(3 downto 0);
    br_dwc_rdata  <= s_v_rdata(255 downto 0);
    dma_m_rdata   <= s_v_rdata(511 downto 256);
    br_dwc_rresp  <= s_v_rresp(1 downto 0);
    dma_m_rresp   <= s_v_rresp(3 downto 2);
    br_dwc_rlast  <= s_v_rlast(0);
    dma_m_rlast   <= s_v_rlast(1);
    br_dwc_rvalid <= s_v_rvalid(0);
    dma_m_rvalid  <= s_v_rvalid(1);
    s_v_rready    <= dma_m_rready & br_dwc_rready;

    u_crossbar : entity work.axi_crossbar_0
        port map (
            aclk => ui_clk, aresetn => ui_rst_n,
            s_axi_awid => s_v_awid, s_axi_awaddr => s_v_awaddr, s_axi_awlen => s_v_awlen, s_axi_awsize => s_v_awsize,
            s_axi_awburst => s_v_awburst, s_axi_awlock => s_v_awlock, s_axi_awcache => s_v_awcache, s_axi_awprot => s_v_awprot,
            s_axi_awqos => s_v_awqos, s_axi_awvalid => s_v_awvalid, s_axi_awready => s_v_awready,
            s_axi_wdata => s_v_wdata, s_axi_wstrb => s_v_wstrb, s_axi_wlast => s_v_wlast, s_axi_wvalid => s_v_wvalid, s_axi_wready => s_v_wready,
            s_axi_bid => s_v_bid, s_axi_bresp => s_v_bresp, s_axi_bvalid => s_v_bvalid, s_axi_bready => s_v_bready,
            s_axi_arid => s_v_arid, s_axi_araddr => s_v_araddr, s_axi_arlen => s_v_arlen, s_axi_arsize => s_v_arsize,
            s_axi_arburst => s_v_arburst, s_axi_arlock => s_v_arlock, s_axi_arcache => s_v_arcache, s_axi_arprot => s_v_arprot,
            s_axi_arqos => s_v_arqos, s_axi_arvalid => s_v_arvalid, s_axi_arready => s_v_arready,
            s_axi_rid => s_v_rid, s_axi_rdata => s_v_rdata, s_axi_rresp => s_v_rresp, s_axi_rlast => s_v_rlast, s_axi_rvalid => s_v_rvalid, s_axi_rready => s_v_rready,
            m_axi_awid => m_v_awid, m_axi_awaddr => m_v_awaddr, m_axi_awlen => m_v_awlen, m_axi_awsize => m_v_awsize,
            m_axi_awburst => m_v_awburst, m_axi_awlock => m_v_awlock, m_axi_awcache => m_v_awcache, m_axi_awprot => m_v_awprot,
            m_axi_awregion => m_v_awregion, m_axi_awqos => m_v_awqos, m_axi_awvalid => m_v_awvalid, m_axi_awready => m_v_awready,
            m_axi_wdata => m_v_wdata, m_axi_wstrb => m_v_wstrb, m_axi_wlast => m_v_wlast, m_axi_wvalid => m_v_wvalid, m_axi_wready => m_v_wready,
            m_axi_bid => m_v_bid, m_axi_bresp => m_v_bresp, m_axi_bvalid => m_v_bvalid, m_axi_bready => m_v_bready,
            m_axi_arid => m_v_arid, m_axi_araddr => m_v_araddr, m_axi_arlen => m_v_arlen, m_axi_arsize => m_v_arsize,
            m_axi_arburst => m_v_arburst, m_axi_arlock => m_v_arlock, m_axi_arcache => m_v_arcache, m_axi_arprot => m_v_arprot,
            m_axi_arregion => m_v_arregion, m_axi_arqos => m_v_arqos, m_axi_arvalid => m_v_arvalid, m_axi_arready => m_v_arready,
            m_axi_rid => m_v_rid, m_axi_rdata => m_v_rdata, m_axi_rresp => m_v_rresp, m_axi_rlast => m_v_rlast, m_axi_rvalid => m_v_rvalid, m_axi_rready => m_v_rready
        );

    ddr_awid    <= m_v_awid(3 downto 0);
    ddr_awaddr  <= m_v_awaddr(30 downto 0);
    ddr_awlen   <= m_v_awlen(7 downto 0);
    ddr_awburst <= m_v_awburst(1 downto 0);
    ddr_awvalid <= m_v_awvalid(0);
    m_v_awready(0) <= ddr_awready;
    ddr_wdata   <= m_v_wdata(255 downto 0);
    ddr_wstrb   <= m_v_wstrb(31 downto 0);
    ddr_wlast   <= m_v_wlast(0);
    ddr_wvalid  <= m_v_wvalid(0);
    m_v_wready(0) <= ddr_wready;
    m_v_bid(3 downto 0) <= ddr_bid;
    m_v_bresp(1 downto 0) <= ddr_bresp;
    m_v_bvalid(0) <= ddr_bvalid;
    ddr_bready  <= m_v_bready(0);
    ddr_arid    <= m_v_arid(3 downto 0);
    ddr_araddr  <= m_v_araddr(30 downto 0);
    ddr_arlen   <= m_v_arlen(7 downto 0);
    ddr_arburst <= m_v_arburst(1 downto 0);
    ddr_arvalid <= m_v_arvalid(0);
    m_v_arready(0) <= ddr_arready;
    m_v_rid(3 downto 0) <= ddr_rid;
    m_v_rdata(255 downto 0) <= ddr_rdata;
    m_v_rresp(1 downto 0) <= ddr_rresp;
    m_v_rlast(0) <= ddr_rlast;
    m_v_rvalid(0) <= ddr_rvalid;
    ddr_rready  <= m_v_rready(0);

    u_dwidth_down : entity work.axi_dwidth_converter_1
        port map (
            s_axi_aclk => ui_clk, s_axi_aresetn => ui_rst_n,
            s_axi_awid => m_v_awid(7 downto 4), s_axi_awaddr => m_v_awaddr(63 downto 32), s_axi_awlen => m_v_awlen(15 downto 8), s_axi_awsize => "101",
            s_axi_awburst => m_v_awburst(3 downto 2), s_axi_awlock => "0", s_axi_awcache => "0011", s_axi_awprot => "000",
            s_axi_awregion => "0000", s_axi_awqos => "0000", s_axi_awvalid => m_v_awvalid(1), s_axi_awready => m_v_awready(1),
            s_axi_wdata => m_v_wdata(511 downto 256), s_axi_wstrb => m_v_wstrb(63 downto 32), s_axi_wlast => m_v_wlast(1), s_axi_wvalid => m_v_wvalid(1), s_axi_wready => m_v_wready(1),
            s_axi_bid => m_v_bid(7 downto 4), s_axi_bresp => m_v_bresp(3 downto 2), s_axi_bvalid => m_v_bvalid(1), s_axi_bready => m_v_bready(1),
            s_axi_arid => m_v_arid(7 downto 4), s_axi_araddr => m_v_araddr(63 downto 32), s_axi_arlen => m_v_arlen(15 downto 8), s_axi_arsize => "101",
            s_axi_arburst => m_v_arburst(3 downto 2), s_axi_arlock => "0", s_axi_arcache => "0011", s_axi_arprot => "000",
            s_axi_arregion => "0000", s_axi_arqos => "0000", s_axi_arvalid => m_v_arvalid(1), s_axi_arready => m_v_arready(1),
            s_axi_rid => m_v_rid(7 downto 4), s_axi_rdata => m_v_rdata(511 downto 256), s_axi_rresp => m_v_rresp(3 downto 2), s_axi_rlast => m_v_rlast(1), s_axi_rvalid => m_v_rvalid(1), s_axi_rready => m_v_rready(1),
            m_axi_awaddr => xbar_cfg_awaddr, m_axi_awvalid => xbar_cfg_awvalid, m_axi_awready => xbar_cfg_awready,
            m_axi_wdata => xbar_cfg_wdata(31 downto 0), m_axi_wstrb => xbar_cfg_wstrb(3 downto 0), m_axi_wvalid => xbar_cfg_wvalid, m_axi_wready => xbar_cfg_wready,
            m_axi_bresp => xbar_cfg_bresp, m_axi_bvalid => xbar_cfg_bvalid, m_axi_bready => xbar_cfg_bready,
            m_axi_araddr => xbar_cfg_araddr, m_axi_arvalid => xbar_cfg_arvalid, m_axi_arready => xbar_cfg_arready,
            m_axi_rdata => xbar_cfg_rdata(31 downto 0), m_axi_rresp => xbar_cfg_rresp, m_axi_rvalid => xbar_cfg_rvalid, m_axi_rready => xbar_cfg_rready
        );

    dma_s_awaddr <= xbar_cfg_awaddr(3 downto 0);
    dma_s_awvalid <= xbar_cfg_awvalid;
    xbar_cfg_awready <= dma_s_awready;
    dma_s_wdata <= xbar_cfg_wdata(31 downto 0);
    dma_s_wstrb <= xbar_cfg_wstrb(3 downto 0);
    dma_s_wvalid <= xbar_cfg_wvalid;
    xbar_cfg_wready <= dma_s_wready;
    xbar_cfg_bresp <= dma_s_bresp;
    xbar_cfg_bvalid <= dma_s_bvalid;
    dma_s_bready <= xbar_cfg_bready;
    dma_s_araddr <= xbar_cfg_araddr(3 downto 0);
    dma_s_arvalid <= xbar_cfg_arvalid;
    xbar_cfg_arready <= dma_s_arready;
    xbar_cfg_rdata(31 downto 0) <= dma_s_rdata;
    xbar_cfg_rresp <= dma_s_rresp;
    xbar_cfg_rvalid <= dma_s_rvalid;
    dma_s_rready <= xbar_cfg_rready;

    div_led_inst : entity work.async_div generic map ( STAGES => 28 ) port map ( clk_in => clk_100, clk_out => done_led );
    done_led_n <= not done_led;
    STARTUPE2_inst : STARTUPE2 generic map ( PROG_USR => "FALSE", SIM_CCLK_FREQ => 0.0 )
	port map ( CFGCLK => clk_cfg, CFGMCLK => clk_cfgm, EOS => open, PREQ => open, CLK => '0', GSR => '0', GTS => '0', KEYCLEARB => '0', PACK => '0', USRCCLKO => '0', USRCCLKTS => '0', USRDONEO => '0', USRDONETS => done_led_n );
    led(0) <= not key(0); led(2) <= dma_busy; led(3) <= not key(3);
end RTL;
