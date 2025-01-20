-- Theta-generator
-- 2024 Dr.-Ing. Christian Noeding
-- christian.noeding@uni-kassel.de
-- 08.10.2024
--
-- This file calculates a theta-angle-signal based on the given frequency-information

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gen_theta is
	generic(
		f_pwm		: integer := 16000;
		f_ref		: integer := 50
		);
	port
	(
		clk		: in std_logic;
		frequency: in signed(31 downto 0); -- Q15.16
		sync_in	: in std_logic; -- sync_ed with PWM-clock
		
		theta		: out signed(31 downto 0); -- Q15.16
		sync_out : out std_logic
	);    
end gen_theta;

architecture behaviour of gen_theta is
	-- with Q15.16 the counter-increment defines a minimum f_ref of 0.38 Hz.
	-- so we are working with Q3.28 internally and convert it to Q15.16 at the end

	signal state		:	natural range 0 to 3 := 0;

	constant counter_top    : signed(31 downto 0) := to_signed(1 * 2**28, 32); -- 1.0 as Q3.28
	constant one_by_fpwm		: signed(31 downto 0) := to_signed((2**28)/f_pwm, 32); -- Q3.28
	constant scaler_theta   : signed(31 downto 0) := to_signed(1686629713, 32); -- 2*pi = 6.283185307179586476925286766559 as Q3.28

	signal counter          : signed(31 downto 0) := to_signed(0, 32);	-- counter in Q3.28
	signal counter_inc    	: signed(31 downto 0) := to_signed((2**28)*f_ref/f_pwm, 32); -- increment defined by used pwm-clock and desired frequency
begin
	process(clk)
	begin
		if rising_edge(clk) then
			if (sync_in = '1' and state = 0) then
				-- increase counter and wrap around when reaching top
				counter_inc <= resize(shift_right(frequency * one_by_fpwm, 16), counter_inc'length); -- Q15.16	* Q3.28 = Qx.44 -> convert to Q15.28
				
				state <= 1; -- start of state-machine
			
			elsif state = 1 then
				if (counter + counter_inc) > counter_top then -- case for positive increment
					counter <= (counter + counter_inc) - counter_top;
				elsif (counter + counter_inc) < 0 then -- case for negative increment
					counter <= (counter + counter_inc) + counter_top;
				else
					counter <= counter + counter_inc;
				end if;
				
				state <= state + 1;
			
			elsif state = 2 then
				-- scale counter for output of theta
				theta <= resize(shift_right(counter * scaler_theta, 40), 32); -- scale theta to 0 to 2*pi | Q3.28 * Q3.28 = Qx.56 -> convert to Q15.16
				sync_out <= '1';
				
				state <= state + 1;

			elsif state = 3 then
				sync_out <= '0';
				
				state <= 0;
				
			end if;
		end if; -- clk
	end process;
end behaviour;
