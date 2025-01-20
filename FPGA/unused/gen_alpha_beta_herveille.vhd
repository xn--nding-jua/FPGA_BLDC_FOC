-- Generate Alpha/Beta reference signal
-- 2024 Dr.-Ing. Christian Noeding
-- christian.noeding@uni-kassel.de
-- 08.10.2024
--
-- This file calculates alpha and beta-signal based on the given theta-signal
-- It uses the cordic-implementation of Richard Herveille, but it has some drawbacks regarding
-- glitches around +90° and -90°.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gen_alpha_beta_herveille is 
	port( 
		clk     	: in std_logic;
		ampl    	: in signed(31 downto 0);   -- Q15.16
		theta 	: in signed(31 downto 0);   -- Q15.16
		sync_in	: in std_logic;

		alpha 	: out signed(31 downto 0);  -- Q15.16
		beta  	: out signed(31 downto 0);  -- Q15.16
		sync_out : out std_logic
	);
end gen_alpha_beta_herveille;

architecture behavioural of gen_alpha_beta_herveille is
	signal cordic_mini_done : std_logic;
	signal sine, cosine : signed(31 downto 0) := (others => '0');  -- type: Q15.16
	signal alpha_int, beta_int : signed(31 downto 0) := (others => '0'); -- type: Q15.16
	
	component sc_corproc is
	port(
		clk	: in std_logic;
		theta : in signed(31 downto 0); -- Q15.16 valid: 0  to 2*pi

		sin	: out signed(31 downto 0);
		cos	: out signed(31 downto 0)
	);
	end component;
begin
	process(clk)
	begin
		if rising_edge(clk) then
			if (sync_in = '1') then
				alpha_int <= sine;
				beta_int <= -cosine;

				alpha <= resize(shift_right(alpha_int * ampl, 16), 32); -- convert to Q15.16
				beta <= resize(shift_right(beta_int * ampl, 16), 32); -- convert to Q15.16
				
				sync_out <= '1';
			else
				sync_out <= '0';
			end if;
		end if;
	end process;

	cordic_sine_cos : sc_corproc
	port map (
		clk => clk,
		theta => theta, -- type: Q15.16
		sin => sine, -- type: Q15.16
		cos => cosine -- type: Q15.16
	 );
end behavioural;
