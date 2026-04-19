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

entity dbg_bridge_fifo is
    generic (
        WIDTH   : integer := 8;
        DEPTH   : integer := 4;
        ADDR_W  : integer := 2
    );
    port (
        -- Inputs
        clk_i      : in  std_logic;
        rst_i      : in  std_logic;
        data_in_i  : in  std_logic_vector(WIDTH-1 downto 0);
        push_i     : in  std_logic;
        pop_i      : in  std_logic;

        -- Outputs
        data_out_o : out std_logic_vector(WIDTH-1 downto 0);
        accept_o   : out std_logic;
        valid_o    : out std_logic
    );
end entity dbg_bridge_fifo;

architecture rtl of dbg_bridge_fifo is
    constant COUNT_W : integer := ADDR_W + 1;

    type ram_type is array (0 to DEPTH-1) of std_logic_vector(WIDTH-1 downto 0);
    signal ram_q     : ram_type;
    signal rd_ptr_q  : unsigned(ADDR_W-1 downto 0);
    signal wr_ptr_q  : unsigned(ADDR_W-1 downto 0);
    signal count_q   : unsigned(COUNT_W-1 downto 0);

    signal accept_w  : std_logic;
    signal valid_w   : std_logic;

begin

    valid_w  <= '1' when count_q /= to_unsigned(0, COUNT_W) else '0';
    accept_w <= '1' when count_q /= to_unsigned(DEPTH, COUNT_W) else '0';

    process(clk_i, rst_i)
    begin
        if rst_i = '1' then
            count_q   <= (others => '0');
            rd_ptr_q  <= (others => '0');
            wr_ptr_q  <= (others => '0');
        elsif rising_edge(clk_i) then
            -- Push
            if push_i = '1' and accept_w = '1' then
                ram_q(to_integer(wr_ptr_q)) <= data_in_i;
                wr_ptr_q <= wr_ptr_q + 1;
            end if;

            -- Pop
            if pop_i = '1' and valid_w = '1' then
                rd_ptr_q <= rd_ptr_q + 1;
            end if;

            -- Count up
            if (push_i = '1' and accept_w = '1') and not (pop_i = '1' and valid_w = '1') then
                count_q <= count_q + 1;
            -- Count down
            elsif not (push_i = '1' and accept_w = '1') and (pop_i = '1' and valid_w = '1') then
                count_q <= count_q - 1;
            end if;
        end if;
    end process;

    valid_o    <= valid_w;
    accept_o   <= accept_w;
    data_out_o <= ram_q(to_integer(rd_ptr_q));

end architecture rtl;
