----------------------------------------------------------------------------
--  top.vhd
--	MicroZed simple VHDL example
--	Version 1.0
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
        ps_mio : inout std_logic_vector(53 downto 0) );
end entity top;

architecture RTL of top is

    signal clk_cfg : std_logic;
    signal clk_cfgm : std_logic;

    signal blue_led : std_logic;
    signal blue_led_n : std_logic;

    signal ps_fclk : std_logic_vector(3 downto 0);
    signal ps_reset_n : std_logic_vector(3 downto 0);


    --------------------------------------------------------------------
    -- AXI Bus Signals
    --------------------------------------------------------------------

    signal mem_awvalid : std_logic;
    signal mem_awready : std_logic;
    signal mem_awaddr  : std_logic_vector(31 downto 0);
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
    signal mem_araddr  : std_logic_vector(31 downto 0);
    signal mem_arid    : std_logic_vector(3 downto 0);
    signal mem_arlen   : std_logic_vector(7 downto 0);
    signal mem_arburst : std_logic_vector(1 downto 0);

    signal mem_rvalid  : std_logic;
    signal mem_rready  : std_logic;
    signal mem_rdata   : std_logic_vector(31 downto 0);
    signal mem_rresp   : std_logic_vector(1 downto 0);
    signal mem_rid     : std_logic_vector(3 downto 0);
    signal mem_rlast   : std_logic;

    signal s_gp0_bid   : std_logic_vector(5 downto 0);
    signal s_gp0_rid   : std_logic_vector(5 downto 0);

    signal uart0_tx : std_ulogic;
    signal uart0_rx : std_ulogic;

    signal clk_i : std_logic;
    signal rst_i : std_logic;

begin

    --------------------------------------------------------------------
    -- Processing System 7
    --------------------------------------------------------------------

    ps7_stub_inst : entity work.ps7_stub
        port map (
            ps_mio          => ps_mio,
            ps_fclk         => ps_fclk,
            ps_reset_n      => ps_reset_n,

            s_gp0_aclk      => clk_i,

            s_gp0_awvalid   => mem_awvalid,
            s_gp0_awready   => mem_awready,
            s_gp0_awaddr    => mem_awaddr,
            s_gp0_awid      => "00" & mem_awid,
            s_gp0_awlen     => mem_awlen(3 downto 0),
            s_gp0_awburst   => mem_awburst,

            s_gp0_wvalid    => mem_wvalid,
            s_gp0_wready    => mem_wready,
            s_gp0_wdata     => mem_wdata,
            s_gp0_wstrb     => mem_wstrb,
            s_gp0_wlast     => mem_wlast,
            s_gp0_wid       => "00" & mem_awid,

            s_gp0_bvalid    => mem_bvalid,
            s_gp0_bready    => mem_bready,
            s_gp0_bresp     => mem_bresp,
            s_gp0_bid       => s_gp0_bid,

            s_gp0_arvalid   => mem_arvalid,
            s_gp0_arready   => mem_arready,
            s_gp0_araddr    => mem_araddr,
            s_gp0_arid      => "00" & mem_arid,
            s_gp0_arlen     => mem_arlen(3 downto 0),
            s_gp0_arburst   => mem_arburst,

            s_gp0_rvalid    => mem_rvalid,
            s_gp0_rready    => mem_rready,
            s_gp0_rdata     => mem_rdata,
            s_gp0_rresp     => mem_rresp,
            s_gp0_rid       => s_gp0_rid,
            s_gp0_rlast     => mem_rlast,

            uart0_tx        => uart0_tx,
            uart0_rx        => uart0_rx
        );

    mem_bid <= s_gp0_bid(3 downto 0);
    mem_rid <= s_gp0_rid(3 downto 0);

    --------------------------------------------------------------------
    -- Debug Bridge
    --------------------------------------------------------------------

    clk_i <= ps_fclk(0);
    rst_i <= not ps_reset_n(0);

    u_bridge : entity work.dbg_bridge
        generic map (
            CLK_FREQ     => 100000000,
            UART_SPEED   => UART_SPEED
        )
        port map (
            clk_i          => clk_i,
            rst_i          => rst_i,
            uart_rxd_i     => uart0_tx, -- PS7 UART0 TX is bridge RX
            uart_txd_o     => uart0_rx, -- Bridge TX is PS7 UART0 RX

            mem_awvalid_o  => mem_awvalid,
            mem_awready_i  => mem_awready,
            mem_awaddr_o   => mem_awaddr,
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
            mem_araddr_o   => mem_araddr,
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

    --------------------------------------------------------------------
    -- Blinking DONE LED
    --------------------------------------------------------------------

    div_led_inst : entity work.async_div
	generic map (
	    STAGES => 28 )
	port map (
	    clk_in => clk_i,
	    clk_out => blue_led );

    blue_led_n <= not blue_led;

    STARTUPE2_inst : STARTUPE2
	generic map (
	    PROG_USR => "FALSE",
	    SIM_CCLK_FREQ => 0.0 )
	port map (
	    CFGCLK => clk_cfg,
	    CFGMCLK => clk_cfgm,
	    EOS => open,
	    PREQ => open,
	    CLK => '0',
	    GSR => '0',
	    GTS => '0',
	    KEYCLEARB => '0',
	    PACK => '0',
	    USRCCLKO => '0',
	    USRCCLKTS => '0',
	    USRDONEO => '0',
	    USRDONETS => blue_led_n );

end RTL;
