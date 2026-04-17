----------------------------------------------------------------------------
--  top.vhd
--	XCKU5P simple VHDL example
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
    port (
	sys_clk_p : IN std_logic;
	sys_clk_n : IN std_logic;

	led : OUT std_logic_vector(0 TO 3);
	key : IN std_logic_vector(0 TO 3);

        uart_rxd_i : in  std_logic;
        uart_txd_o : out std_logic );

end entity top;

architecture RTL of top is

    signal clk_200 : std_logic;

    signal clk_cfg : std_logic;
    signal clk_cfgm : std_logic;

    signal done_led : std_logic;
    signal done_led_n : std_logic;


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

    --------------------------------------------------------------------
    -- BRAM Interface Signals
    --------------------------------------------------------------------

    signal bram_rst_a    : std_logic;
    signal bram_clk_a    : std_logic;
    signal bram_en_a     : std_logic;
    signal bram_we_a     : std_logic_vector(3 downto 0);
    signal bram_addr_a   : std_logic_vector(15 downto 0);
    signal bram_wrdata_a : std_logic_vector(31 downto 0);
    signal bram_rddata_a : std_logic_vector(31 downto 0);

    --------------------------------------------------------------------
    -- AXI BRAM Controller (IP)
    --------------------------------------------------------------------

    component axi_bram_ctrl_0 is
        port (
            -- AXI interface
            s_axi_aclk    : in  std_logic;
            s_axi_aresetn : in  std_logic;
            s_axi_awid    : in  std_logic_vector(3 downto 0);
            s_axi_awaddr  : in  std_logic_vector(15 downto 0);
            s_axi_awlen   : in  std_logic_vector(7 downto 0);
            s_axi_awsize  : in  std_logic_vector(2 downto 0);
            s_axi_awburst : in  std_logic_vector(1 downto 0);
            s_axi_awlock  : in  std_logic;
            s_axi_awcache : in  std_logic_vector(3 downto 0);
            s_axi_awprot  : in  std_logic_vector(2 downto 0);
            s_axi_awvalid : in  std_logic;
            s_axi_awready : out std_logic;
            s_axi_wdata   : in  std_logic_vector(31 downto 0);
            s_axi_wstrb   : in  std_logic_vector(3 downto 0);
            s_axi_wlast   : in  std_logic;
            s_axi_wvalid  : in  std_logic;
            s_axi_wready  : out std_logic;
            s_axi_bid     : out std_logic_vector(3 downto 0);
            s_axi_bresp   : out std_logic_vector(1 downto 0);
            s_axi_bvalid  : out std_logic;
            s_axi_bready  : in  std_logic;
            s_axi_arid    : in  std_logic_vector(3 downto 0);
            s_axi_araddr  : in  std_logic_vector(15 downto 0);
            s_axi_arlen   : in  std_logic_vector(7 downto 0);
            s_axi_arsize  : in  std_logic_vector(2 downto 0);
            s_axi_arburst : in  std_logic_vector(1 downto 0);
            s_axi_arlock  : in  std_logic;
            s_axi_arcache : in  std_logic_vector(3 downto 0);
            s_axi_arprot  : in  std_logic_vector(2 downto 0);
            s_axi_arvalid : in  std_logic;
            s_axi_arready : out std_logic;
            s_axi_rid     : out std_logic_vector(3 downto 0);
            s_axi_rdata   : out std_logic_vector(31 downto 0);
            s_axi_rresp   : out std_logic_vector(1 downto 0);
            s_axi_rlast   : out std_logic;
            s_axi_rvalid  : out std_logic;
            s_axi_rready  : in  std_logic;

            -- BRAM interface
            bram_rst_a    : out std_logic;
            bram_clk_a    : out std_logic;
            bram_en_a     : out std_logic;
            bram_we_a     : out std_logic_vector(3 downto 0);
            bram_addr_a   : out std_logic_vector(15 downto 0);
            bram_wrdata_a : out std_logic_vector(31 downto 0);
            bram_rddata_a : in  std_logic_vector(31 downto 0)
        );
    end component;

    --------------------------------------------------------------------
    -- Block Memory (IP)
    --------------------------------------------------------------------

    component blk_mem_gen_0 is
        port (
            clka  : in  std_logic;
            rsta  : in  std_logic;
            ena   : in  std_logic;
            wea   : in  std_logic_vector(3 downto 0);
            addra : in  std_logic_vector(15 downto 0);
            dina  : in  std_logic_vector(31 downto 0);
            douta : out std_logic_vector(31 downto 0)
        );
    end component;

    signal clk_i : std_logic;
    signal rst_i : std_logic;

    signal rst_n : std_logic;

