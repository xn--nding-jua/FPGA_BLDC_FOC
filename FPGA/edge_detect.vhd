-- Edge-Detection
-- 2024 Dr.-Ing. Christian Noeding
-- christian.noeding@uni-kassel.de
-- 08.10.2024
--
-- This file outputs a rising- or falling-signal for one single clock

LIBRARY IEEE;    
USE IEEE.STD_LOGIC_1164.ALL;    

entity edge_detect is
	port (
	  clk			: in std_logic;
	  signal_in	: in std_logic;
	  rising		: out std_logic;
	  falling	: out std_logic
	);
end edge_detect;

architecture Behavioral of edge_detect is
	signal zsignal, zzsignal, zzzsignal 	: std_logic;
begin
	process(clk)
	begin
		if(rising_edge(clk)) then
			zsignal <= signal_in;
			zzsignal <= zsignal;
			zzzsignal <= zzsignal;
			if zzsignal = '1' and zzzsignal = '0' then
				-- rising edge detected
				rising <= '1';
				falling <= '0';
			elsif zzsignal = '0' and zzzsignal = '1' then
				-- falling edge detected
				rising <= '0';
				falling <= '1';
			else
				rising <= '0';
				falling <= '0';
			end if;
		end if;
	end process;
end;
