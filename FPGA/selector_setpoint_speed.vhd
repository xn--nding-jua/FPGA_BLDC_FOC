-- Selector for position or speed-controller
-- 2024 Dr.-Ing. Christian Noeding
-- christian.noeding@uni-kassel.de
-- 15.10.2024
--
-- This file selects between static speed-setpoint or position-controller

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity selector_setpoint_speed is
  port( 
    clk       		: in std_logic;
	 position		: in signed(31 downto 0); -- Q15.16
	 speed			: in signed(31 downto 0); -- Q15.16
	 position_ctrl	: in std_logic;
	 sync_in			: in std_logic;
	 
    setpoint		: out signed(31 downto 0); -- Q15.16
	 sync_out		: out std_logic
  );
end selector_setpoint_speed;

architecture behavioural of selector_setpoint_speed is
begin
	process(clk)
	begin
		if rising_edge(clk) then
			if (position_ctrl = '1') then
				setpoint <= position;
			else
				setpoint <= speed;
			end if;
		
			sync_out <= sync_in;
		end if;
	end process;
end behavioural;
