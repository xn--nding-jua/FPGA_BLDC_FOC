-- Hallsignal-Converter
-- 2024 Dr.-Ing. Christian Noeding
-- christian.noeding@uni-kassel.de
-- 12.10.2024
--
-- This file converts digital hall-signals with a phase-shift of 30 degree
-- into roughly shaped alpha/beta-signals. A subsequent Dual-Sogi filter filters
-- the two signals and restores a phase-corrected alpha/beta signal to calculate
-- the phase-angle theta

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hall_to_alpha_beta is 
	generic (
		alphaBetaShiftLeft	: natural := 12
	);
  port( 
    clk			: in std_logic;
    a				: in std_logic;
    b				: in std_logic;
    c				: in std_logic;
    d				: in std_logic;
    e				: in std_logic;
    f				: in std_logic;
	 sync_in		: in std_logic;
    
	 alpha		: out signed(31 downto 0); -- Q15.16
	 beta			: out signed(31 downto 0); -- Q15.16
	 theta		: out signed(31 downto 0); -- Q15.16
	 sync_out 	: out std_logic
  );
end hall_to_alpha_beta;

architecture behavioural of hall_to_alpha_beta is
	signal hallsignal	: unsigned(5 downto 0);
	signal alpha_int	: signed(31 downto 0); -- Q15.16
	signal beta_int	: signed(31 downto 0); -- Q15.16
	signal theta_int	: signed(31 downto 0); -- Q15.16
	
	signal state		: natural range 0 to 3 := 0;
begin
	process(clk)
--		variable beta_scaled : signed(31 downto 0);
	begin
		if rising_edge(clk) then
			if (sync_in = '1' and state = 0) then
				hallsignal <= unsigned'(f & e & d & c & b & a);

				state <= 1;
			
			elsif (state = 1) then
				-- determine current sector and read alpha/beta from table
				-- Sector	Theta			Alpha				Beta
				-- 0			0				0					-1
				-- 1			0.523598776	0.5				-0.866025404
				-- 2			1.047197551	0.866025404		-0.5
				-- 3			1.570796327	1					0
				-- 4			2.094395102	0.866025404		0.5
				-- 5			2.617993878	0.5				0.866025404
				-- 6			3.141592654	0					1
				-- 7			3.665191429	-0.5				0.866025404 
				-- 8			4.188790205	-0.866025404	0.5
				-- 9			4.71238898	-1					0
				-- 10			5.235987756	-0.866025404	-0.5
				-- 11			5.759586532	-0.5				-0.866025404
				
				case hallsignal is
					when "000001" => -- sector 0
						alpha_int <= to_signed(0, 32);
						beta_int <= to_signed(-65536, 32);
						theta_int <= to_signed(0, 32); 		-- 2*pi * (0/12)
					when "000011" => -- sector 1
						alpha_int <= to_signed(32768, 32);
						beta_int <= to_signed(-56756, 32);
						theta_int <= to_signed(34315, 32); -- 2*pi * (1/12)
					when "000111" => -- sector 2
						alpha_int <= to_signed(56756, 32);
						beta_int <= to_signed(-32768, 32);
						theta_int <= to_signed(68629, 32); -- 2*pi * (2/12)
					when "001111" => -- sector 3
						alpha_int <= to_signed(65536, 32);
						beta_int <= to_signed(0, 32);
						theta_int <= to_signed(102944, 32); -- 2*pi * (3/12)
					when "011111" => -- sector 4
						alpha_int <= to_signed(56756, 32);
						beta_int <= to_signed(32768, 32);
						theta_int <= to_signed(137258, 32); -- 2*pi * (4/12)
					when "111111" => -- sector 5
						alpha_int <= to_signed(32768, 32);
						beta_int <= to_signed(56756, 32);
						theta_int <= to_signed(171573, 32); -- 2*pi * (5/12)
					when "111110" => -- sector 6
						alpha_int <= to_signed(0, 32);
						beta_int <= to_signed(65536, 32);
						theta_int <= to_signed(205887, 32); -- 2*pi * (6/12)
					when "111100" => -- sector 7
						alpha_int <= to_signed(-32768, 32);
						beta_int <= to_signed(56756, 32);
						theta_int <= to_signed(240202, 32); -- 2*pi * (7/12)
					when "111000" => -- sector 8
						alpha_int <= to_signed(-56756, 32);
						beta_int <= to_signed(32768, 32);
						theta_int <= to_signed(274517, 32); -- 2*pi * (8/12)
					when "110000" => -- sector 9
						alpha_int <= to_signed(-65536, 32);
						beta_int <= to_signed(0, 32);
						theta_int <= to_signed(308831, 32); -- 2*pi * (9/12)
					when "100000" => -- sector 10
						alpha_int <= to_signed(-56756, 32);
						beta_int <= to_signed(-32768, 32);
						theta_int <= to_signed(343146, 32); -- 2*pi * (10/12)
					when "000000" => -- sector 11
						alpha_int <= to_signed(-32768, 32);
						beta_int <= to_signed(-56756, 32);
						theta_int <= to_signed(377460, 32); -- 2*pi * (11/12)
					when others =>
						-- unexpected state
						-- keep last values for alpha_int and beta_int
				end case;
				
				state <= 2;
				
			elsif (state = 2) then
				-- shift x bits for better dynamic of PLL
				alpha <= shift_left(alpha_int, alphaBetaShiftLeft);
				beta <= shift_left(beta_int, alphaBetaShiftLeft);
				theta <= theta_int;
			
				sync_out <= '1';
				
				state <= 3;
				
			elsif (state = 3) then
				sync_out <= '0';
				
				state <= 0;
				
			end if;
		end if;
	end process;
end behavioural;
