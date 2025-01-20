-- DeadTime-generator for PWM signals
-- 30.04.2014 Dr.-Ing. Christian Felgemacher
-- 08.10.2024 Dr.-Ing. Christian Noeding
-- christian.noeding@uni-kassel.de
--
-- This file delays the rising of an input signal for several clocks. Number of clocks can be
-- controlled by the dt-signal.
-- This module is loosely based on http://www.lothar-miller.de/s9y/archives/58-Totzeit-fuer-H-Bruecke.html

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity PWM_DT_delay is
	Port (
		clk  	: in std_logic;
		dt   	: in unsigned(7 downto 0); -- number of ticks define the length of delay together with clk-frequency
		inp 	: in std_logic;
		outp 	: out std_logic := '0'
	);
end PWM_DT_delay;

architecture Behavioral of PWM_DT_delay is
begin
	process(clk)
		variable delayCounter : integer range 0 to 255 := 0;
	begin
		if rising_edge(clk) then
			if (inp='0') then
				-- turn off output immediately without any delay
				outp  <= '0';
				delayCounter := 0;
			else
				-- turn on: count down delayCounter, than turn on signal
				if (delayCounter < dt) then
					-- still counting
					delayCounter := delayCounter + 1;
					outp <= '0';
				else            
					-- turn on
					outp <= '1';
				end if;
			end if;
		end if;
	end process;
end Behavioral;
