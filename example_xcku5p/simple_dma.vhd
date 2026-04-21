----------------------------------------------------------------------------
--  simple_dma.vhd
--	Simple AXI4 DMA for DDR4 Copy
--	Version 1.0
--
--  Copyright (C) 2026 H.Poetzl
--
--	This program is free software: you can redistribute it and/or
--	modify it under the terms of the GNU General Public License
--	as published by the Free Software Foundation, either version
--	2 of the License, or (at your option) any later version.
----------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.ALL;

entity simple_dma is
    generic (
        C_M_AXI_DATA_WIDTH : integer := 256;
        C_M_AXI_ADDR_WIDTH : integer := 32;
        C_S_AXI_DATA_WIDTH : integer := 32;
        C_S_AXI_ADDR_WIDTH : integer := 4
    );
    port (
        -- Global signals
        clk_i          : in  std_logic;
        rst_i          : in  std_logic;

        -- AXI4-Lite Slave Interface (Configuration)
        s_axi_awaddr   : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        s_axi_awvalid  : in  std_logic;
        s_axi_awready  : out std_logic;
        s_axi_wdata    : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        s_axi_wstrb    : in  std_logic_vector(C_S_AXI_DATA_WIDTH/8-1 downto 0);
        s_axi_wvalid   : in  std_logic;
        s_axi_wready   : out std_logic;
        s_axi_bresp    : out std_logic_vector(1 downto 0);
        s_axi_bvalid   : out std_logic;
        s_axi_bready   : in  std_logic;
        s_axi_araddr   : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        s_axi_arvalid  : in  std_logic;
        s_axi_arready  : out std_logic;
        s_axi_rdata    : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        s_axi_rresp    : out std_logic_vector(1 downto 0);
        s_axi_rvalid   : out std_logic;
        s_axi_rready   : in  std_logic;

        -- AXI4 Master Interface (Data)
        m_axi_awaddr   : out std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0);
        m_axi_awlen    : out std_logic_vector(7 downto 0);
        m_axi_awsize   : out std_logic_vector(2 downto 0);
        m_axi_awburst  : out std_logic_vector(1 downto 0);
        m_axi_awlock   : out std_logic;
        m_axi_awcache  : out std_logic_vector(3 downto 0);
        m_axi_awprot   : out std_logic_vector(2 downto 0);
        m_axi_awvalid  : out std_logic;
        m_axi_awready  : in  std_logic;
        m_axi_wdata    : out std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
        m_axi_wstrb    : out std_logic_vector(C_M_AXI_DATA_WIDTH/8-1 downto 0);
        m_axi_wlast    : out std_logic;
        m_axi_wvalid   : out std_logic;
        m_axi_wready   : in  std_logic;
        m_axi_bresp    : in  std_logic_vector(1 downto 0);
        m_axi_bvalid   : in  std_logic;
        m_axi_bready   : out std_logic;
        m_axi_araddr   : out std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0);
        m_axi_arlen    : out std_logic_vector(7 downto 0);
        m_axi_arsize   : out std_logic_vector(2 downto 0);
        m_axi_arburst  : out std_logic_vector(1 downto 0);
        m_axi_arlock   : out std_logic;
        m_axi_arcache  : out std_logic_vector(3 downto 0);
        m_axi_arprot   : out std_logic_vector(2 downto 0);
        m_axi_arvalid  : out std_logic;
        m_axi_arready  : in  std_logic;
        m_axi_rdata    : in  std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
        m_axi_rresp    : in  std_logic_vector(1 downto 0);
        m_axi_rlast    : in  std_logic;
        m_axi_rvalid   : in  std_logic;
        m_axi_rready   : out std_logic;

        -- Status
        busy_o         : out std_logic
    );
end entity simple_dma;

architecture RTL of simple_dma is

    -- Registers
    signal reg_src_addr : std_logic_vector(31 downto 0);
    signal reg_dst_addr : std_logic_vector(31 downto 0);
    signal reg_length   : std_logic_vector(31 downto 0);
    signal reg_start    : std_logic;
    signal reg_busy     : std_logic;

    -- FIFO (simple synchronous)
    constant FIFO_DEPTH : integer := 512;
    type fifo_mem_t is array (0 to FIFO_DEPTH-1) of std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
    signal fifo_mem : fifo_mem_t;
    signal fifo_wr_ptr : unsigned(8 downto 0) := (others => '0');
    signal fifo_rd_ptr : unsigned(8 downto 0) := (others => '0');
    signal fifo_count  : unsigned(9 downto 0) := (others => '0');

    signal fifo_full  : std_logic;
    signal fifo_empty : std_logic;
    signal fifo_we    : std_logic;
    signal fifo_re    : std_logic;

    -- Control logic
    type state_t is (IDLE, RUNNING, DONE);
    signal state : state_t := IDLE;

    -- Read Master signals
    type rstate_t is (R_IDLE, R_ADDR, R_DATA);
    signal rstate : rstate_t := R_IDLE;
    signal r_addr : unsigned(31 downto 0);
    signal r_len  : unsigned(31 downto 0);

    -- Write Master signals
    type wstate_t is (W_IDLE, W_ADDR, W_DATA, W_RESP);
    signal wstate : wstate_t := W_IDLE;
    signal w_addr : unsigned(31 downto 0);
    signal w_len  : unsigned(31 downto 0);
    signal w_beats : unsigned(7 downto 0);

