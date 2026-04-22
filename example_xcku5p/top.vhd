----------------------------------------------------------------------------
--  top.vhd
--	XCKU5P simple VHDL example
--	Version 1.1 - DDR4 Support
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
    generic (
        UART_SPEED : integer := 115200
    );
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
    -- AXI Bus Signals (Bridge 32-bit)
    --------------------------------------------------------------------

    signal mem_awvalid : std_logic;
    signal mem_awready : std_logic;
    signal mem_awaddr  : std_logic_vector(30 downto 0);
    signal mem_awid    : std_logic_vector(3 downto 0);
    signal mem_awlen   : std_logic_vector(7 downto 0);
    signal mem_awburst : std_logic_vector(1 downto 0);

    signal mem_wvalid  : std_logic;
    signal mem_wready  : std_logic;
    signal mem_wdata   : std_logic_vector(31 downto 0);
    signal mem_wstrb   : std_logic_vector(3 downto 0);
    signal mem_wlast   : std_logic;

    signal mem_bvalid  : std_logic;
    signal mem_bready  : std_logic;
    signal mem_bresp   : std_logic_vector(1 downto 0);
    signal mem_bid     : std_logic_vector(3 downto 0);

    signal mem_arvalid : std_logic;
    signal mem_arready : std_logic;
    signal mem_araddr  : std_logic_vector(30 downto 0);
    signal mem_arid    : std_logic_vector(3 downto 0);
    signal mem_arlen   : std_logic_vector(7 downto 0);
    signal mem_arburst : std_logic_vector(1 downto 0);

    signal mem_rvalid  : std_logic;
    signal mem_rready  : std_logic;
    signal mem_rdata   : std_logic_vector(31 downto 0);
    signal mem_rresp   : std_logic_vector(1 downto 0);
    signal mem_rid     : std_logic_vector(3 downto 0);
    signal mem_rlast   : std_logic;

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
    -- AXI Clock Conversion (100 -> UI)
    --------------------------------------------------------------------

    signal m_awvalid : std_logic;
    signal m_awready : std_logic;
    signal m_awaddr  : std_logic_vector(30 downto 0);
    signal m_awid    : std_logic_vector(3 downto 0);
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
    signal m_bid     : std_logic_vector(3 downto 0);

    signal m_arvalid : std_logic;
    signal m_arready : std_logic;
    signal m_araddr  : std_logic_vector(30 downto 0);
    signal m_arid    : std_logic_vector(3 downto 0);
    signal m_arlen   : std_logic_vector(7 downto 0);
    signal m_arburst : std_logic_vector(1 downto 0);

    signal m_rvalid  : std_logic;
    signal m_rready  : std_logic;
    signal m_rdata   : std_logic_vector(255 downto 0);
    signal m_rresp   : std_logic_vector(1 downto 0);
    signal m_rid     : std_logic_vector(3 downto 0);
    signal m_rlast   : std_logic;


    signal rst_i : std_logic;
    signal ddr_rst : std_logic;
    signal ui_clk : std_logic;
    signal ui_rst : std_logic;
    signal ui_rst_n : std_logic;
    signal rst_100_n : std_logic;

    signal calib_complete : std_logic;

    signal bridge_awaddr : std_logic_vector(31 downto 0);
    signal bridge_araddr : std_logic_vector(31 downto 0);

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
            UART_SPEED   => UART_SPEED
        )
        port map (
            clk_i          => clk_100,
            rst_i          => rst_i,
            uart_rxd_i     => uart_rxd_i,
            uart_txd_o     => uart_txd_o,

            mem_awvalid_o  => mem_awvalid,
            mem_awready_i  => mem_awready,
            mem_awaddr_o   => bridge_awaddr,
            mem_awid_o     => mem_awid,
            mem_awlen_o    => mem_awlen,
            mem_awburst_o  => mem_awburst,

            mem_wvalid_o   => mem_wvalid,
            mem_wready_i   => mem_wready,
            mem_wdata_o    => mem_wdata,
            mem_wstrb_o    => mem_wstrb,
            mem_wlast_o    => mem_wlast,

            mem_bvalid_i   => mem_bvalid,
            mem_bready_o   => mem_bready,
            mem_bresp_i    => mem_bresp,
            mem_bid_i      => mem_bid,

            mem_arvalid_o  => mem_arvalid,
            mem_arready_i  => mem_arready,
            mem_araddr_o   => bridge_araddr,
            mem_arid_o     => mem_arid,
            mem_arlen_o    => mem_arlen,
            mem_arburst_o  => mem_arburst,

            mem_rvalid_i   => mem_rvalid,
            mem_rready_o   => mem_rready,
            mem_rdata_i    => mem_rdata,
            mem_rresp_i    => mem_rresp,
            mem_rid_i      => mem_rid,
            mem_rlast_i    => mem_rlast,

            gpio_inputs_i  => (others => '0'),
            gpio_outputs_o => open
        );

    mem_awaddr <= bridge_awaddr(30 downto 0);
    mem_araddr <= bridge_araddr(30 downto 0);

    --------------------------------------------------------------------
    -- AXI Data Width Converter (32 -> 256)
    --------------------------------------------------------------------

    rst_100_n <= not rst_i;

    u_dwidth_conv : entity work.axi_dwidth_converter_0
        port map (
            s_axi_aclk    => clk_100,
            s_axi_aresetn => rst_100_n,
            s_axi_awid    => mem_awid,
            s_axi_awaddr  => mem_awaddr,
            s_axi_awlen   => mem_awlen,
            s_axi_awsize  => "010", -- 4 bytes (32-bit)
            s_axi_awburst => mem_awburst,
            s_axi_awlock  => "0",
            s_axi_awcache => "0011",
            s_axi_awprot  => "000",
            s_axi_awregion => "0000",
            s_axi_awqos    => "0000",
            s_axi_awvalid => mem_awvalid,
            s_axi_awready => mem_awready,
            s_axi_wdata   => mem_wdata,
            s_axi_wstrb   => mem_wstrb,
            s_axi_wlast   => mem_wlast,
            s_axi_wvalid  => mem_wvalid,
            s_axi_wready  => mem_wready,
            s_axi_bid     => mem_bid,
            s_axi_bresp   => mem_bresp,
            s_axi_bvalid  => mem_bvalid,
            s_axi_bready  => mem_bready,
            s_axi_arid    => mem_arid,
            s_axi_araddr  => mem_araddr,
            s_axi_arlen   => mem_arlen,
            s_axi_arsize  => "010", -- 4 bytes (32-bit)
            s_axi_arburst => mem_arburst,
            s_axi_arlock  => "0",
            s_axi_arcache => "0011",
            s_axi_arprot  => "000",
            s_axi_arregion => "0000",
            s_axi_arqos    => "0000",
            s_axi_arvalid => mem_arvalid,
            s_axi_arready => mem_arready,
            s_axi_rid     => mem_rid,
            s_axi_rdata   => mem_rdata,
            s_axi_rresp   => mem_rresp,
            s_axi_rlast   => mem_rlast,
            s_axi_rvalid  => mem_rvalid,
            s_axi_rready  => mem_rready,

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
        dwc_awid <= mem_awid;
        dwc_arid <= mem_arid;

    --------------------------------------------------------------------
    -- AXI Clock Converter (100 -> UI)
    --------------------------------------------------------------------

    u_clk_conv : entity work.axi_clock_converter_0
        port map (
            s_axi_aclk    => clk_100,
            s_axi_aresetn => rst_100_n,
            s_axi_awid    => dwc_awid,
            s_axi_awaddr  => dwc_awaddr,
            s_axi_awlen   => dwc_awlen,
            s_axi_awsize  => "101", -- 32 bytes (256-bit)
            s_axi_awburst => dwc_awburst,
            s_axi_awlock  => "0",
            s_axi_awcache => "0011",
            s_axi_awprot  => "000",
            s_axi_awregion => "0000",
            s_axi_awqos    => "0000",
            s_axi_awvalid => dwc_awvalid,
            s_axi_awready => dwc_awready,
            s_axi_wdata   => dwc_wdata,
            s_axi_wstrb   => dwc_wstrb,
            s_axi_wlast   => dwc_wlast,
            s_axi_wvalid  => dwc_wvalid,
            s_axi_wready  => dwc_wready,
            s_axi_bid     => dwc_bid,
            s_axi_bresp   => dwc_bresp,
            s_axi_bvalid  => dwc_bvalid,
            s_axi_bready  => dwc_bready,
            s_axi_arid    => dwc_arid,
            s_axi_araddr  => dwc_araddr,
            s_axi_arlen   => dwc_arlen,
            s_axi_arsize  => "101", -- 32 bytes (256-bit)
            s_axi_arburst => dwc_arburst,
            s_axi_arlock  => "0",
            s_axi_arcache => "0011",
            s_axi_arprot  => "000",
            s_axi_arregion => "0000",
            s_axi_arqos    => "0000",
            s_axi_arvalid => dwc_arvalid,
            s_axi_arready => dwc_arready,
            s_axi_rid     => dwc_rid,
            s_axi_rdata   => dwc_rdata,
            s_axi_rresp   => dwc_rresp,
            s_axi_rlast   => dwc_rlast,
            s_axi_rvalid  => dwc_rvalid,
            s_axi_rready  => dwc_rready,

            m_axi_aclk    => ui_clk,
            m_axi_aresetn => ui_rst_n,
            m_axi_awid    => m_awid,
            m_axi_awaddr  => m_awaddr,
            m_axi_awlen   => m_awlen,
            m_axi_awsize  => open,
            m_axi_awburst => m_awburst,
            m_axi_awlock  => open,
            m_axi_awcache => open,
            m_axi_awprot  => open,
            m_axi_awregion => open,
            m_axi_awqos    => open,
            m_axi_awvalid => m_awvalid,
            m_axi_awready => m_awready,
            m_axi_wdata   => m_wdata,
            m_axi_wstrb   => m_wstrb,
            m_axi_wlast   => m_wlast,
            m_axi_wvalid  => m_wvalid,
            m_axi_wready  => m_wready,
            m_axi_bid     => m_bid,
            m_axi_bresp   => m_bresp,
            m_axi_bvalid  => m_bvalid,
            m_axi_bready  => m_bready,
            m_axi_arid    => m_arid,
            m_axi_araddr  => m_araddr,
            m_axi_arlen   => m_arlen,
            m_axi_arsize  => open,
            m_axi_arburst => m_arburst,
            m_axi_arlock  => open,
            m_axi_arcache => open,
            m_axi_arprot  => open,
            m_axi_arregion => open,
            m_axi_arqos    => open,
            m_axi_arvalid => m_arvalid,
            m_axi_arready => m_arready,
            m_axi_rid     => m_rid,
            m_axi_rdata   => m_rdata,
            m_axi_rresp   => m_rresp,
            m_axi_rlast   => m_rlast,
            m_axi_rvalid  => m_rvalid,
            m_axi_rready  => m_rready
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
    led(2) <= not key(2);
    led(3) <= not key(3);

end RTL;