begin

    --------------------------------------------------------------------
    -- Differential Clock Buffer
    --------------------------------------------------------------------

    IBUFDS_inst : entity work.IBUFDS
	port map (
	    I => sys_clk_p,
	    IB => sys_clk_n,
	    O => clk_200
	);

    BUFGCE_DIV_inst : entity work.BUFGCE_DIV
	generic map (
	    BUFGCE_DIVIDE => 2
	)
	port map (
	    I => clk_200,
	    CE => '1',
	    CLR => '0',
	    O => clk_i
	);

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
            clk_i          => clk_i,
            rst_i          => rst_i,
            uart_rxd_i     => uart_rxd_i,
            uart_txd_o     => uart_txd_o,

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
    -- AXI BRAM Controller
    --------------------------------------------------------------------

    rst_n <= key(0);

    u_bram_ctrl : axi_bram_ctrl_0
        port map (
            s_axi_aclk    => clk_i,
            s_axi_aresetn => rst_n,
            s_axi_awid    => mem_awid,
            s_axi_awaddr  => mem_awaddr(15 downto 0),
            s_axi_awlen   => mem_awlen,
            s_axi_awsize  => "010", -- 4 bytes
            s_axi_awburst => mem_awburst,
            s_axi_awlock  => '0',
            s_axi_awcache => "0011",
            s_axi_awprot  => "000",
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
            s_axi_araddr  => mem_araddr(15 downto 0),
            s_axi_arlen   => mem_arlen,
            s_axi_arsize  => "010", -- 4 bytes
            s_axi_arburst => mem_arburst,
            s_axi_arlock  => '0',
            s_axi_arcache => "0011",
            s_axi_arprot  => "000",
            s_axi_arvalid => mem_arvalid,
            s_axi_arready => mem_arready,
            s_axi_rid     => mem_rid,
            s_axi_rdata   => mem_rdata,
            s_axi_rresp   => mem_rresp,
            s_axi_rlast   => mem_rlast,
            s_axi_rvalid  => mem_rvalid,
            s_axi_rready  => mem_rready,

            -- BRAM interface
            bram_rst_a    => bram_rst_a,
            bram_clk_a    => bram_clk_a,
            bram_en_a     => bram_en_a,
            bram_we_a     => bram_we_a,
            bram_addr_a   => bram_addr_a,
            bram_wrdata_a => bram_wrdata_a,
            bram_rddata_a => bram_rddata_a
        );

    --------------------------------------------------------------------
    -- Block Memory (BRAM)
    --------------------------------------------------------------------

    u_bram : blk_mem_gen_0
        port map (
            clka  => bram_clk_a,
            rsta  => bram_rst_a,
            ena   => bram_en_a,
            wea   => bram_we_a,
            addra => bram_addr_a,
            dina  => bram_wrdata_a,
            douta => bram_rddata_a
        );

    --------------------------------------------------------------------
    -- Blinking DONE LED
    --------------------------------------------------------------------

    div_led_inst : entity work.async_div
	generic map (
	    STAGES => 28 )
	port map (
	    clk_in => clk_i,
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

end RTL;
