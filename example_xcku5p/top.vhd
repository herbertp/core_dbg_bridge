----------------------------------------------------------------------------
--  top.vhd
--	XCKU5P simple VHDL example
--	Version 1.2 - DMA and SmartConnect
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
    signal dma_m_awburst : std_logic_vector(1 downto 0);
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
    signal dma_m_arburst : std_logic_vector(1 downto 0);
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

    -- Internal signals for dummy address ports
    signal bridge_awaddr_dma : std_logic_vector(31 downto 0);
    signal bridge_araddr_dma : std_logic_vector(31 downto 0);

begin

    --------------------------------------------------------------------
    -- DDR4 IP Instance
    --------------------------------------------------------------------

    ddr_rst <= not key(1); -- Active-high reset for DDR4 IP

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
            c0_ddr4_s_axi_awsize   => "101", -- 32 bytes (256-bit)
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
            c0_ddr4_s_axi_arsize   => "101", -- 32 bytes (256-bit)
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
        generic map (
            CLK_FREQ     => 100000000,
            UART_SPEED   => 115200
        )
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
            clk_i          => ui_clk,
            rst_i          => ui_rst,

            -- Slave Config
            s_axi_awaddr   => dma_s_awaddr,
            s_axi_awvalid  => dma_s_awvalid,
            s_axi_awready  => dma_s_awready,
            s_axi_wdata    => dma_s_wdata,
            s_axi_wstrb    => dma_s_wstrb,
            s_axi_wvalid   => dma_s_wvalid,
            s_axi_wready   => dma_s_wready,
            s_axi_bresp    => dma_s_bresp,
            s_axi_bvalid   => dma_s_bvalid,
            s_axi_bready   => dma_s_bready,
            s_axi_araddr   => dma_s_araddr,
            s_axi_arvalid  => dma_s_arvalid,
            s_axi_arready  => dma_s_arready,
            s_axi_rdata    => dma_s_rdata,
            s_axi_rresp    => dma_s_rresp,
            s_axi_rvalid   => dma_s_rvalid,
            s_axi_rready   => dma_s_rready,

            -- Master Data
            m_axi_awaddr   => dma_m_awaddr,
            m_axi_awlen    => dma_m_awlen,
            m_axi_awsize   => open,
            m_axi_awburst  => dma_m_awburst,
            m_axi_awlock   => open,
            m_axi_awcache  => open,
            m_axi_awprot   => open,
            m_axi_awvalid  => dma_m_awvalid,
            m_axi_awready  => dma_m_awready,
            m_axi_wdata    => dma_m_wdata,
            m_axi_wstrb    => dma_m_wstrb,
            m_axi_wlast    => dma_m_wlast,
            m_axi_wvalid   => dma_m_wvalid,
            m_axi_wready   => dma_m_wready,
            m_axi_bresp    => dma_m_bresp,
            m_axi_bvalid   => dma_m_bvalid,
            m_axi_bready   => dma_m_bready,
            m_axi_araddr   => dma_m_araddr,
            m_axi_arlen    => dma_m_arlen,
            m_axi_arsize   => open,
            m_axi_arburst  => dma_m_arburst,
            m_axi_arlock   => open,
            m_axi_arcache  => open,
            m_axi_arprot   => open,
            m_axi_arvalid  => dma_m_arvalid,
            m_axi_arready  => dma_m_arready,
            m_axi_rdata    => dma_m_rdata,
            m_axi_rresp    => dma_m_rresp,
            m_axi_rlast    => dma_m_rlast,
            m_axi_rvalid   => dma_m_rvalid,
            m_axi_rready   => dma_m_rready,

            busy_o         => dma_busy
        );

    --------------------------------------------------------------------
    -- AXI SmartConnect
    --------------------------------------------------------------------

    rst_100_n <= not rst_i;

    u_smartconnect : entity work.axi_smartconnect_0
        port map (
            aclk          => ui_clk,
            aresetn       => ui_rst_n,

            -- S00: Bridge (100MHz)
            s00_axi_aclk    => clk_100,
            s00_axi_aresetn => rst_100_n,
            s00_axi_awid    => bridge_awid,
            s00_axi_awaddr  => bridge_awaddr,
            s00_axi_awlen   => bridge_awlen,
            s00_axi_awsize  => "010", -- 4 bytes
            s00_axi_awburst => bridge_awburst,
            s00_axi_awlock  => "0",
            s00_axi_awcache => "0011",
            s00_axi_awprot  => "000",
            s00_axi_awqos   => "0000",
            s00_axi_awvalid => bridge_awvalid,
            s00_axi_awready => bridge_awready,
            s00_axi_wdata   => bridge_wdata,
            s00_axi_wstrb   => bridge_wstrb,
            s00_axi_wlast   => bridge_wlast,
            s00_axi_wvalid  => bridge_wvalid,
            s00_axi_wready  => bridge_wready,
            s00_axi_bid     => bridge_bid,
            s00_axi_bresp   => bridge_bresp,
            s00_axi_bvalid  => bridge_bvalid,
            s00_axi_bready  => bridge_bready,
            s00_axi_arid    => bridge_arid,
            s00_axi_araddr  => bridge_araddr,
            s00_axi_arlen   => bridge_arlen,
            s00_axi_arsize  => "010",
            s00_axi_arburst => bridge_arburst,
            s00_axi_arlock  => "0",
            s00_axi_arcache => "0011",
            s00_axi_arprot  => "000",
            s00_axi_arqos   => "0000",
            s00_axi_arvalid => bridge_arvalid,
            s00_axi_arready => bridge_arready,
            s00_axi_rid     => bridge_rid,
            s00_axi_rdata   => bridge_rdata,
            s00_axi_rresp   => bridge_rresp,
            s00_axi_rlast   => bridge_rlast,
            s00_axi_rvalid  => bridge_rvalid,
            s00_axi_rready  => bridge_rready,

            -- S01: DMA Master (UI clk)
            s01_axi_awaddr  => dma_m_awaddr,
            s01_axi_awlen   => dma_m_awlen,
            s01_axi_awsize  => "101", -- 32 bytes
            s01_axi_awburst => dma_m_awburst,
            s01_axi_awlock  => "0",
            s01_axi_awcache => "0011",
            s01_axi_awprot  => "000",
            s01_axi_awqos   => "0000",
            s01_axi_awvalid => dma_m_awvalid,
            s01_axi_awready => dma_m_awready,
            s01_axi_wdata   => dma_m_wdata,
            s01_axi_wstrb   => dma_m_wstrb,
            s01_axi_wlast   => dma_m_wlast,
            s01_axi_wvalid  => dma_m_wvalid,
            s01_axi_wready  => dma_m_wready,
            s01_axi_bresp   => dma_m_bresp,
            s01_axi_bvalid  => dma_m_bvalid,
            s01_axi_bready  => dma_m_bready,
            s01_axi_araddr  => dma_m_araddr,
            s01_axi_arlen   => dma_m_arlen,
            s01_axi_arsize  => "101",
            s01_axi_arburst => dma_m_arburst,
            s01_axi_arlock  => "0",
            s01_axi_arcache => "0011",
            s01_axi_arprot  => "000",
            s01_axi_arqos   => "0000",
            s01_axi_arvalid => dma_m_arvalid,
            s01_axi_arready => dma_m_arready,
            s01_axi_rdata   => dma_m_rdata,
            s01_axi_rresp   => dma_m_rresp,
            s01_axi_rlast   => dma_m_rlast,
            s01_axi_rvalid  => dma_m_rvalid,
            s01_axi_rready  => dma_m_rready,

            -- M00: DDR4
            m00_axi_awid    => ddr_awid,
            m00_axi_awaddr  => ddr_awaddr,
            m00_axi_awlen   => ddr_awlen,
            m00_axi_awsize  => open,
            m00_axi_awburst => ddr_awburst,
            m00_axi_awlock  => open,
            m00_axi_awcache => open,
            m00_axi_awprot  => open,
            m00_axi_awregion => open,
            m00_axi_awqos   => open,
            m00_axi_awvalid => ddr_awvalid,
            m00_axi_awready => ddr_awready,
            m00_axi_wdata   => ddr_wdata,
            m00_axi_wstrb   => ddr_wstrb,
            m00_axi_wlast   => ddr_wlast,
            m00_axi_wvalid  => ddr_wvalid,
            m00_axi_wready  => ddr_wready,
            m00_axi_bid     => ddr_bid,
            m00_axi_bresp   => ddr_bresp,
            m00_axi_bvalid  => ddr_bvalid,
            m00_axi_bready  => ddr_bready,
            m00_axi_arid    => ddr_arid,
            m00_axi_araddr  => ddr_araddr,
            m00_axi_arlen   => ddr_arlen,
            m00_axi_arsize  => open,
            m00_axi_arburst => ddr_arburst,
            m00_axi_arlock  => open,
            m00_axi_arcache => open,
            m00_axi_arprot  => open,
            m00_axi_arregion => open,
            m00_axi_arqos   => open,
            m00_axi_arvalid => ddr_arvalid,
            m00_axi_arready => ddr_arready,
            m00_axi_rid     => ddr_rid,
            m00_axi_rdata   => ddr_rdata,
            m00_axi_rresp   => ddr_rresp,
            m00_axi_rlast   => ddr_rlast,
            m00_axi_rvalid  => ddr_rvalid,
            m00_axi_rready  => ddr_rready,

            -- M01: DMA Config
            m01_axi_awaddr  => bridge_awaddr_dma,
            m01_axi_awvalid => dma_s_awvalid,
            m01_axi_awready => dma_s_awready,
            m01_axi_wdata   => dma_s_wdata,
            m01_axi_wstrb   => dma_s_wstrb,
            m01_axi_wvalid  => dma_s_wvalid,
            m01_axi_wready  => dma_s_wready,
            m01_axi_bresp   => dma_s_bresp,
            m01_axi_bvalid  => dma_s_bvalid,
            m01_axi_bready  => dma_s_bready,
            m01_axi_araddr  => bridge_araddr_dma,
            m01_axi_arvalid => dma_s_arvalid,
            m01_axi_arready => dma_s_arready,
            m01_axi_rdata   => dma_s_rdata,
            m01_axi_rresp   => dma_s_rresp,
            m01_axi_rvalid  => dma_s_rvalid,
            m01_axi_rready  => dma_s_rready
        );

    -- SmartConnect output addresses are full width, we only need lower bits for DMA config
    dma_s_awaddr <= bridge_awaddr_dma(3 downto 0);
    dma_s_araddr <= bridge_araddr_dma(3 downto 0);

    --------------------------------------------------------------------
    -- Blinking DONE LED
    --------------------------------------------------------------------

    div_led_inst : entity work.async_div
	generic map (
	    STAGES => 28 )
	port map (
	    clk_in => clk_100,
	    clk_out => done_led );

    done_led_n <= not done_led;

    STARTUPE2_inst : STARTUPE2
	generic map (
	    PROG_USR => "FALSE",	-- Program event security feature.
	    SIM_CCLK_FREQ => 0.0 )	-- Configuration Clock Frequency(ns)
	port map (
	    CFGCLK => clk_cfg,		-- 1-bit output: Configuration main clock output
	    CFGMCLK => clk_cfgm,	-- 1-bit output: Configuration internal oscillator clock output
	    EOS => open,		-- 1-bit output: Active high output signal indicating the End Of Startup.
	    PREQ => open,		-- 1-bit output: PROGRAM request to fabric output
	    CLK => '0',			-- 1-bit input: User start-up clock input
	    GSR => '0',			-- 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
	    GTS => '0',			-- 1-bit input: Global 3-state input (GTS cannot be used for the port name)
	    KEYCLEARB => '0',		-- 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
	    PACK => '0',		-- 1-bit input: PROGRAM acknowledge input
	    USRCCLKO => '0',		-- 1-bit input: User CCLK input
	    USRCCLKTS => '0',		-- 1-bit input: User CCLK 3-state enable input
	    USRDONEO => '0',		-- 1-bit input: User DONE pin output control
	    USRDONETS => done_led_n );	-- 1-bit input: User DONE 3-state enable output

    -- Default values for other LEDs
    led(0) <= not key(0);
    led(2) <= dma_busy;
    led(3) <= not key(3);

end RTL;
