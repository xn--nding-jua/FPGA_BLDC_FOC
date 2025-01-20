-- Clock-Divider
-- 2024 Dr.-Ing. Christian Noeding
-- christian.noeding@uni-kassel.de
-- 08.10.2024
--
-- This file reduces an input-clock by factor x to a slower clock

LIBRARY IEEE;    
USE IEEE.STD_LOGIC_1164.ALL;    

entity clk_by_x is
	generic(
		clk_in_freq		:	natural := 12288000;
		clk_out_freq	:	natural := 192000
	);
	port (
	  clk_in				: in std_logic;
	  clk_out 			: out std_logic
	);
end clk_by_x;

architecture Behavioral of clk_by_x is
    signal count : integer range 0 to 200000 := 1;
    signal b : std_logic :='0';
begin
    process(clk_in)     
    begin
        if(rising_edge(clk_in)) then
            if (count = (clk_in_freq/(2*clk_out_freq))) then
					b <= not b;
					count <= 1;
				else
					count <= count + 1;
            end if;
        end if;
    end process;

    clk_out<=b;
end;
