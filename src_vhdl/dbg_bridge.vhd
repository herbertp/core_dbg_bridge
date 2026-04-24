-----------------------------------------------------------------
--                     UART -> AXI Debug Bridge
--                              V1.0
--                        Ultra-Embedded.com
--                        Copyright 2017-2019
--
--                 Email: admin@ultra-embedded.com
--
--                       License: LGPL
-----------------------------------------------------------------
--
-- This source file may be used and distributed without
-- restriction provided that this copyright statement is not
-- removed from the file and that any derivative work contains
-- the original copyright notice and the associated disclaimer.
--
-- This source file is free software; you can redistribute it
-- and/or modify it under the terms of the GNU Lesser General
-- Public License as published by the Free Software Foundation;
-- either version 2.1 of the License, or (at your option) any
-- later version.
--
-- This source is distributed in the hope that it will be
-- useful, but WITHOUT ANY WARRANTY; without even the implied
-- warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
-- PURPOSE.  See the GNU Lesser General Public License for more
-- details.
--
-- You should have received a copy of the GNU Lesser General
-- Public License along with this source; if not, write to the
-- Free Software Foundation, Inc., 59 Temple Place, Suite 330,
-- Boston, MA  02111-1307  USA
-----------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dbg_bridge is
    generic (
        CLK_FREQ     : integer := 14745600;
        UART_SPEED   : integer := 115200;
        AXI_ID       : std_logic_vector(3 downto 0) := x"0";
        GPIO_ADDRESS : std_logic_vector(31 downto 0) := x"f0000000";
        STS_ADDRESS  : std_logic_vector(31 downto 0) := x"f0000004"
    );
    port (
        -- Inputs
        clk_i          : in  std_logic;
        rst_i          : in  std_logic;
        uart_rxd_i     : in  std_logic;
        mem_awready_i  : in  std_logic;
        mem_wready_i   : in  std_logic;
        mem_bvalid_i   : in  std_logic;
        mem_bresp_i    : in  std_logic_vector(1 downto 0);
        mem_bid_i      : in  std_logic_vector(3 downto 0);
        mem_arready_i  : in  std_logic;
        mem_rvalid_i   : in  std_logic;
        mem_rdata_i    : in  std_logic_vector(31 downto 0);
        mem_rresp_i    : in  std_logic_vector(1 downto 0);
        mem_rid_i      : in  std_logic_vector(3 downto 0);
        mem_rlast_i    : in  std_logic;
        gpio_inputs_i  : in  std_logic_vector(31 downto 0);

        -- Outputs
        uart_txd_o     : out std_logic;
        mem_awvalid_o  : out std_logic;
        mem_awaddr_o   : out std_logic_vector(31 downto 0);
        mem_awid_o     : out std_logic_vector(3 downto 0);
        mem_awlen_o    : out std_logic_vector(7 downto 0);
        mem_awburst_o  : out std_logic_vector(1 downto 0);
        mem_wvalid_o   : out std_logic;
        mem_wdata_o    : out std_logic_vector(31 downto 0);
        mem_wstrb_o    : out std_logic_vector(3 downto 0);
        mem_wlast_o    : out std_logic;
        mem_bready_o   : out std_logic;
        mem_arvalid_o  : out std_logic;
        mem_araddr_o   : out std_logic_vector(31 downto 0);
        mem_arid_o     : out std_logic_vector(3 downto 0);
        mem_arlen_o    : out std_logic_vector(7 downto 0);
        mem_arburst_o  : out std_logic_vector(1 downto 0);
        mem_rready_o   : out std_logic;
        gpio_outputs_o : out std_logic_vector(31 downto 0)
    );
end entity dbg_bridge;

