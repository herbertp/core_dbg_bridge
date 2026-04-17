library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top is
    port (
        clk_i      : in  std_logic;
        rst_i      : in  std_logic;
        uart_rxd_i : in  std_logic;
        uart_txd_o : out std_logic
    );
end entity top;

architecture rtl of top is

    -- Internal AXI signals
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

    -- Component declaration for Block Memory Generator (IP)
    component blk_mem_gen_0 is
        port (
            clka  : in  std_logic;
            rsta  : in  std_logic;
            ena   : in  std_logic;
            wea   : in  std_logic_vector(3 downto 0);
            addra : in  std_logic_vector(13 downto 0);
            dina  : in  std_logic_vector(31 downto 0);
            douta : out std_logic_vector(31 downto 0)
        );
    end component;

    -- Component declaration for AXI BRAM Controller (IP)
    component axi_bram_ctrl_0 is
        port (
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
            bram_addr_a   : out std_logic_vector(13 downto 0);
            bram_wrdata_a : out std_logic_vector(31 downto 0);
            bram_rddata_a : in  std_logic_vector(31 downto 0)
        );
    end component;

    signal rst_n : std_logic;

    -- BRAM interface signals
    signal bram_rst_a    : std_logic;
    signal bram_clk_a    : std_logic;
    signal bram_en_a     : std_logic;
    signal bram_we_a     : std_logic_vector(3 downto 0);
    signal bram_addr_a   : std_logic_vector(13 downto 0);
    signal bram_wrdata_a : std_logic_vector(31 downto 0);
    signal bram_rddata_a : std_logic_vector(31 downto 0);

begin

    rst_n <= not rst_i;

    -- Instantiate Debug Bridge
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

    -- Instantiate AXI BRAM Controller
    -- Note: Address is truncated to 16 bits for the BRAM controller in this example
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

    -- Instantiate Block Memory
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

end architecture rtl;