begin

    busy_o <= reg_busy;

    --------------------------------------------------------------------
    -- AXI-Lite Slave (Registers)
    --------------------------------------------------------------------

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                s_axi_awready <= '0';
                s_axi_wready  <= '0';
                s_axi_bvalid  <= '0';
                s_axi_arready <= '0';
                s_axi_rvalid  <= '0';
                reg_src_addr  <= (others => '0');
                reg_dst_addr  <= (others => '0');
                reg_length    <= (others => '0');
                reg_start     <= '0';
            else
                reg_start <= '0'; -- Auto-clear

                -- Write channel
                if s_axi_awvalid = '1' and s_axi_awready = '0' then
                    s_axi_awready <= '1';
                elsif s_axi_wvalid = '1' and s_axi_wready = '0' then
                    s_axi_wready <= '1';
                    case s_axi_awaddr(3 downto 2) is
                        when "00" => reg_start <= s_axi_wdata(0);
                        when "01" => reg_src_addr <= s_axi_wdata;
                        when "10" => reg_dst_addr <= s_axi_wdata;
                        when "11" => reg_length   <= s_axi_wdata;
                        when others => null;
                    end case;
                elsif s_axi_bready = '1' and s_axi_bvalid = '1' then
                    s_axi_bvalid <= '0';
                elsif s_axi_awready = '1' and s_axi_wready = '1' then
                    s_axi_awready <= '0';
                    s_axi_wready  <= '0';
                    s_axi_bvalid  <= '1';
                    s_axi_bresp   <= "00";
                end if;

                -- Read channel
                if s_axi_arvalid = '1' and s_axi_arready = '0' then
                    s_axi_arready <= '1';
                elsif s_axi_arready = '1' then
                    s_axi_arready <= '0';
                    s_axi_rvalid  <= '1';
                    s_axi_rresp   <= "00";
                    case s_axi_araddr(3 downto 2) is
                        when "00" => s_axi_rdata <= (0 => reg_busy, others => '0');
                        when "01" => s_axi_rdata <= reg_src_addr;
                        when "10" => s_axi_rdata <= reg_dst_addr;
                        when "11" => s_axi_rdata <= reg_length;
                        when others => s_axi_rdata <= (others => '0');
                    end case;
                elsif s_axi_rready = '1' and s_axi_rvalid = '1' then
                    s_axi_rvalid <= '0';
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- FIFO logic
    --------------------------------------------------------------------

    fifo_full  <= '1' when fifo_count = FIFO_DEPTH else '0';
    fifo_empty <= '1' when fifo_count = 0 else '0';

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' or (state = IDLE and reg_start = '1') then
                fifo_wr_ptr <= (others => '0');
                fifo_rd_ptr <= (others => '0');
                fifo_count  <= (others => '0');
            else
                if fifo_we = '1' and fifo_full = '0' then
                    fifo_mem(to_integer(fifo_wr_ptr)) <= m_axi_rdata;
                    fifo_wr_ptr <= fifo_wr_ptr + 1;
                end if;
                if fifo_re = '1' and fifo_empty = '0' then
                    fifo_rd_ptr <= fifo_rd_ptr + 1;
                end if;

                if (fifo_we = '1' and fifo_full = '0') and not (fifo_re = '1' and fifo_empty = '0') then
                    fifo_count <= fifo_count + 1;
                elsif not (fifo_we = '1' and fifo_full = '0') and (fifo_re = '1' and fifo_empty = '0') then
                    fifo_count <= fifo_count - 1;
                end if;
            end if;
        end if;
    end process;

    m_axi_wdata <= fifo_mem(to_integer(fifo_rd_ptr));

    --------------------------------------------------------------------
    -- DMA Control State Machine
    --------------------------------------------------------------------

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                state <= IDLE;
                reg_busy <= '0';
            else
                case state is
                    when IDLE =>
                        if reg_start = '1' then
                            state <= RUNNING;
                            reg_busy <= '1';
                        end if;
                    when RUNNING =>
                        if rstate = R_IDLE and wstate = W_IDLE and r_len = 0 and w_len = 0 and fifo_empty = '1' then
                            state <= DONE;
                        end if;
                    when DONE =>
                        reg_busy <= '0';
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Read Master (Source)
    --------------------------------------------------------------------

    m_axi_arsize  <= "101"; -- 32 bytes (256-bit)
    m_axi_arburst <= "01";  -- INCR
    m_axi_arlock  <= '0';
    m_axi_arcache <= "0011";
    m_axi_arprot  <= "000";

    process(clk_i)
        variable burst_len : unsigned(7 downto 0);
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                rstate <= R_IDLE;
                m_axi_arvalid <= '0';
                m_axi_rready  <= '0';
                r_len <= (others => '0');
            else
                case rstate is
                    when R_IDLE =>
                        if state = IDLE and reg_start = '1' then
                            r_addr <= unsigned(reg_src_addr);
                            r_len  <= unsigned(reg_length);
                            rstate <= R_ADDR;
                        end if;

                    when R_ADDR =>
                        if r_len > 0 then
                            m_axi_araddr <= std_logic_vector(r_addr);
                            -- Max burst 16 beats to avoid overrunning FIFO (FIFO_DEPTH=512 is plenty, but let's be safe)
                            if r_len > 16*32 then
                                burst_len := x"0F"; -- 16 beats
                            else
                                burst_len := resize(shift_right(r_len, 5) - 1, 8);
                            end if;
                            m_axi_arlen <= std_logic_vector(burst_len);
                            m_axi_arvalid <= '1';
                            rstate <= R_DATA;
                        else
                            rstate <= R_IDLE;
                        end if;

                    when R_DATA =>
                        if m_axi_arready = '1' then
                            m_axi_arvalid <= '0';
                        end if;
                        m_axi_rready <= not fifo_full;
                        if m_axi_rvalid = '1' and fifo_full = '0' then
                            r_addr <= r_addr + 32;
                            r_len  <= r_len - 32;
                            if m_axi_rlast = '1' then
                                m_axi_rready <= '0';
                                rstate <= R_ADDR;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;

    fifo_we <= m_axi_rvalid and not fifo_full;

    --------------------------------------------------------------------
    -- Write Master (Destination)
    --------------------------------------------------------------------

    m_axi_awsize  <= "101"; -- 32 bytes (256-bit)
    m_axi_awburst <= "01";  -- INCR
    m_axi_awlock  <= '0';
    m_axi_awcache <= "0011";
    m_axi_awprot  <= "000";
    m_axi_wstrb   <= (others => '1');

    process(clk_i)
        variable burst_len : unsigned(7 downto 0);
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                wstate <= W_IDLE;
                m_axi_awvalid <= '0';
                m_axi_wvalid  <= '0';
                m_axi_bready  <= '0';
                w_len <= (others => '0');
            else
                case wstate is
                    when W_IDLE =>
                        if state = IDLE and reg_start = '1' then
                            w_addr <= unsigned(reg_dst_addr);
                            w_len  <= unsigned(reg_length);
                            wstate <= W_ADDR;
                        end if;

                    when W_ADDR =>
                        if w_len > 0 then
                            -- Wait for enough data in FIFO or end of transfer
                            if fifo_count >= 16 or (r_len = 0 and fifo_count >= shift_right(w_len, 5)) then
                                m_axi_awaddr <= std_logic_vector(w_addr);
                                if w_len > 16*32 then
                                    burst_len := x"0F";
                                else
                                    burst_len := resize(shift_right(w_len, 5) - 1, 8);
                                end if;
                                w_beats <= burst_len;
                                m_axi_awlen <= std_logic_vector(burst_len);
                                m_axi_awvalid <= '1';
                                wstate <= W_DATA;
                            end if;
                        else
                            wstate <= W_IDLE;
                        end if;

                    when W_DATA =>
                        if m_axi_awready = '1' then
                            m_axi_awvalid <= '0';
                        end if;
                        if m_axi_wvalid = '0' or m_axi_wready = '1' then
                            if fifo_empty = '0' then
                                m_axi_wvalid <= '1';
                                if w_beats = 0 then
                                    m_axi_wlast <= '1';
                                else
                                    m_axi_wlast <= '0';
                                end if;
                            else
                                m_axi_wvalid <= '0';
                            end if;
                        end if;

                        if m_axi_wvalid = '1' and m_axi_wready = '1' then
                            w_addr <= w_addr + 32;
                            w_len  <= w_len - 32;
                            if w_beats = 0 then
                                m_axi_wvalid <= '0';
                                m_axi_wlast  <= '0';
                                m_axi_bready <= '1';
                                wstate <= W_RESP;
                            else
                                w_beats <= w_beats - 1;
                            end if;
                        end if;

                    when W_RESP =>
                        if m_axi_bvalid = '1' then
                            m_axi_bready <= '0';
                            wstate <= W_ADDR;
                        end if;
                end case;
            end if;
        end if;
    end process;

    fifo_re <= m_axi_wvalid and m_axi_wready;

end RTL;
