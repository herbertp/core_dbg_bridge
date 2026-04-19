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

entity dbg_bridge_uart is
    generic (
        UART_DIVISOR_W : integer := 9
    );
    port (
        -- Clock & Reset
        clk_i       : in  std_logic;
        rst_i       : in  std_logic;

        -- Control
        bit_div_i   : in  std_logic_vector(UART_DIVISOR_W-1 downto 0);
        stop_bits_i : in  std_logic; -- 0 = 1, 1 = 2

        -- Transmit
        wr_i        : in  std_logic;
        data_i      : in  std_logic_vector(7 downto 0);
        tx_busy_o   : out std_logic;

        -- Receive
        rd_i        : in  std_logic;
        data_o      : out std_logic_vector(7 downto 0);
        rx_ready_o  : out std_logic;

        rx_err_o    : out std_logic;

        -- UART pins
        rxd_i       : in  std_logic;
        txd_o       : out std_logic
    );
end entity dbg_bridge_uart;

architecture rtl of dbg_bridge_uart is

    constant START_BIT : unsigned(3 downto 0) := x"0";
    constant STOP_BIT0 : unsigned(3 downto 0) := x"9";
    constant STOP_BIT1 : unsigned(3 downto 0) := x"A";

    -- TX Signals
    signal tx_busy_q      : std_logic;
    signal tx_bits_q      : unsigned(3 downto 0);
    signal tx_count_q     : unsigned(UART_DIVISOR_W-1 downto 0);
    signal tx_shift_reg_q : std_logic_vector(7 downto 0);
    signal txd_q          : std_logic;

    -- RX Signals
    signal rxd_q          : std_logic;
    signal rx_data_q      : std_logic_vector(7 downto 0);
    signal rx_bits_q      : unsigned(3 downto 0);
    signal rx_count_q     : unsigned(UART_DIVISOR_W-1 downto 0);
    signal rx_shift_reg_q : std_logic_vector(7 downto 0);
    signal rx_ready_q     : std_logic;
    signal rx_busy_q      : std_logic;

    signal rx_err_q       : std_logic;

    -- Re-sync RXD
    signal rxd_ms_q       : std_logic;

    signal rx_sample_w    : boolean;
    signal tx_sample_w    : boolean;

