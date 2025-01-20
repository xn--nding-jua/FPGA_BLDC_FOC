LIBRARY IEEE;    
USE IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all; 

entity bitshl is
	generic(
		bits_input				: integer := 32;
		bits_output				: integer := 24;
		bits_to_shift_left	: integer := 0;
		bits_to_shift_right	: integer := 0
	);
	port (
		clk			: in std_logic;
		signal_in	: in signed(bits_input - 1 downto 0);
		signal_out	: out signed(bits_output - 1 downto 0)
	);
end bitshl;

architecture Behavioral of bitshl is
begin
	process(clk)
	begin
		if (rising_edge(clk)) then
			signal_out <= resize(shift_right(shift_left(signal_in, bits_to_shift_left), bits_to_shift_right), signal_out'length);
		end if;
	end process;
end;
