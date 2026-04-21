----------------------------------------------------------------------------
--  top.vhd
--	XCKU5P simple VHDL example
--	Version 1.2 - DMA and AXI Crossbar
--
--  Copyright (C) 2026 H.Poetzl
--
--	This program is free software: you can redistribute it and/or
--	modify it under the terms of the GNU General Public License
--	as published by the Free Software Foundation, either version
--	2 of the License, or (at your option) any later version.
--
--  Vivado 2025.2:
--    mkdir -p build
--    (cd build && vivado -mode tcl -source ../vivado.tcl)
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

        -- DDR4 interface
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
    signal clk_cfg : std_logic;
    signal clk_cfgm : std_logic;
    signal done_led : std_logic;
    signal done_led_n : std_logic;

    --------------------------------------------------------------------
    -- Bridge AXI Master (32-bit, 100MHz)
    --------------------------------------------------------------------
    signal bridge_awvalid : std_logic;
    signal bridge_awready : std_logic;
    signal bridge_awaddr  : std_logic_vector(31 downto 0);
    signal bridge_awid    : std_logic_vector(3 downto 0);
    signal bridge_awlen   : std_logic_vector(7 downto 0);
    signal bridge_awburst : std_logic_vector(1 downto 0);
    signal bridge_wvalid  : std_logic;
    signal bridge_wready  : std_logic;
    signal bridge_wdata   : std_logic_vector(31 downto 0);
    signal bridge_wstrb   : std_logic_vector(3 downto 0);
    signal bridge_wlast   : std_logic;
    signal bridge_bvalid  : std_logic;
    signal bridge_bready  : std_logic;
    signal bridge_bresp   : std_logic_vector(1 downto 0);
    signal bridge_bid     : std_logic_vector(3 downto 0);
    signal bridge_arvalid : std_logic;
    signal bridge_arready : std_logic;
    signal bridge_araddr  : std_logic_vector(31 downto 0);
    signal bridge_arid    : std_logic_vector(3 downto 0);
    signal bridge_arlen   : std_logic_vector(7 downto 0);
    signal bridge_arburst : std_logic_vector(1 downto 0);
    signal bridge_rvalid  : std_logic;
    signal bridge_rready  : std_logic;
    signal bridge_rdata   : std_logic_vector(31 downto 0);
    signal bridge_rresp   : std_logic_vector(1 downto 0);
    signal bridge_rid     : std_logic_vector(3 downto 0);
    signal bridge_rlast   : std_logic;

    --------------------------------------------------------------------
    -- DMA AXI Master (256-bit, UI clk)
    --------------------------------------------------------------------
    signal dma_m_awvalid : std_logic;
    signal dma_m_awready : std_logic;
    signal dma_m_awaddr  : std_logic_vector(31 downto 0);
    signal dma_m_awlen   : std_logic_vector(7 downto 0);
    signal dma_m_awsize  : std_logic_vector(2 downto 0);
    signal dma_m_awburst : std_logic_vector(1 downto 0);
    signal dma_m_awlock  : std_logic;
    signal dma_m_awcache : std_logic_vector(3 downto 0);
    signal dma_m_awprot  : std_logic_vector(2 downto 0);
    signal dma_m_wvalid  : std_logic;
    signal dma_m_wready  : std_logic;
    signal dma_m_wdata   : std_logic_vector(255 downto 0);
    signal dma_m_wstrb   : std_logic_vector(31 downto 0);
    signal dma_m_wlast   : std_logic;
    signal dma_m_bvalid  : std_logic;
    signal dma_m_bready  : std_logic;
    signal dma_m_bresp   : std_logic_vector(1 downto 0);
    signal dma_m_arvalid : std_logic;
    signal dma_m_arready : std_logic;
    signal dma_m_araddr  : std_logic_vector(31 downto 0);
    signal dma_m_arlen   : std_logic_vector(7 downto 0);
    signal dma_m_arsize  : std_logic_vector(2 downto 0);
    signal dma_m_arburst : std_logic_vector(1 downto 0);
    signal dma_m_arlock  : std_logic;
    signal dma_m_arcache : std_logic_vector(3 downto 0);
    signal dma_m_arprot  : std_logic_vector(2 downto 0);
    signal dma_m_rvalid  : std_logic;
    signal dma_m_rready  : std_logic;
    signal dma_m_rdata   : std_logic_vector(255 downto 0);
    signal dma_m_rresp   : std_logic_vector(1 downto 0);
    signal dma_m_rlast   : std_logic;

    --------------------------------------------------------------------
    -- DMA AXI Slave (32-bit, UI clk)
    --------------------------------------------------------------------
    signal dma_s_awvalid : std_logic;
    signal dma_s_awready : std_logic;
    signal dma_s_awaddr  : std_logic_vector(3 downto 0);
    signal dma_s_wvalid  : std_logic;
    signal dma_s_wready  : std_logic;
    signal dma_s_wdata   : std_logic_vector(31 downto 0);
    signal dma_s_wstrb   : std_logic_vector(3 downto 0);
    signal dma_s_bvalid  : std_logic;
    signal dma_s_bready  : std_logic;
    signal dma_s_bresp   : std_logic_vector(1 downto 0);
    signal dma_s_arvalid : std_logic;
    signal dma_s_arready : std_logic;
    signal dma_s_araddr  : std_logic_vector(3 downto 0);
    signal dma_s_rvalid  : std_logic;
    signal dma_s_rready  : std_logic;
    signal dma_s_rdata   : std_logic_vector(31 downto 0);
    signal dma_s_rresp   : std_logic_vector(1 downto 0);

    --------------------------------------------------------------------
    -- DDR4 AXI Slave (256-bit, UI clk)
    --------------------------------------------------------------------
    signal ddr_awvalid : std_logic;
    signal ddr_awready : std_logic;
    signal ddr_awaddr  : std_logic_vector(30 downto 0);
    signal ddr_awid    : std_logic_vector(3 downto 0);
    signal ddr_awlen   : std_logic_vector(7 downto 0);
    signal ddr_awburst : std_logic_vector(1 downto 0);
    signal ddr_wvalid  : std_logic;
    signal ddr_wready  : std_logic;
    signal ddr_wdata   : std_logic_vector(255 downto 0);
    signal ddr_wstrb   : std_logic_vector(31 downto 0);
    signal ddr_wlast   : std_logic;
    signal ddr_bvalid  : std_logic;
    signal ddr_bready  : std_logic;
    signal ddr_bresp   : std_logic_vector(1 downto 0);
    signal ddr_bid     : std_logic_vector(3 downto 0);
    signal ddr_arvalid : std_logic;
    signal ddr_arready : std_logic;
    signal ddr_araddr  : std_logic_vector(30 downto 0);
    signal ddr_arid    : std_logic_vector(3 downto 0);
    signal ddr_arlen   : std_logic_vector(7 downto 0);
    signal ddr_arburst : std_logic_vector(1 downto 0);
    signal ddr_rvalid  : std_logic;
    signal ddr_rready  : std_logic;
    signal ddr_rdata   : std_logic_vector(255 downto 0);
    signal ddr_rresp   : std_logic_vector(1 downto 0);
    signal ddr_rid     : std_logic_vector(3 downto 0);
    signal ddr_rlast   : std_logic;

    signal rst_i : std_logic;
    signal ddr_rst : std_logic;
    signal ui_clk : std_logic;
    signal ui_rst : std_logic;
    signal ui_rst_n : std_logic;
    signal rst_100_n : std_logic;

    signal calib_complete : std_logic;
    signal dma_busy : std_logic;

    -- UI Domain Signals (after Clock Converter)
    signal bridge_ui_awid    : std_logic_vector(3 downto 0);
    signal bridge_ui_awaddr  : std_logic_vector(31 downto 0);
    signal bridge_ui_awlen   : std_logic_vector(7 downto 0);
    signal bridge_ui_awburst : std_logic_vector(1 downto 0);
    signal bridge_ui_awvalid : std_logic;
    signal bridge_ui_awready : std_logic;
    signal bridge_ui_wdata   : std_logic_vector(31 downto 0);
    signal bridge_ui_wstrb   : std_logic_vector(3 downto 0);
    signal bridge_ui_wlast   : std_logic;
    signal bridge_ui_wvalid  : std_logic;
    signal bridge_ui_wready  : std_logic;
    signal bridge_ui_bid     : std_logic_vector(3 downto 0);
    signal bridge_ui_bresp   : std_logic_vector(1 downto 0);
    signal bridge_ui_bvalid  : std_logic;
    signal bridge_ui_bready  : std_logic;
    signal bridge_ui_arid    : std_logic_vector(3 downto 0);
    signal bridge_ui_araddr  : std_logic_vector(31 downto 0);
    signal bridge_ui_arlen   : std_logic_vector(7 downto 0);
    signal bridge_ui_arburst : std_logic_vector(1 downto 0);
    signal bridge_ui_arvalid : std_logic;
    signal bridge_ui_arready : std_logic;
    signal bridge_ui_rid     : std_logic_vector(3 downto 0);
    signal bridge_ui_rdata   : std_logic_vector(31 downto 0);
    signal bridge_ui_rresp   : std_logic_vector(1 downto 0);
    signal bridge_ui_rlast   : std_logic;
    signal bridge_ui_rvalid  : std_logic;
    signal bridge_ui_rready  : std_logic;

    -- DWIDTH Domain Signals (after up-converter)
    signal bridge_dwc_awid    : std_logic_vector(3 downto 0);
    signal bridge_dwc_awaddr  : std_logic_vector(31 downto 0);
    signal bridge_dwc_awlen   : std_logic_vector(7 downto 0);
    signal bridge_dwc_awburst : std_logic_vector(1 downto 0);
    signal bridge_dwc_awvalid : std_logic;
    signal bridge_dwc_awready : std_logic;
    signal bridge_dwc_wdata   : std_logic_vector(255 downto 0);
    signal bridge_dwc_wstrb   : std_logic_vector(31 downto 0);
    signal bridge_dwc_wlast   : std_logic;
    signal bridge_dwc_wvalid  : std_logic;
    signal bridge_dwc_wready  : std_logic;
    signal bridge_dwc_bid     : std_logic_vector(3 downto 0);
    signal bridge_dwc_bresp   : std_logic_vector(1 downto 0);
    signal bridge_dwc_bvalid  : std_logic;
    signal bridge_dwc_bready  : std_logic;
    signal bridge_dwc_arid    : std_logic_vector(3 downto 0);
    signal bridge_dwc_araddr  : std_logic_vector(31 downto 0);
    signal bridge_dwc_arlen   : std_logic_vector(7 downto 0);
    signal bridge_dwc_arburst : std_logic_vector(1 downto 0);
    signal bridge_dwc_arvalid : std_logic;
    signal bridge_dwc_arready : std_logic;
    signal bridge_dwc_rid     : std_logic_vector(3 downto 0);
    signal bridge_dwc_rdata   : std_logic_vector(255 downto 0);
    signal bridge_dwc_rresp   : std_logic_vector(1 downto 0);
    signal bridge_dwc_rlast   : std_logic;
    signal bridge_dwc_rvalid  : std_logic;
    signal bridge_dwc_rready  : std_logic;

    -- Crossbar signals (SI/MI aggregation)
    signal xbar_s_awid    : std_logic_vector(7 downto 0);
    signal xbar_s_awaddr  : std_logic_vector(63 downto 0);
    signal xbar_s_awlen   : std_logic_vector(15 downto 0);
    signal xbar_s_awsize  : std_logic_vector(5 downto 0);
    signal xbar_s_awburst : std_logic_vector(3 downto 0);
    signal xbar_s_awlock  : std_logic_vector(1 downto 0);
    signal xbar_s_awcache : std_logic_vector(7 downto 0);
    signal xbar_s_awprot  : std_logic_vector(5 downto 0);
    signal xbar_s_awqos   : std_logic_vector(7 downto 0);
    signal xbar_s_awvalid : std_logic_vector(1 downto 0);
    signal xbar_s_awready : std_logic_vector(1 downto 0);
    signal xbar_s_wdata   : std_logic_vector(511 downto 0);
    signal xbar_s_wstrb   : std_logic_vector(63 downto 0);
    signal xbar_s_wlast   : std_logic_vector(1 downto 0);
    signal xbar_s_wvalid  : std_logic_vector(1 downto 0);
    signal xbar_s_wready  : std_logic_vector(1 downto 0);
    signal xbar_s_bid     : std_logic_vector(7 downto 0);
    signal xbar_s_bresp   : std_logic_vector(3 downto 0);
    signal xbar_s_bvalid  : std_logic_vector(1 downto 0);
    signal xbar_s_bready  : std_logic_vector(1 downto 0);
    signal xbar_s_arid    : std_logic_vector(7 downto 0);
    signal xbar_s_araddr  : std_logic_vector(63 downto 0);
    signal xbar_s_arlen   : std_logic_vector(15 downto 0);
    signal xbar_s_arsize  : std_logic_vector(5 downto 0);
    signal xbar_s_arburst : std_logic_vector(3 downto 0);
    signal xbar_s_arlock  : std_logic_vector(1 downto 0);
    signal xbar_s_arcache : std_logic_vector(7 downto 0);
    signal xbar_s_arprot  : std_logic_vector(5 downto 0);
    signal xbar_s_arqos   : std_logic_vector(7 downto 0);
    signal xbar_s_arvalid : std_logic_vector(1 downto 0);
    signal xbar_s_arready : std_logic_vector(1 downto 0);
    signal xbar_s_rid     : std_logic_vector(7 downto 0);
    signal xbar_s_rdata   : std_logic_vector(511 downto 0);
    signal xbar_s_rresp   : std_logic_vector(3 downto 0);
    signal xbar_s_rlast   : std_logic_vector(1 downto 0);
    signal xbar_s_rvalid  : std_logic_vector(1 downto 0);
    signal xbar_s_rready  : std_logic_vector(1 downto 0);

    signal xbar_m_awid    : std_logic_vector(7 downto 0);
    signal xbar_m_awaddr  : std_logic_vector(63 downto 0);
    signal xbar_m_awlen   : std_logic_vector(15 downto 0);
    signal xbar_m_awsize  : std_logic_vector(5 downto 0);
    signal xbar_m_awburst : std_logic_vector(3 downto 0);
    signal xbar_m_awlock  : std_logic_vector(1 downto 0);
    signal xbar_m_awcache : std_logic_vector(7 downto 0);
    signal xbar_m_awprot  : std_logic_vector(5 downto 0);
    signal xbar_m_awregion: std_logic_vector(7 downto 0);
    signal xbar_m_awqos   : std_logic_vector(7 downto 0);
    signal xbar_m_awvalid : std_logic_vector(1 downto 0);
    signal xbar_m_awready : std_logic_vector(1 downto 0);
    signal xbar_m_wdata   : std_logic_vector(511 downto 0);
    signal xbar_m_wstrb   : std_logic_vector(63 downto 0);
    signal xbar_m_wlast   : std_logic_vector(1 downto 0);
    signal xbar_m_wvalid  : std_logic_vector(1 downto 0);
    signal xbar_m_wready  : std_logic_vector(1 downto 0);
    signal xbar_m_bid     : std_logic_vector(7 downto 0);
    signal xbar_m_bresp   : std_logic_vector(3 downto 0);
    signal xbar_m_bvalid  : std_logic_vector(1 downto 0);
    signal xbar_m_bready  : std_logic_vector(1 downto 0);
    signal xbar_m_arid    : std_logic_vector(7 downto 0);
    signal xbar_m_araddr  : std_logic_vector(63 downto 0);
    signal xbar_m_arlen   : std_logic_vector(15 downto 0);
    signal xbar_m_arsize  : std_logic_vector(5 downto 0);
    signal xbar_m_arburst : std_logic_vector(3 downto 0);
    signal xbar_m_arlock  : std_logic_vector(1 downto 0);
    signal xbar_m_arcache : std_logic_vector(7 downto 0);
    signal xbar_m_arprot  : std_logic_vector(5 downto 0);
    signal xbar_m_arregion: std_logic_vector(7 downto 0);
    signal xbar_m_arqos   : std_logic_vector(7 downto 0);
    signal xbar_m_arvalid : std_logic_vector(1 downto 0);
    signal xbar_m_arready : std_logic_vector(1 downto 0);
    signal xbar_m_rid     : std_logic_vector(7 downto 0);
    signal xbar_m_rdata   : std_logic_vector(511 downto 0);
    signal xbar_m_rresp   : std_logic_vector(3 downto 0);
    signal xbar_m_rlast   : std_logic_vector(1 downto 0);
    signal xbar_m_rvalid  : std_logic_vector(1 downto 0);
    signal xbar_m_rready  : std_logic_vector(1 downto 0);

    signal xbar_m01_awaddr  : std_logic_vector(31 downto 0);
    signal xbar_m01_awlen   : std_logic_vector(7 downto 0);
    signal xbar_m01_awburst : std_logic_vector(1 downto 0);
    signal xbar_m01_awvalid : std_logic;
    signal xbar_m01_awready : std_logic;
    signal xbar_m01_wdata   : std_logic_vector(255 downto 0);
    signal xbar_m01_wstrb   : std_logic_vector(31 downto 0);
    signal xbar_m01_wlast   : std_logic;
    signal xbar_m01_wvalid  : std_logic;
    signal xbar_m01_wready  : std_logic;
    signal xbar_m01_bresp   : std_logic_vector(1 downto 0);
    signal xbar_m01_bvalid  : std_logic;
    signal xbar_m01_bready  : std_logic;
    signal xbar_m01_araddr  : std_logic_vector(31 downto 0);
    signal xbar_m01_arlen   : std_logic_vector(7 downto 0);
    signal xbar_m01_arburst : std_logic_vector(1 downto 0);
    signal xbar_m01_arvalid : std_logic;
    signal xbar_m01_arready : std_logic;
    signal xbar_m01_rdata   : std_logic_vector(255 downto 0);
    signal xbar_m01_rresp   : std_logic_vector(1 downto 0);
    signal xbar_m01_rlast   : std_logic;
    signal xbar_m01_rvalid  : std_logic;
    signal xbar_m01_rready  : std_logic;

    signal bridge_awaddr_dma : std_logic_vector(31 downto 0);
    signal bridge_araddr_dma : std_logic_vector(31 downto 0);