architecture rtl of dbg_bridge is

    -- Defines
    constant REQ_WRITE  : std_logic_vector(7 downto 0) := x"10";
    constant REQ_READ   : std_logic_vector(7 downto 0) := x"11";

    type state_type is (
        STATE_IDLE, STATE_LEN,
        STATE_ADDR0, STATE_ADDR1, STATE_ADDR2, STATE_ADDR3,
        STATE_WRITE, STATE_READ,
        STATE_DATA0, STATE_DATA1, STATE_DATA2, STATE_DATA3
    );
    signal state_q, next_state_r : state_type;

    -- Wires / Regs
    signal uart_wr_w       : std_logic;
    signal uart_wr_data_w  : std_logic_vector(7 downto 0);
    signal uart_wr_busy_w  : std_logic;

    signal uart_rd_w       : std_logic;
    signal uart_rd_data_w  : std_logic_vector(7 downto 0);
    signal uart_rd_valid_w : std_logic;

    signal uart_rx_error_w : std_logic;

    signal tx_valid_w      : std_logic;
    signal tx_data_w       : std_logic_vector(7 downto 0);
    signal tx_accept_w     : std_logic;
    signal read_skip_w     : std_logic;

    signal rx_valid_w      : std_logic;
    signal rx_data_w       : std_logic_vector(7 downto 0);
    signal rx_accept_w     : std_logic;

    signal mem_addr_q      : std_logic_vector(31 downto 0);
    signal mem_busy_q      : std_logic;
    signal mem_wr_q        : std_logic;

    signal len_q           : unsigned(7 downto 0);

    -- Byte Index
    signal data_idx_q      : unsigned(1 downto 0);

    -- Word storage
    signal data_q          : std_logic_vector(31 downto 0);

    signal magic_addr_w    : boolean;

    signal uart_tx_pop_w   : std_logic;

    signal mem_awvalid_q   : std_logic;
    signal mem_wvalid_q    : std_logic;
    signal mem_arvalid_q   : std_logic;

    signal mem_sel_q       : std_logic_vector(3 downto 0);

    signal gpio_wr_q       : std_logic;
    signal gpio_output_q   : std_logic_vector(31 downto 0);

