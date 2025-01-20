-- Phase Accumulator to convert omega to Theta
-- 2024 Dr.-Ing. Christian Noeding
-- christian.noeding@uni-kassel.de
-- 09.10.2024
--
-- This file contains an integrator to integrate omega to theta

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity phase_acc is
	PORT
	(
		clk			: in std_logic;
		omega			: in signed(31 downto 0); -- Q15.16 -- 2 * pi * frequency
		Ts				: in signed(31 downto 0); -- Q0.31
		sync_in		: in std_logic;

		theta			: out signed(31 downto 0); -- Q15.16 -- angle between 0 ... 2 * pi
		theta_phase	: out signed(31 downto 0); -- Q15.16 -- -90° phase shifted output of theta
		sync_out		: out std_logic
	);    
end phase_acc;

architecture behavioral of phase_acc is
	signal state		:	natural range 0 to 8 := 0;

	signal MUL_1 				: signed(23 downto 0) := to_signed(0, 24); -- Q1.21
	signal theta_int 			: signed(25 downto 0) := to_signed(0, 26); -- Q4.21
	signal theta_phase_int	: signed(25 downto 0) := to_signed(0, 26); -- Q4.21
	
	signal SUM,SUM2			: signed(25 downto 0) := to_signed(0, 26); -- Q4.21
	
	constant TWO_PI 			: signed(25 downto 0) := to_signed(13176795, 26); -- Q4.21
begin
	process(clk)
	begin
		if (rising_edge(clk)) then
			if (sync_in = '1' and state = 0) then
				MUL_1 <= resize(shift_right(omega * Ts, 26), 24); -- Q15.16 * Q0.31 = Qx.47 -> convert to Qx.21

				state <= 1; -- start of state-machine

			elsif (state = 1) then
				SUM <= MUL_1 + theta_int;
				
				state <= state + 1;
				
			elsif (state = 2) then
				if SUM >= TWO_PI then
					theta_int <= SUM - TWO_PI;
				elsif SUM < to_signed(0, 32) then
					theta_int <= SUM + TWO_PI;
				else
					theta_int <= SUM;
				end if;
				
				state <= state + 1;

			elsif (state = 3) then
				-- we shift theta by -pi/2 to get a theta to calculate alpha/beta
				-- as we are calculating Theta based on a 12-step alpha/beta based on the hall-signals
				-- we have to shift theta by +pi/12 to get the resulting alpha/beta in phase
				--SUM2 <= theta_int + to_signed(-2196132, 26); -- SUM2 + (-pi/2 + 2*pi/12) as Q4.21 -- problem like +pi/12, but on the right side of current
				--SUM2 <= theta_int + to_signed(-2470649, 26); -- SUM2 + (-pi/2 + 1.5*pi/12) as Q4.21
				SUM2 <= theta_int + to_signed(-2745166, 26); -- SUM2 + (-pi/2 + pi/12) as Q4.21 -- better current than without adding pi/12
				--SUM2 <= theta_int + to_signed(-3019682, 26); -- SUM2 + (-pi/2 + 0.5*pi/12) as Q4.21
				--SUM2 <= theta_int + to_signed(-3294199, 26); -- SUM2 - pi/2 as Q4.21 -- working in general, but spikes on current
				
				-- just shift by pi/12 to remove phase-shift due to Dual-SOGI
				--SUM2 <= theta_int + to_signed(549033, 26); -- SUM2 + (pi/12) as Q4.21
				
				state <= state + 1;

			elsif (state = 4) then
				if SUM2 >= TWO_PI then
					theta_phase_int <= SUM2 - TWO_PI; 
				elsif SUM2 < to_signed(0, 32) then
					theta_phase_int <= SUM2 + TWO_PI;
				else
					theta_phase_int <= SUM2;
				end if;
			
				state <= state + 1;

			elsif (state = 5) then
				-- set output and set sync-output
				theta <= resize(shift_right(theta_int, 5), 32); -- convert Q4.21 to Q15.16
				theta_phase <= resize(shift_right(theta_phase_int, 5), 32); -- convert Q4.21 to Q15.16
			
				sync_out <= '1';

				state <= state + 1;

			elsif (state = 6) then
				sync_out <= '0';
				
				state <= 0;
				
			end if;
		end if;
	end process;
end behavioral;