begin

    -- Re-sync RXD
    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            rxd_ms_q <= '1';
            rxd_q    <= '1';
        elsif rising_edge(clk_i) then
            rxd_ms_q <= rxd_i;
            rxd_q    <= rxd_ms_q;
        end if;
    end process;

    -- RX Clock Divider
    rx_sample_w <= rx_count_q = 0;

    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            rx_count_q <= (others => '0');
        elsif rising_edge(clk_i) then
            if rx_busy_q = '0' then
                rx_count_q <= unsigned('0' & bit_div_i(UART_DIVISOR_W-1 downto 1));
            elsif rx_count_q /= 0 then
                rx_count_q <= rx_count_q - 1;
            elsif rx_sample_w then
                if (rx_bits_q = STOP_BIT0 and stop_bits_i = '0') or (rx_bits_q = STOP_BIT1 and stop_bits_i = '1') then
                    rx_count_q <= (others => '0');
                else
                    rx_count_q <= unsigned(bit_div_i);
                end if;
            end if;
        end if;
    end process;

    -- RX Shift Register
    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            rx_shift_reg_q <= (others => '0');
            rx_busy_q      <= '0';
        elsif rising_edge(clk_i) then
            if rx_busy_q = '1' and rx_sample_w then
                if (rx_bits_q = STOP_BIT0 and stop_bits_i = '0') or (rx_bits_q = STOP_BIT1 and stop_bits_i = '1') then
                    rx_busy_q <= '0';
                elsif rx_bits_q = START_BIT then
                    if rxd_q = '1' then
                        rx_busy_q <= '0';
                    end if;
                else
                    rx_shift_reg_q <= rxd_q & rx_shift_reg_q(7 downto 1);
                end if;
            elsif rx_busy_q = '0' and rxd_q = '0' then
                rx_shift_reg_q <= (others => '0');
                rx_busy_q      <= '1';
            end if;
        end if;
    end process;

    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            rx_bits_q <= START_BIT;
        elsif rising_edge(clk_i) then
            if rx_sample_w and rx_busy_q = '1' then
                if (rx_bits_q = STOP_BIT1 and stop_bits_i = '1') or (rx_bits_q = STOP_BIT0 and stop_bits_i = '0') then
                    rx_bits_q <= START_BIT;
                else
                    rx_bits_q <= rx_bits_q + 1;
                end if;
            elsif rx_busy_q = '0' and (unsigned(bit_div_i) = 0) then
                rx_bits_q <= START_BIT + 1;
            elsif rx_busy_q = '0' then
                rx_bits_q <= START_BIT;
            end if;
        end if;
    end process;

    -- RX Data
    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            rx_ready_q <= '0';
            rx_data_q  <= (others => '0');
            rx_err_q   <= '0';
        elsif rising_edge(clk_i) then
            if rd_i = '1' then
                rx_ready_q <= '0';
                rx_err_q   <= '0';
            end if;

            if rx_busy_q = '1' and rx_sample_w then
                if (rx_bits_q = STOP_BIT1 and stop_bits_i = '1') or (rx_bits_q = STOP_BIT0 and stop_bits_i = '0') then
                    if rxd_q = '1' then
                        rx_data_q  <= rx_shift_reg_q;
                        rx_ready_q <= '1';
                    else
                        rx_ready_q <= '0';
                        rx_data_q  <= (others => '0');
                        rx_err_q   <= '1';
                    end if;
                elsif rx_bits_q = START_BIT and rxd_q = '1' then
                    rx_err_q <= '1';
                end if;
            end if;
        end if;
    end process;

    -- TX Clock Divider
    tx_sample_w <= tx_count_q = 0;

    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            tx_count_q <= (others => '0');
        elsif rising_edge(clk_i) then
            if tx_busy_q = '0' then
                tx_count_q <= unsigned(bit_div_i);
            elsif tx_count_q /= 0 then
                tx_count_q <= tx_count_q - 1;
            elsif tx_sample_w then
                tx_count_q <= unsigned(bit_div_i);
            end if;
        end if;
    end process;

    -- TX Shift Register
    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            tx_shift_reg_q <= (others => '0');
            tx_busy_q      <= '0';
        elsif rising_edge(clk_i) then
            if tx_busy_q = '1' then
                if tx_bits_q /= START_BIT and tx_sample_w then
                    tx_shift_reg_q <= '0' & tx_shift_reg_q(7 downto 1);
                end if;

                if tx_bits_q = STOP_BIT0 and tx_sample_w and stop_bits_i = '0' then
                    tx_busy_q <= '0';
                elsif tx_bits_q = STOP_BIT1 and tx_sample_w and stop_bits_i = '1' then
                    tx_busy_q <= '0';
                end if;
            elsif wr_i = '1' then
                tx_shift_reg_q <= data_i;
                tx_busy_q      <= '1';
            end if;
        end if;
    end process;

    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            tx_bits_q <= (others => '0');
        elsif rising_edge(clk_i) then
            if tx_sample_w and tx_busy_q = '1' then
                if (tx_bits_q = STOP_BIT1 and stop_bits_i = '1') or (tx_bits_q = STOP_BIT0 and stop_bits_i = '0') then
                    tx_bits_q <= START_BIT;
                else
                    tx_bits_q <= tx_bits_q + 1;
                end if;
            end if;
        end if;
    end process;

    -- UART Tx Pin
    process(clk_i, rst_i)
        variable txd_r : std_logic;
    begin
        if rst_i = '1' then
            txd_q <= '1';
        elsif rising_edge(clk_i) then
            txd_r := '1';
            if tx_busy_q = '1' then
                if tx_bits_q = START_BIT then
                    txd_r := '0';
                elsif tx_bits_q = STOP_BIT0 or tx_bits_q = STOP_BIT1 then
                    txd_r := '1';
                else
                    txd_r := tx_shift_reg_q(0);
                end if;
            end if;
            txd_q <= txd_r;
        end if;
    end process;

    -- Outputs
    tx_busy_o  <= tx_busy_q;
    rx_ready_o <= rx_ready_q;
    txd_o      <= txd_q;
    data_o     <= rx_data_q;
    rx_err_o   <= rx_err_q;

end architecture rtl;