begin

    magic_addr_w <= (mem_addr_q = GPIO_ADDRESS or mem_addr_q = STS_ADDRESS);

    -- UART core
    u_uart : entity work.dbg_bridge_uart
        generic map (
            UART_DIVISOR_W => 32
        )
        port map (
            clk_i       => clk_i,
            rst_i       => rst_i,
            bit_div_i   => std_logic_vector(to_unsigned((CLK_FREQ / UART_SPEED) - 1, 32)),
            stop_bits_i => '0',
            wr_i        => uart_wr_w,
            data_i      => uart_wr_data_w,
            tx_busy_o   => uart_wr_busy_w,
            rd_i        => uart_rd_w,
            data_o      => uart_rd_data_w,
            rx_ready_o  => uart_rd_valid_w,
            rx_err_o    => uart_rx_error_w,
            rxd_i       => uart_rxd_i,
            txd_o       => uart_txd_o
        );

    -- Output FIFO
    uart_tx_pop_w <= not uart_wr_busy_w;

    u_fifo_tx : entity work.dbg_bridge_fifo
        generic map (
            WIDTH  => 8,
            DEPTH  => 8,
            ADDR_W => 3
        )
        port map (
            clk_i      => clk_i,
            rst_i      => rst_i,
            push_i     => tx_valid_w,
            data_in_i  => tx_data_w,
            accept_o   => tx_accept_w,
            pop_i      => uart_tx_pop_w,
            data_out_o => uart_wr_data_w,
            valid_o    => uart_wr_w
        );

    -- Input FIFO
    u_fifo_rx : entity work.dbg_bridge_fifo
        generic map (
            WIDTH  => 8,
            DEPTH  => 64,
            ADDR_W => 6
        )
        port map (
            clk_i      => clk_i,
            rst_i      => rst_i,
            push_i     => uart_rd_valid_w,
            data_in_i  => uart_rd_data_w,
            accept_o   => uart_rd_w,
            pop_i      => rx_accept_w,
            data_out_o => rx_data_w,
            valid_o    => rx_valid_w
        );

    -- State machine
    process(state_q, rx_valid_w, rx_data_w, mem_wr_q, len_q, mem_bvalid_i, magic_addr_w, mem_rvalid_i, read_skip_w, tx_accept_w)
    begin
        next_state_r <= state_q;

        case state_q is
            when STATE_IDLE =>
                if rx_valid_w = '1' then
                    if rx_data_w = REQ_WRITE or rx_data_w = REQ_READ then
                        next_state_r <= STATE_LEN;
                    end if;
                end if;

            when STATE_LEN =>
                if rx_valid_w = '1' then
                    next_state_r <= STATE_ADDR0;
                end if;

            when STATE_ADDR0 =>
                if rx_valid_w = '1' then
                    next_state_r <= STATE_ADDR1;
                end if;

            when STATE_ADDR1 =>
                if rx_valid_w = '1' then
                    next_state_r <= STATE_ADDR2;
                end if;

            when STATE_ADDR2 =>
                if rx_valid_w = '1' then
                    next_state_r <= STATE_ADDR3;
                end if;

            when STATE_ADDR3 =>
                if rx_valid_w = '1' then
                    if mem_wr_q = '1' then
                        next_state_r <= STATE_WRITE;
                    else
                        next_state_r <= STATE_READ;
                    end if;
                end if;

            when STATE_WRITE =>
                if len_q = 0 and (mem_bvalid_i = '1' or magic_addr_w) then
                    next_state_r <= STATE_IDLE;
                end if;

            when STATE_READ =>
                if mem_rvalid_i = '1' or magic_addr_w then
                    next_state_r <= STATE_DATA0;
                end if;

            when STATE_DATA0 =>
                if read_skip_w = '1' then
                    next_state_r <= STATE_DATA1;
                elsif tx_accept_w = '1' then
                    if len_q = 0 then
                        next_state_r <= STATE_IDLE;
                    else
                        next_state_r <= STATE_DATA1;
                    end if;
                end if;

            when STATE_DATA1 =>
                if read_skip_w = '1' then
                    next_state_r <= STATE_DATA2;
                elsif tx_accept_w = '1' then
                    if len_q = 0 then
                        next_state_r <= STATE_IDLE;
                    else
                        next_state_r <= STATE_DATA2;
                    end if;
                end if;

            when STATE_DATA2 =>
                if read_skip_w = '1' then
                    next_state_r <= STATE_DATA3;
                elsif tx_accept_w = '1' then
                    if len_q = 0 then
                        next_state_r <= STATE_IDLE;
                    else
                        next_state_r <= STATE_DATA3;
                    end if;
                end if;

            when STATE_DATA3 =>
                if tx_accept_w = '1' then
                    if len_q /= 0 then
                        next_state_r <= STATE_READ;
                    else
                        next_state_r <= STATE_IDLE;
                    end if;
                end if;

            when others =>
                next_state_r <= STATE_IDLE;
        end case;
    end process;

    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            state_q <= STATE_IDLE;
        elsif rising_edge(clk_i) then
            state_q <= next_state_r;
        end if;
    end process;

    -- RD/WR to and from UART
    tx_valid_w <= '1' when ((state_q = STATE_DATA0) or
                           (state_q = STATE_DATA1) or
                           (state_q = STATE_DATA2) or
                           (state_q = STATE_DATA3)) and read_skip_w = '0' else '0';

    rx_accept_w <= '1' when (state_q = STATE_IDLE) or
                            (state_q = STATE_LEN) or
                            (state_q = STATE_ADDR0) or
                            (state_q = STATE_ADDR1) or
                            (state_q = STATE_ADDR2) or
                            (state_q = STATE_ADDR3) or
                            (state_q = STATE_WRITE and mem_busy_q = '0') else '0';

    -- Capture length
    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            len_q <= (others => '0');
        elsif rising_edge(clk_i) then
            if state_q = STATE_LEN and rx_valid_w = '1' then
                len_q <= unsigned(rx_data_w);
            elsif state_q = STATE_WRITE and rx_valid_w = '1' and mem_busy_q = '0' then
                len_q <= len_q - 1;
            elsif state_q = STATE_READ and ((mem_busy_q = '1' and mem_rvalid_i = '1') or magic_addr_w) then
                len_q <= len_q - 1;
            elsif ((state_q = STATE_DATA0) or (state_q = STATE_DATA1) or (state_q = STATE_DATA2)) and (tx_accept_w = '1' and read_skip_w = '0') then
                len_q <= len_q - 1;
            end if;
        end if;
    end process;

    -- Capture addr
    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            mem_addr_q <= (others => '0');
        elsif rising_edge(clk_i) then
            if state_q = STATE_ADDR0 and rx_valid_w = '1' then
                mem_addr_q(31 downto 24) <= rx_data_w;
            elsif state_q = STATE_ADDR1 and rx_valid_w = '1' then
                mem_addr_q(23 downto 16) <= rx_data_w;
            elsif state_q = STATE_ADDR2 and rx_valid_w = '1' then
                mem_addr_q(15 downto 8) <= rx_data_w;
            elsif state_q = STATE_ADDR3 and rx_valid_w = '1' then
                mem_addr_q(7 downto 0) <= rx_data_w;
            elsif state_q = STATE_WRITE and (mem_busy_q = '1' and mem_bvalid_i = '1') then
                mem_addr_q <= std_logic_vector(unsigned(mem_addr_q(31 downto 2) & "00") + 4);
            elsif state_q = STATE_READ and (mem_busy_q = '1' and mem_rvalid_i = '1') then
                mem_addr_q <= std_logic_vector(unsigned(mem_addr_q(31 downto 2) & "00") + 4);
            end if;
        end if;
    end process;

    -- Data Index
    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            data_idx_q <= (others => '0');
        elsif rising_edge(clk_i) then
            if state_q = STATE_ADDR3 then
                data_idx_q <= unsigned(rx_data_w(1 downto 0));
            elsif state_q = STATE_WRITE and rx_valid_w = '1' and mem_busy_q = '0' then
                data_idx_q <= data_idx_q + 1;
            elsif ((state_q = STATE_DATA0) or (state_q = STATE_DATA1) or (state_q = STATE_DATA2)) and tx_accept_w = '1' and (data_idx_q /= 0) then
                data_idx_q <= data_idx_q - 1;
            end if;
        end if;
    end process;

    read_skip_w <= '1' when data_idx_q /= 0 else '0';

    -- Data Sample
    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            data_q <= (others => '0');
        elsif rising_edge(clk_i) then
            if state_q = STATE_WRITE and rx_valid_w = '1' and mem_busy_q = '0' then
                case data_idx_q is
                    when "00" => data_q(7 downto 0)   <= rx_data_w;
                    when "01" => data_q(15 downto 8)  <= rx_data_w;
                    when "10" => data_q(23 downto 16) <= rx_data_w;
                    when "11" => data_q(31 downto 24) <= rx_data_w;
                    when others => null;
                end case;
            elsif state_q = STATE_READ and mem_addr_q = GPIO_ADDRESS then
                data_q <= gpio_inputs_i;
            elsif state_q = STATE_READ and mem_addr_q = STS_ADDRESS then
                data_q <= x"cafe" & '0' & std_logic_vector(to_unsigned(0, 14)) & mem_busy_q;
            elsif state_q = STATE_READ and mem_rvalid_i = '1' then
                data_q <= mem_rdata_i;
            elsif ((state_q = STATE_DATA0) or (state_q = STATE_DATA1) or (state_q = STATE_DATA2)) and (tx_accept_w = '1' or read_skip_w = '1') then
                data_q <= x"00" & data_q(31 downto 8);
            end if;
        end if;
    end process;

    tx_data_w <= data_q(7 downto 0);
    mem_wdata_o <= data_q;

    -- AXI: Write Request
    process(clk_i, rst_i)
        variable mem_awvalid_r : std_logic;
        variable mem_wvalid_r  : std_logic;
    begin
        if rst_i = '1' then
            mem_awvalid_q <= '0';
            mem_wvalid_q  <= '0';
        elsif rising_edge(clk_i) then
            mem_awvalid_r := '0';
            mem_wvalid_r  := '0';

            if mem_awvalid_q = '1' and mem_awready_i = '0' then
                mem_awvalid_r := mem_awvalid_q;
            elsif mem_awvalid_q = '1' then
                mem_awvalid_r := '0';
            elsif state_q = STATE_WRITE and rx_valid_w = '1' and (data_idx_q = 3 or len_q = 1) then
                if not magic_addr_w then
                    mem_awvalid_r := '1';
                end if;
            end if;

            if mem_wvalid_q = '1' and mem_wready_i = '0' then
                mem_wvalid_r := mem_wvalid_q;
            elsif mem_wvalid_q = '1' then
                mem_wvalid_r := '0';
            elsif state_q = STATE_WRITE and rx_valid_w = '1' and (data_idx_q = 3 or len_q = 1) then
                if not magic_addr_w then
                    mem_wvalid_r := '1';
                end if;
            end if;

            mem_awvalid_q <= mem_awvalid_r;
            mem_wvalid_q  <= mem_wvalid_r;
        end if;
    end process;

    mem_awvalid_o <= mem_awvalid_q;
    mem_wvalid_o  <= mem_wvalid_q;
    mem_awaddr_o  <= mem_addr_q(31 downto 2) & "00";
    mem_awid_o    <= AXI_ID;
    mem_awlen_o   <= x"00";
    mem_awburst_o <= "01";
    mem_wlast_o   <= '1';
    mem_bready_o  <= '1';

    -- AXI: Read Request
    process(clk_i, rst_i)
        variable mem_arvalid_r : std_logic;
    begin
        if rst_i = '1' then
            mem_arvalid_q <= '0';
        elsif rising_edge(clk_i) then
            mem_arvalid_r := '0';

            if mem_arvalid_q = '1' and mem_arready_i = '0' then
                mem_arvalid_r := mem_arvalid_q;
            elsif mem_arvalid_q = '1' then
                mem_arvalid_r := '0';
            elsif state_q = STATE_READ and mem_busy_q = '0' then
                if not magic_addr_w then
                    mem_arvalid_r := '1';
                end if;
            end if;

            mem_arvalid_q <= mem_arvalid_r;
        end if;
    end process;

    mem_arvalid_o <= mem_arvalid_q;
    mem_araddr_o  <= mem_addr_q(31 downto 2) & "00";
    mem_arid_o    <= AXI_ID;
    mem_arlen_o   <= x"00";
    mem_arburst_o <= "01";
    mem_rready_o  <= '1';

    -- Write mask
    process(clk_i, rst_i)
        variable mem_sel_r : std_logic_vector(3 downto 0);
    begin
        if rst_i = '1' then
            mem_sel_q <= (others => '0');
        elsif rising_edge(clk_i) then
            if state_q = STATE_IDLE then
                mem_sel_q <= (others => '1');
            elsif state_q = STATE_WRITE and rx_valid_w = '1' and (data_idx_q = 3 or len_q = 1) then
                mem_sel_r := "1111";
                case data_idx_q is
                    when "00" => mem_sel_r := "0001";
                    when "01" => mem_sel_r := "0011";
                    when "10" => mem_sel_r := "0111";
                    when "11" => mem_sel_r := "1111";
                    when others => null;
                end case;

                case mem_addr_q(1 downto 0) is
                    when "00" => mem_sel_r := mem_sel_r and "1111";
                    when "01" => mem_sel_r := mem_sel_r and "1110";
                    when "10" => mem_sel_r := mem_sel_r and "1100";
                    when "11" => mem_sel_r := mem_sel_r and "1000";
                    when others => null;
                end case;
                mem_sel_q <= mem_sel_r;
            end if;
        end if;
    end process;

    mem_wstrb_o <= mem_sel_q;

    -- Write enable
    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            mem_wr_q <= '0';
        elsif rising_edge(clk_i) then
            if state_q = STATE_IDLE and rx_valid_w = '1' then
                if rx_data_w = REQ_WRITE then
                    mem_wr_q <= '1';
                else
                    mem_wr_q <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Access in progress
    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            mem_busy_q <= '0';
        elsif rising_edge(clk_i) then
            if mem_arvalid_q = '1' or mem_awvalid_q = '1' then
                mem_busy_q <= '1';
            elsif mem_bvalid_i = '1' or mem_rvalid_i = '1' then
                mem_busy_q <= '0';
            end if;
        end if;
    end process;

    -- GPIO Outputs
    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            gpio_wr_q <= '0';
        elsif rising_edge(clk_i) then
            if mem_addr_q = GPIO_ADDRESS and state_q = STATE_WRITE and rx_valid_w = '1' and (data_idx_q = 3 or len_q = 1) then
                gpio_wr_q <= '1';
            else
                gpio_wr_q <= '0';
            end if;
        end if;
    end process;

    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            gpio_output_q <= (others => '0');
        elsif rising_edge(clk_i) then
            if gpio_wr_q = '1' then
                gpio_output_q <= data_q;
            end if;
        end if;
    end process;

    gpio_outputs_o <= gpio_output_q;

end architecture rtl;
