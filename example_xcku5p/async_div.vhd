----------------------------------------------------------------------------
--  async_div.vhd
--	Synchronous Binary Divider (formerly Asynchronous)
--	Version 1.1
--
--  Copyright (C) 2013-2026 H.Poetzl
--
--	This program is free software: you can redistribute it and/or
--	modify it under the terms of the GNU General Public License
--	as published by the Free Software Foundation, either version
--	2 of the License, or (at your option) any later version.
--
----------------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.ALL;

library unisim;
use unisim.VCOMPONENTS.all;

use work.vivado_pkg.ALL;        -- Vivado Attributes


entity async_div is
    generic (
	STAGES	: natural := 8
    );
    port (
	clk_in	: in std_logic;		-- input clock
	--
	clk_out	: out std_logic		-- output clock
    );

end entity async_div;


architecture RTL of async_div is

    signal counter : unsigned(STAGES - 1 downto 0) := (others => '0');

begin

    process(clk_in)
    begin
        if rising_edge(clk_in) then
            counter <= counter + 1;
        end if;
    end process;

    clk_out <= counter(STAGES - 1);

end RTL;
