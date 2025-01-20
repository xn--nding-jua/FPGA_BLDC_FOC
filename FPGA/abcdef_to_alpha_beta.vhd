-- 6-phase to Alpha-Beta Signal converter
-- 2024 Dr.-Ing. Christian Noeding
-- christian.noeding@uni-kassel.de
-- 09.10.2024
--
-- This file calculates a two-phase Alpha-Beta-Signal out of 6 signals in SRF (Stator Reference Frame)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity abcdef_to_alpha_beta is 
  port( 
    clk       	: in std_logic;
    a			   : in signed(31 downto 0);   --Q15.16
    b			   : in signed(31 downto 0);   --Q15.16
    c			   : in signed(31 downto 0);   --Q15.16
    d			   : in signed(31 downto 0);   --Q15.16
    e			   : in signed(31 downto 0);   --Q15.16
    f			   : in signed(31 downto 0);   --Q15.16
	 sync_in		: in std_logic;
    
    alpha   	: out signed(31 downto 0);   --Q15.16
    beta    	: out signed(31 downto 0);   --Q15.16
	 sync_out 	: out std_logic
  );
end abcdef_to_alpha_beta;

architecture behavioural of abcdef_to_alpha_beta is
	-- internal signals
	signal state		: natural range 0 to 5 := 0;

	signal b_scaled : signed(31 downto 0); -- Q15.16
	signal c_scaled : signed(31 downto 0); -- Q15.16
	signal e_scaled : signed(31 downto 0); -- Q15.16
	signal f_scaled : signed(31 downto 0); -- Q15.16

	signal alpha_int : signed(31 downto 0); -- Q15.16
	
	--signals for multiplier
	signal mult_in_a	:	signed(31 downto 0) := (others=>'0');
	signal mult_in_b	:	signed(31 downto 0) := (others=>'0');
	signal mult_out	:	signed(63 downto 0) := (others=>'0');
begin
	-- multiplier
	process(mult_in_a, mult_in_b)
	begin
		mult_out <= mult_in_a * mult_in_b;
	end process;

	process(clk)
	begin
	if rising_edge(clk) then
			if (sync_in = '1' and state = 0) then
				-- alpha = (1/3) * (a + b/2 + sqrt(3)*c/2 - e/2 + sqrt(3)*f/2)
				-- beta = (1/3) * (sqrt(3)*b/2 + c/2 + d + sqrt(3)*e/2 + f/2)
			
				mult_in_a <= b;
				mult_in_b <= to_signed(56756, 32); -- sqrt(3)/2 as Q15.16
			
				state <= 1; -- start state-machine
			
			elsif (state = 1) then
				b_scaled <= resize(shift_right(mult_out, 16), 32);
				mult_in_a <= c;
							
				state <= state + 1;

			elsif (state = 2) then
				c_scaled <= resize(shift_right(mult_out, 16), 32);
				mult_in_a <= e;
			
				state <= state + 1;
			
			elsif (state = 3) then
				e_scaled <= resize(shift_right(mult_out, 16), 32);
				mult_in_a <= f;
			
				state <= state + 1;

			elsif (state = 4) then
				f_scaled <= resize(shift_right(mult_out, 16), 32);
				
				-- alpha = (1/3) * (a + b/2 + sqrt(3)*c/2 - e/2 + sqrt(3)*f/2)
				mult_in_a <= a + shift_right(b, 1) + c_scaled - shift_right(e, 1) + f_scaled; -- (a + b/2 + sqrt(3)*c/2 - e/2 + sqrt(3)*f/2)
				mult_in_b <= to_signed(21845, 32); -- (1/3)

				state <= state + 1;

			elsif (state = 5) then
				alpha_int <= resize(shift_right(mult_out, 16), 32);
				
				-- beta = (1/3) * (sqrt(3)*b/2 + c/2 + d + sqrt(3)*e/2 + f/2)
				mult_in_a <= b_scaled + shift_right(c, 1) + d + e_scaled + shift_right(f, 1); -- (sqrt(3)*b/2 + c/2 + d + sqrt(3)*e/2 + f/2)
				mult_in_b <= to_signed(21845, 32); -- (1/3)
			
				state <= state + 1;

			elsif (state = 6) then
				alpha <= alpha_int;
				beta <= resize(shift_right(mult_out, 16), 32);
				
				sync_out <= '1';
			
				state <= state + 1;

			elsif (state = 7) then
				sync_out <= '0';
				
				state <= 0;
				
			end if;
		end if;
	end process;
end behavioural;