begin

    --------------------------------------------------------------------
    -- DDR4 IP Instance
    --------------------------------------------------------------------
    ddr_rst <= not key(1);

    u_ddr4 : entity work.ddr4_0
        port map (
            sys_rst                => ddr_rst,
            c0_sys_clk_p           => sys_clk_p,
            c0_sys_clk_n           => sys_clk_n,
            c0_init_calib_complete => calib_complete,
            c0_ddr4_act_n          => c0_ddr4_act_n,
            c0_ddr4_adr            => c0_ddr4_adr,
            c0_ddr4_ba             => c0_ddr4_ba,
            c0_ddr4_bg             => c0_ddr4_bg,
            c0_ddr4_cke            => c0_ddr4_cke,
            c0_ddr4_odt            => c0_ddr4_odt,
            c0_ddr4_cs_n           => c0_ddr4_cs_n,
            c0_ddr4_ck_t           => c0_ddr4_ck_t,
            c0_ddr4_ck_c           => c0_ddr4_ck_c,
            c0_ddr4_reset_n        => c0_ddr4_reset_n,
            c0_ddr4_dm_dbi_n       => c0_ddr4_dm_dbi_n,
            c0_ddr4_dq             => c0_ddr4_dq,
            c0_ddr4_dqs_t          => c0_ddr4_dqs_t,
            c0_ddr4_dqs_c          => c0_ddr4_dqs_c,
            c0_ddr4_ui_clk         => ui_clk,
            c0_ddr4_ui_clk_sync_rst => ui_rst,
            addn_ui_clkout1        => clk_100,
            c0_ddr4_aresetn        => ui_rst_n,
            c0_ddr4_s_axi_awid     => ddr_awid,
            c0_ddr4_s_axi_awaddr   => ddr_awaddr,
            c0_ddr4_s_axi_awlen    => ddr_awlen,
            c0_ddr4_s_axi_awsize   => "101",
            c0_ddr4_s_axi_awburst  => ddr_awburst,
            c0_ddr4_s_axi_awlock   => "0",
            c0_ddr4_s_axi_awcache  => "0011",
            c0_ddr4_s_axi_awprot   => "000",
            c0_ddr4_s_axi_awqos    => "0000",
            c0_ddr4_s_axi_awvalid  => ddr_awvalid,
            c0_ddr4_s_axi_awready  => ddr_awready,
            c0_ddr4_s_axi_wdata    => ddr_wdata,
            c0_ddr4_s_axi_wstrb    => ddr_wstrb,
            c0_ddr4_s_axi_wlast    => ddr_wlast,
            c0_ddr4_s_axi_wvalid   => ddr_wvalid,
            c0_ddr4_s_axi_wready   => ddr_wready,
            c0_ddr4_s_axi_bid      => ddr_bid,
            c0_ddr4_s_axi_bresp    => ddr_bresp,
            c0_ddr4_s_axi_bvalid   => ddr_bvalid,
            c0_ddr4_s_axi_bready   => ddr_bready,
            c0_ddr4_s_axi_arid     => ddr_arid,
            c0_ddr4_s_axi_araddr   => ddr_araddr,
            c0_ddr4_s_axi_arlen    => ddr_arlen,
            c0_ddr4_s_axi_arsize   => "101",
            c0_ddr4_s_axi_arburst  => ddr_arburst,
            c0_ddr4_s_axi_arlock   => "0",
            c0_ddr4_s_axi_arcache  => "0011",
            c0_ddr4_s_axi_arprot   => "000",
            c0_ddr4_s_axi_arqos    => "0000",
            c0_ddr4_s_axi_arvalid  => ddr_arvalid,
            c0_ddr4_s_axi_arready  => ddr_arready,
            c0_ddr4_s_axi_rid      => ddr_rid,
            c0_ddr4_s_axi_rdata    => ddr_rdata,
            c0_ddr4_s_axi_rresp    => ddr_rresp,
            c0_ddr4_s_axi_rlast    => ddr_rlast,
            c0_ddr4_s_axi_rvalid   => ddr_rvalid,
            c0_ddr4_s_axi_rready   => ddr_rready
        );

    ui_rst_n <= not ui_rst;
    led(1) <= calib_complete;

    --------------------------------------------------------------------
    -- Debug Bridge
    --------------------------------------------------------------------
    rst_i <= not key(0);

    u_bridge : entity work.dbg_bridge
        generic map ( CLK_FREQ => 100000000, UART_SPEED => 115200 )
        port map (
            clk_i          => clk_100,
            rst_i          => rst_i,
            uart_rxd_i     => uart_rxd_i,
            uart_txd_o     => uart_txd_o,
            mem_awvalid_o  => bridge_awvalid,
            mem_awready_i  => bridge_awready,
            mem_awaddr_o   => bridge_awaddr,
            mem_awid_o     => bridge_awid,
            mem_awlen_o    => bridge_awlen,
            mem_awburst_o  => bridge_awburst,
            mem_wvalid_o   => bridge_wvalid,
            mem_wready_i   => bridge_wready,
            mem_wdata_o    => bridge_wdata,
            mem_wstrb_o    => bridge_wstrb,
            mem_wlast_o    => bridge_wlast,
            mem_bvalid_i   => bridge_bvalid,
            mem_bready_o   => bridge_bready,
            mem_bresp_i    => bridge_bresp,
            mem_bid_i      => bridge_bid,
            mem_arvalid_o  => bridge_arvalid,
            mem_arready_i  => bridge_arready,
            mem_araddr_o   => bridge_araddr,
            mem_arid_o     => bridge_arid,
            mem_arlen_o    => bridge_arlen,
            mem_arburst_o  => bridge_arburst,
            mem_rvalid_i   => bridge_rvalid,
            mem_rready_o   => bridge_rready,
            mem_rdata_i    => bridge_rdata,
            mem_rresp_i    => bridge_rresp,
            mem_rid_i      => bridge_rid,
            mem_rlast_i    => bridge_rlast,
            gpio_inputs_i  => (others => '0'),
            gpio_outputs_o => open
        );

    --------------------------------------------------------------------
    -- Simple DMA
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
    -- Interconnect
    --------------------------------------------------------------------
    rst_100_n <= not rst_i;

    u_clk_conv : entity work.axi_clock_converter_0
        port map (
            s_axi_aclk => clk_100, s_axi_aresetn => rst_100_n,
            s_axi_awid => bridge_awid, s_axi_awaddr => bridge_awaddr, s_axi_awlen => bridge_awlen, s_axi_awsize => "010",
            s_axi_awburst => bridge_awburst, s_axi_awlock => "0", s_axi_awcache => "0011", s_axi_awprot => "000",
            s_axi_awregion => "0000", s_axi_awqos => "0000", s_axi_awvalid => bridge_awvalid, s_axi_awready => bridge_awready,
            s_axi_wdata => bridge_wdata, s_axi_wstrb => bridge_wstrb, s_axi_wlast => bridge_wlast, s_axi_wvalid => bridge_wvalid, s_axi_wready => bridge_wready,
            s_axi_bid => bridge_bid, s_axi_bresp => bridge_bresp, s_axi_bvalid => bridge_bvalid, s_axi_bready => bridge_bready,
            s_axi_arid => bridge_arid, s_axi_araddr => bridge_araddr, s_axi_arlen => bridge_arlen, s_axi_arsize => "010",
            s_axi_arburst => bridge_arburst, s_axi_arlock => "0", s_axi_arcache => "0011", s_axi_arprot => "000",
            s_axi_arregion => "0000", s_axi_arqos => "0000", s_axi_arvalid => bridge_arvalid, s_axi_arready => bridge_arready,
            s_axi_rid => bridge_rid, s_axi_rdata => bridge_rdata, s_axi_rresp => bridge_rresp, s_axi_rlast => bridge_rlast, s_axi_rvalid => bridge_rvalid, s_axi_rready => bridge_rready,
            m_axi_aclk => ui_clk, m_axi_aresetn => ui_rst_n,
            m_axi_awid => bridge_ui_awid, m_axi_awaddr => bridge_ui_awaddr, m_axi_awlen => bridge_ui_awlen, m_axi_awsize => open,
            m_axi_awburst => bridge_ui_awburst, m_axi_awlock => open, m_axi_awcache => open, m_axi_awprot => open,
            m_axi_awregion => open, m_axi_awqos => open, m_axi_awvalid => bridge_ui_awvalid, m_axi_awready => bridge_ui_awready,
            m_axi_wdata => bridge_ui_wdata, m_axi_wstrb => bridge_ui_wstrb, m_axi_wlast => bridge_ui_wlast, m_axi_wvalid => bridge_ui_wvalid, m_axi_wready => bridge_ui_wready,
            m_axi_bid => bridge_ui_bid, m_axi_bresp => bridge_ui_bresp, m_axi_bvalid => bridge_ui_bvalid, m_axi_bready => bridge_ui_bready,
            m_axi_arid => bridge_ui_arid, m_axi_araddr => bridge_ui_araddr, m_axi_arlen => bridge_ui_arlen, m_axi_arsize => open,
            m_axi_arburst => bridge_ui_arburst, m_axi_arlock => open, m_axi_arcache => open, m_axi_arprot => open,
            m_axi_arregion => open, m_axi_arqos => open, m_axi_arvalid => bridge_ui_arvalid, m_axi_arready => bridge_ui_arready,
            m_axi_rid => bridge_ui_rid, m_axi_rdata => bridge_ui_rdata, m_axi_rresp => bridge_ui_rresp, m_axi_rlast => bridge_ui_rlast, m_axi_rvalid => bridge_ui_rvalid, m_axi_rready => bridge_ui_rready
        );

    u_dwidth_up : entity work.axi_dwidth_converter_0
        port map (
            s_axi_aclk => ui_clk, s_axi_aresetn => ui_rst_n,
            s_axi_awid => bridge_ui_awid, s_axi_awaddr => bridge_ui_awaddr, s_axi_awlen => bridge_ui_awlen, s_axi_awsize => "010",
            s_axi_awburst => bridge_ui_awburst, s_axi_awlock => "0", s_axi_awcache => "0011", s_axi_awprot => "000",
            s_axi_awregion => "0000", s_axi_awqos => "0000", s_axi_awvalid => bridge_ui_awvalid, s_axi_awready => bridge_ui_awready,
            s_axi_wdata => bridge_ui_wdata, s_axi_wstrb => bridge_ui_wstrb, s_axi_wlast => bridge_ui_wlast, s_axi_wvalid => bridge_ui_wvalid, s_axi_wready => bridge_ui_wready,
            s_axi_bid => bridge_ui_bid, s_axi_bresp => bridge_ui_bresp, s_axi_bvalid => bridge_ui_bvalid, s_axi_bready => bridge_ui_bready,
            s_axi_arid => bridge_ui_arid, s_axi_araddr => bridge_ui_araddr, s_axi_arlen => bridge_ui_arlen, s_axi_arsize => "010",
            s_axi_arburst => bridge_ui_arburst, s_axi_arlock => "0", s_axi_arcache => "0011", s_axi_arprot => "000",
            s_axi_arregion => "0000", s_axi_arqos => "0000", s_axi_arvalid => bridge_ui_arvalid, s_axi_arready => bridge_ui_arready,
            s_axi_rid => bridge_ui_rid, s_axi_rdata => bridge_ui_rdata, s_axi_rresp => bridge_ui_rresp, s_axi_rlast => bridge_ui_rlast, s_axi_rvalid => bridge_ui_rvalid, s_axi_rready => bridge_ui_rready,
            m_axi_awid => bridge_dwc_awid, m_axi_awaddr => bridge_dwc_awaddr, m_axi_awlen => bridge_dwc_awlen, m_axi_awsize => open,
            m_axi_awburst => bridge_dwc_awburst, m_axi_awlock => open, m_axi_awcache => open, m_axi_awprot => open,
            m_axi_awregion => open, m_axi_awqos => open, m_axi_awvalid => bridge_dwc_awvalid, m_axi_awready => bridge_dwc_awready,
            m_axi_wdata => bridge_dwc_wdata, m_axi_wstrb => bridge_dwc_wstrb, m_axi_wlast => bridge_dwc_wlast, m_axi_wvalid => bridge_dwc_wvalid, m_axi_wready => bridge_dwc_wready,
            m_axi_bid => bridge_dwc_bid, m_axi_bresp => bridge_dwc_bresp, m_axi_bvalid => bridge_dwc_bvalid, m_axi_bready => bridge_dwc_bready,
            m_axi_arid => bridge_dwc_arid, m_axi_araddr => bridge_dwc_araddr, m_axi_arlen => bridge_dwc_arlen, m_axi_arsize => open,
            m_axi_arburst => bridge_dwc_arburst, m_axi_arlock => open, m_axi_arcache => open, m_axi_arprot => open,
            m_axi_arregion => open, m_axi_arqos => open, m_axi_arvalid => bridge_dwc_arvalid, m_axi_arready => bridge_dwc_arready,
            m_axi_rid => bridge_dwc_rid, m_axi_rdata => bridge_dwc_rdata, m_axi_rresp => bridge_dwc_rresp, m_axi_rlast => bridge_dwc_rlast, m_axi_rvalid => bridge_dwc_rvalid, m_axi_rready => bridge_dwc_rready
        );

    xbar_s_awid    <= "0000" & bridge_dwc_awid;
    xbar_s_awaddr  <= dma_m_awaddr & bridge_dwc_awaddr;
    xbar_s_awlen   <= dma_m_awlen & bridge_dwc_awlen;
    xbar_s_awsize  <= dma_m_awsize & "101";
    xbar_s_awburst <= dma_m_awburst & bridge_dwc_awburst;
    xbar_s_awlock  <= dma_m_awlock & '0';
    xbar_s_awcache <= dma_m_awcache & "0011";
    xbar_s_awprot  <= dma_m_awprot & "000";
    xbar_s_awqos   <= "0000" & "0000";
    xbar_s_awvalid <= dma_m_awvalid & bridge_dwc_awvalid;
    bridge_dwc_awready <= xbar_s_awready(0);
    dma_m_awready      <= xbar_s_awready(1);
    xbar_s_wdata   <= dma_m_wdata & bridge_dwc_wdata;
    xbar_s_wstrb   <= dma_m_wstrb & bridge_dwc_wstrb;
    xbar_s_wlast   <= dma_m_wlast & bridge_dwc_wlast;
    xbar_s_wvalid  <= dma_m_wvalid & bridge_dwc_wvalid;
    bridge_dwc_wready  <= xbar_s_wready(0);
    dma_m_wready       <= xbar_s_wready(1);
    bridge_dwc_bid     <= xbar_s_bid(3 downto 0);
    bridge_dwc_bresp   <= xbar_s_bresp(1 downto 0);
    dma_m_bresp        <= xbar_s_bresp(3 downto 2);
    bridge_dwc_bvalid  <= xbar_s_bvalid(0);
    dma_m_bvalid       <= xbar_s_bvalid(1);
    xbar_s_bready      <= dma_m_bready & bridge_dwc_bready;
    xbar_s_arid    <= "0000" & bridge_dwc_arid;
    xbar_s_araddr  <= dma_m_araddr & bridge_dwc_araddr;
    xbar_s_arlen   <= dma_m_arlen & bridge_dwc_arlen;
    xbar_s_arsize  <= dma_m_arsize & "101";
    xbar_s_arburst <= dma_m_arburst & bridge_dwc_arburst;
    xbar_s_arlock  <= dma_m_arlock & '0';
    xbar_s_arcache <= dma_m_arcache & "0011";
    xbar_s_arprot  <= dma_m_arprot & "000";
    xbar_s_arqos   <= "0000" & "0000";
    xbar_s_arvalid <= dma_m_arvalid & bridge_dwc_arvalid;
    bridge_dwc_arready <= xbar_s_arready(0);
    dma_m_arready      <= xbar_s_arready(1);
    bridge_dwc_rid     <= xbar_s_rid(3 downto 0);
    bridge_dwc_rdata   <= xbar_s_rdata(255 downto 0);
    dma_m_rdata        <= xbar_s_rdata(511 downto 256);
    bridge_dwc_rresp   <= xbar_s_rresp(1 downto 0);
    dma_m_rresp        <= xbar_s_rresp(3 downto 2);
    bridge_dwc_rlast   <= xbar_s_rlast(0);
    dma_m_rlast        <= xbar_s_rlast(1);
    bridge_dwc_rvalid  <= xbar_s_rvalid(0);
    dma_m_rvalid       <= xbar_s_rvalid(1);
    xbar_s_rready      <= dma_m_rready & bridge_dwc_rready;

    u_crossbar : entity work.axi_crossbar_0
        port map (
            aclk => ui_clk, aresetn => ui_rst_n,
            s_axi_awid => xbar_s_awid, s_axi_awaddr => xbar_s_awaddr, s_axi_awlen => xbar_s_awlen, s_axi_awsize => xbar_s_awsize,
            s_axi_awburst => xbar_s_awburst, s_axi_awlock => xbar_s_awlock, s_axi_awcache => xbar_s_awcache, s_axi_awprot => xbar_s_awprot,
            s_axi_awqos => xbar_s_awqos, s_axi_awvalid => xbar_s_awvalid, s_axi_awready => xbar_s_awready,
            s_axi_wdata => xbar_s_wdata, s_axi_wstrb => xbar_s_wstrb, s_axi_wlast => xbar_s_wlast, s_axi_wvalid => xbar_s_wvalid, s_axi_wready => xbar_s_wready,
            s_axi_bid => xbar_s_bid, s_axi_bresp => xbar_s_bresp, s_axi_bvalid => xbar_s_bvalid, s_axi_bready => xbar_s_bready,
            s_axi_arid => xbar_s_arid, s_axi_araddr => xbar_s_araddr, s_axi_arlen => xbar_s_arlen, s_axi_arsize => xbar_s_arsize,
            s_axi_arburst => xbar_s_arburst, s_axi_arlock => xbar_s_arlock, s_axi_arcache => xbar_s_arcache, s_axi_arprot => xbar_s_arprot,
            s_axi_arqos => xbar_s_arqos, s_axi_arvalid => xbar_s_arvalid, s_axi_arready => xbar_s_arready,
            s_axi_rid => xbar_s_rid, s_axi_rdata => xbar_s_rdata, s_axi_rresp => xbar_s_rresp, s_axi_rlast => xbar_s_rlast, s_axi_rvalid => xbar_s_rvalid, s_axi_rready => xbar_s_rready,
            m_axi_awid => xbar_m_awid, m_axi_awaddr => xbar_m_awaddr, m_axi_awlen => xbar_m_awlen, m_axi_awsize => xbar_m_awsize,
            m_axi_awburst => xbar_m_awburst, m_axi_awlock => xbar_m_awlock, m_axi_awcache => xbar_m_awcache, m_axi_awprot => xbar_m_awprot,
            m_axi_awregion => xbar_m_awregion, m_axi_awqos => xbar_m_awqos, m_axi_awvalid => xbar_m_awvalid, m_axi_awready => xbar_m_awready,
            m_axi_wdata => xbar_m_wdata, m_axi_wstrb => xbar_m_wstrb, m_axi_wlast => xbar_m_wlast, m_axi_wvalid => xbar_m_wvalid, m_axi_wready => xbar_m_wready,
            m_axi_bid => xbar_m_bid, m_axi_bresp => xbar_m_bresp, m_axi_bvalid => xbar_m_bvalid, m_axi_bready => xbar_m_bready,
            m_axi_arid => xbar_m_arid, m_axi_araddr => xbar_m_araddr, m_axi_arlen => xbar_m_arlen, m_axi_arsize => xbar_m_arsize,
            m_axi_arburst => xbar_m_arburst, m_axi_arlock => xbar_m_arlock, m_axi_arcache => xbar_m_arcache, m_axi_arprot => xbar_m_arprot,
            m_axi_arregion => xbar_m_arregion, m_axi_arqos => xbar_m_arqos, m_axi_arvalid => xbar_m_arvalid, m_axi_arready => xbar_m_arready,
            m_axi_rid => xbar_m_rid, m_axi_rdata => xbar_m_rdata, m_axi_rresp => xbar_m_rresp, m_axi_rlast => xbar_m_rlast, m_axi_rvalid => xbar_m_rvalid, m_axi_rready => xbar_m_rready
        );

    ddr_awid <= xbar_m_awid(3 downto 0); ddr_awaddr <= xbar_m_awaddr(30 downto 0); ddr_awlen <= xbar_m_awlen(7 downto 0); ddr_awburst <= xbar_m_awburst(1 downto 0); ddr_awvalid <= xbar_m_awvalid(0);
    xbar_m_awready(0) <= ddr_awready; ddr_wdata <= xbar_m_wdata(255 downto 0); ddr_wstrb <= xbar_m_wstrb(31 downto 0); ddr_wlast <= xbar_m_wlast(0); ddr_wvalid <= xbar_m_wvalid(0);
    xbar_m_wready(0) <= ddr_wready; ddr_bid <= xbar_m_bid(3 downto 0); ddr_bresp <= xbar_m_bresp(1 downto 0); ddr_bvalid <= xbar_m_bvalid(0); xbar_m_bready(0) <= ddr_bready;
    ddr_arid <= xbar_m_arid(3 downto 0); ddr_araddr <= xbar_m_araddr(30 downto 0); ddr_arlen <= xbar_m_arlen(7 downto 0); ddr_arburst <= xbar_m_arburst(1 downto 0); ddr_arvalid <= xbar_m_arvalid(0);
    xbar_m_arready(0) <= ddr_arready; xbar_m_rid(3 downto 0) <= ddr_rid; xbar_m_rdata(255 downto 0) <= ddr_rdata; xbar_m_rresp(1 downto 0) <= ddr_rresp; xbar_m_rlast(0) <= ddr_rlast; xbar_m_rvalid(0) <= ddr_rvalid; ddr_rready <= xbar_m_rready(0);

    u_dwidth_down : entity work.axi_dwidth_converter_1
        port map (
            s_axi_aclk => ui_clk, s_axi_aresetn => ui_rst_n,
            s_axi_awid => xbar_m_awid(7 downto 4), s_axi_awaddr => xbar_m_awaddr(63 downto 32), s_axi_awlen => xbar_m_awlen(15 downto 8), s_axi_awsize => "101",
            s_axi_awburst => xbar_m_awburst(3 downto 2), s_axi_awlock => "0", s_axi_awcache => "0011", s_axi_awprot => "000",
            s_axi_awregion => "0000", s_axi_awqos => "0000", s_axi_awvalid => xbar_m_awvalid(1), s_axi_awready => xbar_m_awready(1),
            s_axi_wdata => xbar_m_wdata(511 downto 256), s_axi_wstrb => xbar_m_wstrb(63 downto 32), s_axi_wlast => xbar_m_wlast(1), s_axi_wvalid => xbar_m_wvalid(1), s_axi_wready => xbar_m_wready(1),
            s_axi_bid => xbar_m_bid(7 downto 4), s_axi_bresp => xbar_m_bresp(3 downto 2), s_axi_bvalid => xbar_m_bvalid(1), s_axi_bready => xbar_m_bready(1),
            s_axi_arid => xbar_m_arid(7 downto 4), s_axi_araddr => xbar_m_araddr(63 downto 32), s_axi_arlen => xbar_m_arlen(15 downto 8), s_axi_arsize => "101",
            s_axi_arburst => xbar_m_arburst(3 downto 2), s_axi_arlock => "0", s_axi_arcache => "0011", s_axi_arprot => "000",
            s_axi_arregion => "0000", s_axi_arqos => "0000", s_axi_arvalid => xbar_m_arvalid(1), s_axi_arready => xbar_m_arready(1),
            s_axi_rid => xbar_m_rid(7 downto 4), s_axi_rdata => xbar_m_rdata(511 downto 256), s_axi_rresp => xbar_m_rresp(3 downto 2), s_axi_rlast => xbar_m_rlast(1), s_axi_rvalid => xbar_m_rvalid(1), s_axi_rready => xbar_m_rready(1),
            m_axi_awaddr => bridge_awaddr_dma, m_axi_awvalid => dma_s_awvalid, m_axi_awready => dma_s_awready, m_axi_wdata => dma_s_wdata,
            m_axi_wstrb => dma_s_wstrb, m_axi_wvalid => dma_s_wvalid, m_axi_wready => dma_s_wready, m_axi_bresp => dma_s_bresp, m_axi_bvalid => dma_s_bvalid,
            m_axi_bready => dma_s_bready, m_axi_araddr => bridge_araddr_dma, m_axi_arvalid => dma_s_arvalid, m_axi_arready => dma_s_arready,
            m_axi_rdata => dma_s_rdata, m_axi_rresp => dma_s_rresp, m_axi_rvalid => dma_s_rvalid, m_axi_rready => dma_s_rready
        );

    dma_s_awaddr <= bridge_awaddr_dma(3 downto 0); dma_s_araddr <= bridge_araddr_dma(3 downto 0);
    div_led_inst : entity work.async_div generic map ( STAGES => 28 ) port map ( clk_in => clk_100, clk_out => done_led );
    done_led_n <= not done_led;
    STARTUPE2_inst : STARTUPE2 generic map ( PROG_USR => "FALSE", SIM_CCLK_FREQ => 0.0 )
	port map ( CFGCLK => clk_cfg, CFGMCLK => clk_cfgm, EOS => open, PREQ => open, CLK => '0', GSR => '0', GTS => '0', KEYCLEARB => '0', PACK => '0', USRCCLKO => '0', USRCCLKTS => '0', USRDONEO => '0', USRDONETS => done_led_n );
    led(0) <= not key(0); led(2) <= dma_busy; led(3) <= not key(3);
end RTL;
