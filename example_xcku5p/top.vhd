----------------------------------------------------------------------------
--  top.vhd
--	XCKU5P simple VHDL example
--	Version 1.2 - DDR4 Support with CDMA
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
    -- AXI Bus Signals (Bridge 32-bit, 100MHz)
    --------------------------------------------------------------------

    signal bridge_awaddr  : std_logic_vector(31 downto 0);
    signal bridge_awvalid : std_logic;
    signal bridge_awready : std_logic;
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

    signal bridge_araddr  : std_logic_vector(31 downto 0);
    signal bridge_arvalid : std_logic;
    signal bridge_arready : std_logic;
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
    -- AXI Clock Converter (100 -> UI, 32-bit)
    --------------------------------------------------------------------

    signal cc_awaddr  : std_logic_vector(31 downto 0);
    signal cc_awvalid : std_logic;
    signal cc_awready : std_logic;
    signal cc_awid    : std_logic_vector(3 downto 0);
    signal cc_awlen   : std_logic_vector(7 downto 0);
    signal cc_awburst : std_logic_vector(1 downto 0);

    signal cc_wvalid  : std_logic;
    signal cc_wready  : std_logic;
    signal cc_wdata   : std_logic_vector(31 downto 0);
    signal cc_wstrb   : std_logic_vector(3 downto 0);
    signal cc_wlast   : std_logic;

    signal cc_bvalid  : std_logic;
    signal cc_bready  : std_logic;
    signal cc_bresp   : std_logic_vector(1 downto 0);
    signal cc_bid     : std_logic_vector(3 downto 0);

    signal cc_araddr  : std_logic_vector(31 downto 0);
    signal cc_arvalid : std_logic;
    signal cc_arready : std_logic;
    signal cc_arid    : std_logic_vector(3 downto 0);
    signal cc_arlen   : std_logic_vector(7 downto 0);
    signal cc_arburst : std_logic_vector(1 downto 0);

    signal cc_rvalid  : std_logic;
    signal cc_rready  : std_logic;
    signal cc_rdata   : std_logic_vector(31 downto 0);
    signal cc_rresp   : std_logic_vector(1 downto 0);
    signal cc_rid     : std_logic_vector(3 downto 0);
    signal cc_rlast   : std_logic;

    --------------------------------------------------------------------
    -- AXI Crossbar 0 (Splitter: Bridge -> DDR4 or CDMA)
    --------------------------------------------------------------------

    -- M00: to DDR4 Path (32-bit, UI)
    signal x0_m00_awaddr  : std_logic_vector(31 downto 0);
    signal x0_m00_awvalid : std_logic;
    signal x0_m00_awready : std_logic;
    signal x0_m00_awid    : std_logic_vector(3 downto 0);
    signal x0_m00_awlen   : std_logic_vector(7 downto 0);
    signal x0_m00_awburst : std_logic_vector(1 downto 0);

    signal x0_m00_wvalid  : std_logic;
    signal x0_m00_wready  : std_logic;
    signal x0_m00_wdata   : std_logic_vector(31 downto 0);
    signal x0_m00_wstrb   : std_logic_vector(3 downto 0);
    signal x0_m00_wlast   : std_logic;

    signal x0_m00_bvalid  : std_logic;
    signal x0_m00_bready  : std_logic;
    signal x0_m00_bresp   : std_logic_vector(1 downto 0);
    signal x0_m00_bid     : std_logic_vector(3 downto 0);

    signal x0_m00_araddr  : std_logic_vector(31 downto 0);
    signal x0_m00_arvalid : std_logic;
    signal x0_m00_arready : std_logic;
    signal x0_m00_arid    : std_logic_vector(3 downto 0);
    signal x0_m00_arlen   : std_logic_vector(7 downto 0);
    signal x0_m00_arburst : std_logic_vector(1 downto 0);

    signal x0_m00_rvalid  : std_logic;
    signal x0_m00_rready : std_logic;
    signal x0_m00_rdata   : std_logic_vector(31 downto 0);
    signal x0_m00_rresp   : std_logic_vector(1 downto 0);
    signal x0_m00_rid     : std_logic_vector(3 downto 0);
    signal x0_m00_rlast   : std_logic;

    -- M01: to CDMA Path (32-bit, UI)
    signal x0_m01_awaddr  : std_logic_vector(31 downto 0);
    signal x0_m01_awvalid : std_logic;
    signal x0_m01_awready : std_logic;
    signal x0_m01_awid    : std_logic_vector(3 downto 0);
    signal x0_m01_awlen   : std_logic_vector(7 downto 0);
    signal x0_m01_awburst : std_logic_vector(1 downto 0);

    signal x0_m01_wvalid  : std_logic;
    signal x0_m01_wready  : std_logic;
    signal x0_m01_wdata   : std_logic_vector(31 downto 0);
    signal x0_m01_wstrb   : std_logic_vector(3 downto 0);
    signal x0_m01_wlast   : std_logic;

    signal x0_m01_bvalid  : std_logic;
    signal x0_m01_bready  : std_logic;
    signal x0_m01_bresp   : std_logic_vector(1 downto 0);
    signal x0_m01_bid     : std_logic_vector(3 downto 0);

    signal x0_m01_araddr  : std_logic_vector(31 downto 0);
    signal x0_m01_arvalid : std_logic;
    signal x0_m01_arready : std_logic;
    signal x0_m01_arid    : std_logic_vector(3 downto 0);
    signal x0_m01_arlen   : std_logic_vector(7 downto 0);
    signal x0_m01_arburst : std_logic_vector(1 downto 0);

    signal x0_m01_rvalid  : std_logic;
    signal x0_m01_rready  : std_logic;
    signal x0_m01_rdata   : std_logic_vector(31 downto 0);
    signal x0_m01_rresp   : std_logic_vector(1 downto 0);
    signal x0_m01_rid     : std_logic_vector(3 downto 0);
    signal x0_m01_rlast   : std_logic;

    --------------------------------------------------------------------
    -- AXI Protocol Converter (AXI4 -> AXI4Lite)
    --------------------------------------------------------------------

    signal prot_awaddr  : std_logic_vector(31 downto 0);
    signal prot_awvalid : std_logic;
    signal prot_awready : std_logic;
    signal prot_wvalid  : std_logic;
    signal prot_wready  : std_logic;
    signal prot_wdata   : std_logic_vector(31 downto 0);
    signal prot_wstrb   : std_logic_vector(3 downto 0);
    signal prot_bvalid  : std_logic;
    signal prot_bready  : std_logic;
    signal prot_bresp   : std_logic_vector(1 downto 0);
    signal prot_araddr  : std_logic_vector(31 downto 0);
    signal prot_arvalid : std_logic;
    signal prot_arready : std_logic;
    signal prot_rvalid  : std_logic;
    signal prot_rready  : std_logic;
    signal prot_rdata   : std_logic_vector(31 downto 0);
    signal prot_rresp   : std_logic_vector(1 downto 0);

    --------------------------------------------------------------------
    -- AXI Data Width Conversion (32 -> 256)
    --------------------------------------------------------------------

    signal dwc_awvalid : std_logic;
    signal dwc_awready : std_logic;
    signal dwc_awaddr  : std_logic_vector(30 downto 0);
    signal dwc_awid    : std_logic_vector(3 downto 0);
    signal dwc_awlen   : std_logic_vector(7 downto 0);
    signal dwc_awburst : std_logic_vector(1 downto 0);

    signal dwc_wvalid  : std_logic;
    signal dwc_wready  : std_logic;
    signal dwc_wdata   : std_logic_vector(255 downto 0);
    signal dwc_wstrb   : std_logic_vector(31 downto 0);
    signal dwc_wlast   : std_logic;

    signal dwc_bvalid  : std_logic;
    signal dwc_bready  : std_logic;
    signal dwc_bresp   : std_logic_vector(1 downto 0);
    signal dwc_bid     : std_logic_vector(3 downto 0);

    signal dwc_arvalid : std_logic;
    signal dwc_arready : std_logic;
    signal dwc_araddr  : std_logic_vector(30 downto 0);
    signal dwc_arid    : std_logic_vector(3 downto 0);
    signal dwc_arlen   : std_logic_vector(7 downto 0);
    signal dwc_arburst : std_logic_vector(1 downto 0);

    signal dwc_rvalid  : std_logic;
    signal dwc_rready  : std_logic;
    signal dwc_rdata   : std_logic_vector(255 downto 0);
    signal dwc_rresp   : std_logic_vector(1 downto 0);
    signal dwc_rid     : std_logic_vector(3 downto 0);
    signal dwc_rlast   : std_logic;

    --------------------------------------------------------------------
    -- AXI CDMA Master (256-bit, UI)
    --------------------------------------------------------------------

    signal cdma_awaddr  : std_logic_vector(31 downto 0);
    signal cdma_awvalid : std_logic;
    signal cdma_awready : std_logic;
    signal cdma_awlen   : std_logic_vector(7 downto 0);
    signal cdma_awsize  : std_logic_vector(2 downto 0);
    signal cdma_awburst : std_logic_vector(1 downto 0);
    signal cdma_awprot  : std_logic_vector(2 downto 0);
    signal cdma_awcache : std_logic_vector(3 downto 0);

    signal cdma_wvalid  : std_logic;
    signal cdma_wready  : std_logic;
    signal cdma_wdata   : std_logic_vector(255 downto 0);
    signal cdma_wstrb   : std_logic_vector(31 downto 0);
    signal cdma_wlast   : std_logic;

    signal cdma_bvalid  : std_logic;
    signal cdma_bready  : std_logic;
    signal cdma_bresp   : std_logic_vector(1 downto 0);

    signal cdma_araddr  : std_logic_vector(31 downto 0);
    signal cdma_arvalid : std_logic;
    signal cdma_arready : std_logic;
    signal cdma_arlen   : std_logic_vector(7 downto 0);
    signal cdma_arsize  : std_logic_vector(2 downto 0);
    signal cdma_arburst : std_logic_vector(1 downto 0);
    signal cdma_arprot  : std_logic_vector(2 downto 0);
    signal cdma_arcache : std_logic_vector(3 downto 0);

    signal cdma_rvalid  : std_logic;
    signal cdma_rready  : std_logic;
    signal cdma_rdata   : std_logic_vector(255 downto 0);
    signal cdma_rresp   : std_logic_vector(1 downto 0);
    signal cdma_rlast   : std_logic;

    --------------------------------------------------------------------
    -- AXI Interconnect (Merger: Bridge & CDMA -> DDR4, 256-bit)
    --------------------------------------------------------------------

    signal m_awvalid : std_logic;
    signal m_awready : std_logic;
    signal m_awaddr  : std_logic_vector(30 downto 0);
    signal m_awid    : std_logic_vector(4 downto 0);
    signal m_awlen   : std_logic_vector(7 downto 0);
    signal m_awburst : std_logic_vector(1 downto 0);

    signal m_wvalid  : std_logic;
    signal m_wready  : std_logic;
    signal m_wdata   : std_logic_vector(255 downto 0);
    signal m_wstrb   : std_logic_vector(31 downto 0);
    signal m_wlast   : std_logic;

    signal m_bvalid  : std_logic;
    signal m_bready  : std_logic;
    signal m_bresp   : std_logic_vector(1 downto 0);
    signal m_bid     : std_logic_vector(4 downto 0);

    signal m_arvalid : std_logic;
    signal m_arready : std_logic;
    signal m_araddr  : std_logic_vector(30 downto 0);
    signal m_arid    : std_logic_vector(4 downto 0);
    signal m_arlen   : std_logic_vector(7 downto 0);
    signal m_arburst : std_logic_vector(1 downto 0);

    signal m_rvalid  : std_logic;
    signal m_rready  : std_logic;
    signal m_rdata   : std_logic_vector(255 downto 0);
    signal m_rresp   : std_logic_vector(1 downto 0);
    signal m_rid     : std_logic_vector(4 downto 0);
    signal m_rlast   : std_logic;


    signal rst_i : std_logic;
    signal ddr_rst : std_logic;
    signal ui_clk : std_logic;
    signal ui_rst : std_logic;
    signal ui_rst_n : std_logic;
    signal rst_100_n : std_logic;

    signal calib_complete : std_logic;

    -- CDMA activity status for LED(2)
    signal cdma_active : std_logic;
    signal cdma_active_cnt : unsigned(23 downto 0);

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

            c0_ddr4_s_axi_awid     => m_awid,
            c0_ddr4_s_axi_awaddr   => m_awaddr,
            c0_ddr4_s_axi_awlen    => m_awlen,
            c0_ddr4_s_axi_awsize   => "101", -- 32 bytes (256-bit)
            c0_ddr4_s_axi_awburst  => m_awburst,
            c0_ddr4_s_axi_awlock   => "0",
            c0_ddr4_s_axi_awcache  => "0011",
            c0_ddr4_s_axi_awprot   => "000",
            c0_ddr4_s_axi_awqos    => "0000",
            c0_ddr4_s_axi_awvalid  => m_awvalid,
            c0_ddr4_s_axi_awready  => m_awready,
            c0_ddr4_s_axi_wdata    => m_wdata,
            c0_ddr4_s_axi_wstrb    => m_wstrb,
            c0_ddr4_s_axi_wlast    => m_wlast,
            c0_ddr4_s_axi_wvalid   => m_wvalid,
            c0_ddr4_s_axi_wready   => m_wready,
            c0_ddr4_s_axi_bid      => m_bid,
            c0_ddr4_s_axi_bresp    => m_bresp,
            c0_ddr4_s_axi_bvalid   => m_bvalid,
            c0_ddr4_s_axi_bready   => m_bready,
            c0_ddr4_s_axi_arid     => m_arid,
            c0_ddr4_s_axi_araddr   => m_araddr,
            c0_ddr4_s_axi_arlen    => m_arlen,
            c0_ddr4_s_axi_arsize   => "101", -- 32 bytes (256-bit)
            c0_ddr4_s_axi_arburst  => m_arburst,
            c0_ddr4_s_axi_arlock   => "0",
            c0_ddr4_s_axi_arcache  => "0011",
            c0_ddr4_s_axi_arprot   => "000",
            c0_ddr4_s_axi_arqos    => "0000",
            c0_ddr4_s_axi_arvalid  => m_arvalid,
            c0_ddr4_s_axi_arready  => m_arready,
            c0_ddr4_s_axi_rid      => m_rid,
            c0_ddr4_s_axi_rdata    => m_rdata,
            c0_ddr4_s_axi_rresp    => m_rresp,
            c0_ddr4_s_axi_rlast    => m_rlast,
            c0_ddr4_s_axi_rvalid   => m_rvalid,
            c0_ddr4_s_axi_rready   => m_rready
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
    -- AXI Clock Converter (Bridge 100M -> UI, 32-bit)
    --------------------------------------------------------------------

    rst_100_n <= not rst_i;

    u_clk_conv : entity work.axi_clock_converter_0
        port map (
            s_axi_aclk    => clk_100,
            s_axi_aresetn => rst_100_n,
            s_axi_awid    => bridge_awid,
            s_axi_awaddr  => bridge_awaddr,
            s_axi_awlen   => bridge_awlen,
            s_axi_awsize  => "010", -- 4 bytes (32-bit)
            s_axi_awburst => bridge_awburst,
            s_axi_awlock  => "0",
            s_axi_awcache => "0011",
            s_axi_awprot  => "000",
            s_axi_awregion => "0000",
            s_axi_awqos    => "0000",
            s_axi_awvalid => bridge_awvalid,
            s_axi_awready => bridge_awready,
            s_axi_wdata   => bridge_wdata,
            s_axi_wstrb   => bridge_wstrb,
            s_axi_wlast   => bridge_wlast,
            s_axi_wvalid  => bridge_wvalid,
            s_axi_wready  => bridge_wready,
            s_axi_bid     => bridge_bid,
            s_axi_bresp   => bridge_bresp,
            s_axi_bvalid  => bridge_bvalid,
            s_axi_bready  => bridge_bready,
            s_axi_arid    => bridge_arid,
            s_axi_araddr  => bridge_araddr,
            s_axi_arlen   => bridge_arlen,
            s_axi_arsize  => "010", -- 4 bytes (32-bit)
            s_axi_arburst => bridge_arburst,
            s_axi_arlock  => "0",
            s_axi_arcache => "0011",
            s_axi_arprot  => "000",
            s_axi_arregion => "0000",
            s_axi_arqos    => "0000",
            s_axi_arvalid => bridge_arvalid,
            s_axi_arready => bridge_arready,
            s_axi_rid     => bridge_rid,
            s_axi_rdata   => bridge_rdata,
            s_axi_rresp   => bridge_rresp,
            s_axi_rlast   => bridge_rlast,
            s_axi_rvalid  => bridge_rvalid,
            s_axi_rready  => bridge_rready,

            m_axi_aclk    => ui_clk,
            m_axi_aresetn => ui_rst_n,
            m_axi_awid    => cc_awid,
            m_axi_awaddr  => cc_awaddr,
            m_axi_awlen   => cc_awlen,
            m_axi_awsize  => open,
            m_axi_awburst => cc_awburst,
            m_axi_awlock  => open,
            m_axi_awcache => open,
            m_axi_awprot  => open,
            m_axi_awregion => open,
            m_axi_awqos    => open,
            m_axi_awvalid => cc_awvalid,
            m_axi_awready => cc_awready,
            m_axi_wdata   => cc_wdata,
            m_axi_wstrb   => cc_wstrb,
            m_axi_wlast   => cc_wlast,
            m_axi_wvalid  => cc_wvalid,
            m_axi_wready  => cc_wready,
            m_axi_bid     => cc_bid,
            m_axi_bresp   => cc_bresp,
            m_axi_bvalid  => cc_bvalid,
            m_axi_bready  => cc_bready,
            m_axi_arid    => cc_arid,
            m_axi_araddr  => cc_araddr,
            m_axi_arlen   => cc_arlen,
            m_axi_arsize  => open,
            m_axi_arburst => cc_arburst,
            m_axi_arlock  => open,
            m_axi_arcache => open,
            m_axi_arprot  => open,
            m_axi_arregion => open,
            m_axi_arqos    => open,
            m_axi_arvalid => cc_arvalid,
            m_axi_arready => cc_arready,
            m_axi_rid     => cc_rid,
            m_axi_rdata   => cc_rdata,
            m_axi_rresp   => cc_rresp,
            m_axi_rlast   => cc_rlast,
            m_axi_rvalid  => cc_rvalid,
            m_axi_rready  => cc_rready
        );

    --------------------------------------------------------------------
    -- AXI Crossbar 0 (Splitter: Bridge -> DDR4 or CDMA)
    --------------------------------------------------------------------

    u_xbar_splitter : entity work.axi_crossbar_0
        port map (
            aclk          => ui_clk,
            aresetn       => ui_rst_n,

            s_axi_awid(3 downto 0) => cc_awid,
            s_axi_awaddr  => cc_awaddr,
            s_axi_awlen   => cc_awlen,
            s_axi_awsize  => "010",
            s_axi_awburst => cc_awburst,
            s_axi_awlock(0) => '0',
            s_axi_awcache => "0011",
            s_axi_awprot  => "000",
            s_axi_awqos   => "0000",
            s_axi_awvalid(0) => cc_awvalid,
            s_axi_awready(0) => cc_awready,
            s_axi_wdata   => cc_wdata,
            s_axi_wstrb   => cc_wstrb,
            s_axi_wlast(0) => cc_wlast,
            s_axi_wvalid(0) => cc_wvalid,
            s_axi_wready(0) => cc_wready,
            s_axi_bid     => cc_bid,
            s_axi_bresp   => cc_bresp,
            s_axi_bvalid(0) => cc_bvalid,
            s_axi_bready(0) => cc_bready,
            s_axi_arid(3 downto 0) => cc_arid,
            s_axi_araddr  => cc_araddr,
            s_axi_arlen   => cc_arlen,
            s_axi_arsize  => "010",
            s_axi_arburst => cc_arburst,
            s_axi_arlock(0) => '0',
            s_axi_arcache => "0011",
            s_axi_arqos   => "0000",
            s_axi_arprot  => "000",
            s_axi_arvalid(0) => cc_arvalid,
            s_axi_arready(0) => cc_arready,
            s_axi_rid     => cc_rid,
            s_axi_rdata   => cc_rdata,
            s_axi_rresp   => cc_rresp,
            s_axi_rlast(0) => cc_rlast,
            s_axi_rvalid(0) => cc_rvalid,
            s_axi_rready(0) => cc_rready,

            m_axi_awid(7 downto 4)     => x0_m01_awid,
            m_axi_awid(3 downto 0)     => x0_m00_awid,
            m_axi_awaddr(63 downto 32) => x0_m01_awaddr,
            m_axi_awaddr(31 downto 0)  => x0_m00_awaddr,
            m_axi_awlen(15 downto 8)   => x0_m01_awlen,
            m_axi_awlen(7 downto 0)    => x0_m00_awlen,
            m_axi_awsize  => open,
            m_axi_awburst(3 downto 2)  => x0_m01_awburst,
            m_axi_awburst(1 downto 0)  => x0_m00_awburst,
            m_axi_awlock  => open,
            m_axi_awcache => open,
            m_axi_awprot  => open,
            m_axi_awregion => open,
            m_axi_awqos    => open,
            m_axi_awvalid(1) => x0_m01_awvalid,
            m_axi_awvalid(0) => x0_m00_awvalid,
            m_axi_awready(1) => x0_m01_awready,
            m_axi_awready(0) => x0_m00_awready,
            m_axi_wdata(63 downto 32)  => x0_m01_wdata,
            m_axi_wdata(31 downto 0)   => x0_m00_wdata,
            m_axi_wstrb(7 downto 4)    => x0_m01_wstrb,
            m_axi_wstrb(3 downto 0)    => x0_m00_wstrb,
            m_axi_wlast(1) => x0_m01_wlast,
            m_axi_wlast(0) => x0_m00_wlast,
            m_axi_wvalid(1) => x0_m01_wvalid,
            m_axi_wvalid(0) => x0_m00_wvalid,
            m_axi_wready(1) => x0_m01_wready,
            m_axi_wready(0) => x0_m00_wready,
            m_axi_bid(7 downto 4)      => x0_m01_bid,
            m_axi_bid(3 downto 0)      => x0_m00_bid,
            m_axi_bresp(3 downto 2)    => x0_m01_bresp,
            m_axi_bresp(1 downto 0)    => x0_m00_bresp,
            m_axi_bvalid(1) => x0_m01_bvalid,
            m_axi_bvalid(0) => x0_m00_bvalid,
            m_axi_bready(1) => x0_m01_bready,
            m_axi_bready(0) => x0_m00_bready,
            m_axi_arid(7 downto 4)     => x0_m01_arid,
            m_axi_arid(3 downto 0)     => x0_m00_arid,
            m_axi_araddr(63 downto 32) => x0_m01_araddr,
            m_axi_araddr(31 downto 0)  => x0_m00_araddr,
            m_axi_arlen(15 downto 8)   => x0_m01_arlen,
            m_axi_arlen(7 downto 0)    => x0_m00_arlen,
            m_axi_arsize  => open,
            m_axi_arburst(3 downto 2)  => x0_m01_arburst,
            m_axi_arburst(1 downto 0)  => x0_m00_arburst,
            m_axi_arlock  => open,
            m_axi_arcache => open,
            m_axi_arprot  => open,
            m_axi_arregion => open,
            m_axi_arqos    => open,
            m_axi_arvalid(1) => x0_m01_arvalid,
            m_axi_arvalid(0) => x0_m00_arvalid,
            m_axi_arready(1) => x0_m01_arready,
            m_axi_arready(0) => x0_m00_arready,
            m_axi_rid(7 downto 4)      => x0_m01_rid,
            m_axi_rid(3 downto 0)      => x0_m00_rid,
            m_axi_rdata(63 downto 32)  => x0_m01_rdata,
            m_axi_rdata(31 downto 0)   => x0_m00_rdata,
            m_axi_rresp(3 downto 2)    => x0_m01_rresp,
            m_axi_rresp(1 downto 0)    => x0_m00_rresp,
            m_axi_rlast(1) => x0_m01_rlast,
            m_axi_rlast(0) => x0_m00_rlast,
            m_axi_rvalid(1) => x0_m01_rvalid,
            m_axi_rvalid(0) => x0_m00_rvalid,
            m_axi_rready(1) => x0_m01_rready,
            m_axi_rready(0) => x0_m00_rready
        );

    --------------------------------------------------------------------
    -- AXI Protocol Converter (AXI4 -> AXI4Lite for CDMA Control)
    --------------------------------------------------------------------

    u_prot_conv : entity work.axi_protocol_converter_0
        port map (
            aclk          => ui_clk,
            aresetn       => ui_rst_n,
            s_axi_awid    => x0_m01_awid,
            s_axi_awaddr  => x0_m01_awaddr,
            s_axi_awlen   => x0_m01_awlen,
            s_axi_awsize  => "010",
            s_axi_awburst => x0_m01_awburst,
            s_axi_awlock(0) => '0',
            s_axi_awcache => "0011",
            s_axi_awprot  => "000",
            s_axi_awregion => "0000",
            s_axi_awqos   => "0000",
            s_axi_awvalid => x0_m01_awvalid,
            s_axi_awready => x0_m01_awready,
            s_axi_wdata   => x0_m01_wdata,
            s_axi_wstrb   => x0_m01_wstrb,
            s_axi_wlast   => x0_m01_wlast,
            s_axi_wvalid  => x0_m01_wvalid,
            s_axi_wready  => x0_m01_wready,
            s_axi_bid     => x0_m01_bid,
            s_axi_bresp   => x0_m01_bresp,
            s_axi_bvalid  => x0_m01_bvalid,
            s_axi_bready  => x0_m01_bready,
            s_axi_arid    => x0_m01_arid,
            s_axi_araddr  => x0_m01_araddr,
            s_axi_arlen   => x0_m01_arlen,
            s_axi_arsize  => "010",
            s_axi_arburst => x0_m01_arburst,
            s_axi_arlock(0) => '0',
            s_axi_arcache => "0011",
            s_axi_arregion => "0000",
            s_axi_arqos   => "0000",
            s_axi_arprot  => "000",
            s_axi_arvalid => x0_m01_arvalid,
            s_axi_arready => x0_m01_arready,
            s_axi_rid     => x0_m01_rid,
            s_axi_rdata   => x0_m01_rdata,
            s_axi_rresp   => x0_m01_rresp,
            s_axi_rlast   => x0_m01_rlast,
            s_axi_rvalid  => x0_m01_rvalid,
            s_axi_rready  => x0_m01_rready,

            m_axi_awaddr  => prot_awaddr,
            m_axi_awprot  => open,
            m_axi_awvalid => prot_awvalid,
            m_axi_awready => prot_awready,
            m_axi_wdata   => prot_wdata,
            m_axi_wstrb   => prot_wstrb,
            m_axi_wvalid  => prot_wvalid,
            m_axi_wready  => prot_wready,
            m_axi_bresp   => prot_bresp,
            m_axi_bvalid  => prot_bvalid,
            m_axi_bready  => prot_bready,
            m_axi_araddr  => prot_araddr,
            m_axi_arprot  => open,
            m_axi_arvalid => prot_arvalid,
            m_axi_arready => prot_arready,
            m_axi_rdata   => prot_rdata,
            m_axi_rresp   => prot_rresp,
            m_axi_rvalid  => prot_rvalid,
            m_axi_rready  => prot_rready
        );

    --------------------------------------------------------------------
    -- AXI Central DMA IP Instance
    --------------------------------------------------------------------

    u_cdma : entity work.axi_cdma_0
        port map (
            m_axi_aclk    => ui_clk,
            s_axi_lite_aclk => ui_clk,
            s_axi_lite_aresetn => ui_rst_n,
            cdma_introut  => open,

            -- Slave Interface (AXI Lite Control)
            s_axi_lite_awvalid => prot_awvalid,
            s_axi_lite_awready => prot_awready,
            s_axi_lite_awaddr  => prot_awaddr(5 downto 0),
            s_axi_lite_wvalid  => prot_wvalid,
            s_axi_lite_wready  => prot_wready,
            s_axi_lite_wdata   => prot_wdata,
            s_axi_lite_bvalid  => prot_bvalid,
            s_axi_lite_bready  => prot_bready,
            s_axi_lite_bresp   => prot_bresp,
            s_axi_lite_arvalid => prot_arvalid,
            s_axi_lite_arready => prot_arready,
            s_axi_lite_araddr  => prot_araddr(5 downto 0),
            s_axi_lite_rvalid  => prot_rvalid,
            s_axi_lite_rready  => prot_rready,
            s_axi_lite_rdata   => prot_rdata,
            s_axi_lite_rresp   => prot_rresp,

            -- Master Interface (AXI4 256-bit)
            m_axi_arready => cdma_arready,
            m_axi_arvalid => cdma_arvalid,
            m_axi_araddr  => cdma_araddr,
            m_axi_arlen   => cdma_arlen,
            m_axi_arsize  => cdma_arsize,
            m_axi_arburst => cdma_arburst,
            m_axi_arprot  => cdma_arprot,
            m_axi_arcache => cdma_arcache,
            m_axi_rready  => cdma_rready,
            m_axi_rvalid  => cdma_rvalid,
            m_axi_rdata   => cdma_rdata,
            m_axi_rresp   => cdma_rresp,
            m_axi_rlast   => cdma_rlast,
            m_axi_awready => cdma_awready,
            m_axi_awvalid => cdma_awvalid,
            m_axi_awaddr  => cdma_awaddr,
            m_axi_awlen   => cdma_awlen,
            m_axi_awsize  => cdma_awsize,
            m_axi_awburst => cdma_awburst,
            m_axi_awprot  => cdma_awprot,
            m_axi_awcache => cdma_awcache,
            m_axi_wready  => cdma_wready,
            m_axi_wvalid  => cdma_wvalid,
            m_axi_wdata   => cdma_wdata,
            m_axi_wstrb   => cdma_wstrb,
            m_axi_wlast   => cdma_wlast,
            m_axi_bready  => cdma_bready,
            m_axi_bvalid  => cdma_bvalid,
            m_axi_bresp   => cdma_bresp
        );

    --------------------------------------------------------------------
    -- LED(2) status logic (Active when CDMA is transferring)
    --------------------------------------------------------------------

    process (ui_clk)
    begin
        if rising_edge(ui_clk) then
            if ui_rst_n = '0' then
                cdma_active <= '0';
                cdma_active_cnt <= (others => '0');
            else
                -- Set active if any master activity is detected
                if cdma_awvalid = '1' or cdma_arvalid = '1' then
                    cdma_active <= '1';
                    cdma_active_cnt <= (others => '1');
                elsif cdma_active_cnt /= 0 then
                    cdma_active_cnt <= cdma_active_cnt - 1;
                else
                    cdma_active <= '0';
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- AXI Data Width Converter (32 -> 256)
    --------------------------------------------------------------------

    u_dwidth_conv : entity work.axi_dwidth_converter_0
        port map (
            s_axi_aclk    => ui_clk,
            s_axi_aresetn => ui_rst_n,
            s_axi_awid    => x0_m00_awid,
            s_axi_awaddr  => x0_m00_awaddr(30 downto 0),
            s_axi_awlen   => x0_m00_awlen,
            s_axi_awsize  => "010",
            s_axi_awburst => x0_m00_awburst,
            s_axi_awlock(0) => '0',
            s_axi_awcache => "0011",
            s_axi_awprot  => "000",
            s_axi_awregion => "0000",
            s_axi_awqos    => "0000",
            s_axi_awvalid => x0_m00_awvalid,
            s_axi_awready => x0_m00_awready,
            s_axi_wdata   => x0_m00_wdata,
            s_axi_wstrb   => x0_m00_wstrb,
            s_axi_wlast   => x0_m00_wlast,
            s_axi_wvalid  => x0_m00_wvalid,
            s_axi_wready  => x0_m00_wready,
            s_axi_bid     => x0_m00_bid,
            s_axi_bresp   => x0_m00_bresp,
            s_axi_bvalid  => x0_m00_bvalid,
            s_axi_bready  => x0_m00_bready,
            s_axi_arid    => x0_m00_arid,
            s_axi_araddr  => x0_m00_araddr(30 downto 0),
            s_axi_arlen   => x0_m00_arlen,
            s_axi_arsize  => "010",
            s_axi_arburst => x0_m00_arburst,
            s_axi_arlock(0) => '0',
            s_axi_arcache => "0011",
            s_axi_arregion => "0000",
            s_axi_arqos    => "0000",
            s_axi_arprot  => "000",
            s_axi_arvalid => x0_m00_arvalid,
            s_axi_arready => x0_m00_arready,
            s_axi_rid     => x0_m00_rid,
            s_axi_rdata   => x0_m00_rdata,
            s_axi_rresp   => x0_m00_rresp,
            s_axi_rlast   => x0_m00_rlast,
            s_axi_rvalid  => x0_m00_rvalid,
            s_axi_rready  => x0_m00_rready,

            m_axi_awaddr  => dwc_awaddr,
            m_axi_awlen   => dwc_awlen,
            m_axi_awsize  => open,
            m_axi_awburst => dwc_awburst,
            m_axi_awlock  => open,
            m_axi_awcache => open,
            m_axi_awprot  => open,
            m_axi_awregion => open,
            m_axi_awqos    => open,
            m_axi_awvalid => dwc_awvalid,
            m_axi_awready => dwc_awready,
            m_axi_wdata   => dwc_wdata,
            m_axi_wstrb   => dwc_wstrb,
            m_axi_wlast   => dwc_wlast,
            m_axi_wvalid  => dwc_wvalid,
            m_axi_wready  => dwc_wready,
            m_axi_bresp   => dwc_bresp,
            m_axi_bvalid  => dwc_bvalid,
            m_axi_bready  => dwc_bready,
            m_axi_araddr  => dwc_araddr,
            m_axi_arlen   => dwc_arlen,
            m_axi_arsize  => open,
            m_axi_arburst => dwc_arburst,
            m_axi_arlock  => open,
            m_axi_arcache => open,
            m_axi_arprot  => open,
            m_axi_arregion => open,
            m_axi_arqos    => open,
            m_axi_arvalid => dwc_arvalid,
            m_axi_arready => dwc_arready,
            m_axi_rdata   => dwc_rdata,
            m_axi_rresp   => dwc_rresp,
            m_axi_rlast   => dwc_rlast,
            m_axi_rvalid  => dwc_rvalid,
            m_axi_rready  => dwc_rready
        );
        dwc_awid <= x0_m00_awid;
        dwc_arid <= x0_m00_arid;

    --------------------------------------------------------------------
    -- AXI SmartConnect (Merger: Bridge & CDMA -> DDR4, 256-bit)
    --------------------------------------------------------------------

    u_merger : entity work.axi_smartconnect_1
        port map (
            aclk          => ui_clk,
            aresetn       => ui_rst_n,

            -- S00: from DWC (Bridge)
            s00_axi_awid    => dwc_awid,
            s00_axi_awaddr  => dwc_awaddr,
            s00_axi_awlen   => dwc_awlen,
            s00_axi_awsize  => "101",
            s00_axi_awburst => dwc_awburst,
            s00_axi_awlock(0) => '0',
            s00_axi_awcache => "0011",
            s00_axi_awprot  => "000",
            s00_axi_awqos   => "0000",
            s00_axi_awvalid => dwc_awvalid,
            s00_axi_awready => dwc_awready,
            s00_axi_wdata   => dwc_wdata,
            s00_axi_wstrb   => dwc_wstrb,
            s00_axi_wlast   => dwc_wlast,
            s00_axi_wvalid  => dwc_wvalid,
            s00_axi_wready  => dwc_wready,
            s00_axi_bid     => dwc_bid,
            s00_axi_bresp   => dwc_bresp,
            s00_axi_bvalid  => dwc_bvalid,
            s00_axi_bready  => dwc_bready,
            s00_axi_arid    => dwc_arid,
            s00_axi_araddr  => dwc_araddr,
            s00_axi_arlen   => dwc_arlen,
            s00_axi_arsize  => "101",
            s00_axi_arburst => dwc_arburst,
            s00_axi_arlock(0) => '0',
            s00_axi_arcache => "0011",
            s00_axi_arprot  => "000",
            s00_axi_arqos   => "0000",
            s00_axi_arvalid => dwc_arvalid,
            s00_axi_arready => dwc_arready,
            s00_axi_rid     => dwc_rid,
            s00_axi_rdata   => dwc_rdata,
            s00_axi_rresp   => dwc_rresp,
            s00_axi_rlast   => dwc_rlast,
            s00_axi_rvalid  => dwc_rvalid,
            s00_axi_rready  => dwc_rready,

            -- S01: from CDMA Master
            s01_axi_awid    => (others => '0'),
            s01_axi_awaddr  => cdma_awaddr(30 downto 0),
            s01_axi_awlen   => cdma_awlen,
            s01_axi_awsize  => cdma_awsize,
            s01_axi_awburst => cdma_awburst,
            s01_axi_awlock(0) => '0',
            s01_axi_awcache => cdma_awcache,
            s01_axi_awprot  => cdma_awprot,
            s01_axi_awqos   => "0000",
            s01_axi_awvalid => cdma_awvalid,
            s01_axi_awready => cdma_awready,
            s01_axi_wdata   => cdma_wdata,
            s01_axi_wstrb   => cdma_wstrb,
            s01_axi_wlast   => cdma_wlast,
            s01_axi_wvalid  => cdma_wvalid,
            s01_axi_wready  => cdma_wready,
            s01_axi_bid     => open,
            s01_axi_bresp   => cdma_bresp,
            s01_axi_bvalid  => cdma_bvalid,
            s01_axi_bready  => cdma_bready,
            s01_axi_arid    => (others => '0'),
            s01_axi_araddr  => cdma_araddr(30 downto 0),
            s01_axi_arlen   => cdma_arlen,
            s01_axi_arsize  => cdma_arsize,
            s01_axi_arburst => cdma_arburst,
            s01_axi_arlock(0) => '0',
            s01_axi_arcache => cdma_arcache,
            s01_axi_arprot  => cdma_arprot,
            s01_axi_arqos   => "0000",
            s01_axi_arvalid => cdma_arvalid,
            s01_axi_arready => cdma_arready,
            s01_axi_rid     => open,
            s01_axi_rdata   => cdma_rdata,
            s01_axi_rresp   => cdma_rresp,
            s01_axi_rlast   => cdma_rlast,
            s01_axi_rvalid  => cdma_rvalid,
            s01_axi_rready  => cdma_rready,

            -- M00: to DDR4
            m00_axi_awid    => m_awid,
            m00_axi_awaddr  => m_awaddr,
            m00_axi_awlen   => m_awlen,
            m00_axi_awsize  => open,
            m00_axi_awburst => m_awburst,
            m00_axi_awlock  => open,
            m00_axi_awcache => open,
            m00_axi_awprot  => open,
            m00_axi_awregion => open,
            m00_axi_awqos    => open,
            m00_axi_awvalid => m_awvalid,
            m00_axi_awready => m_awready,
            m00_axi_wdata   => m_wdata,
            m00_axi_wstrb   => m_wstrb,
            m00_axi_wlast   => m_wlast,
            m00_axi_wvalid  => m_wvalid,
            m00_axi_wready  => m_wready,
            m00_axi_bid     => m_bid,
            m00_axi_bresp   => m_bresp,
            m00_axi_bvalid  => m_bvalid,
            m00_axi_bready  => m_bready,
            m00_axi_arid    => m_arid,
            m00_axi_araddr  => m_araddr,
            m00_axi_arlen   => m_arlen,
            m00_axi_arsize  => open,
            m00_axi_arburst => m_arburst,
            m00_axi_arlock  => open,
            m00_axi_arcache => open,
            m00_axi_arprot  => open,
            m00_axi_arregion => open,
            m00_axi_arqos    => open,
            m00_axi_arvalid => m_arvalid,
            m00_axi_arready => m_arready,
            m00_axi_rid     => m_rid,
            m00_axi_rdata   => m_rdata,
            m00_axi_rresp   => m_rresp,
            m00_axi_rlast   => m_rlast,
            m00_axi_rvalid  => m_rvalid,
            m00_axi_rready  => m_rready
        );

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
    led(1) <= calib_complete;
    led(2) <= cdma_active;
    led(3) <= not key(3);

end RTL;
