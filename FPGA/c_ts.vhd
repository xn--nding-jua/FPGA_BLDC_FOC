LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity c_ts is
	PORT
	(
		Ts					: out signed(31 downto 0) := to_signed(21475, 32) 		-- Q0.31
	);    
end c_ts;

architecture behavioral of c_ts is   
begin
end behavioral;