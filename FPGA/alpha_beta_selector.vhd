-- Control-signal selector
-- 2024 Dr.-Ing. Christian Noeding
-- christian.noeding@uni-kassel.de
-- 14.10.2024

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alpha_beta_selector is 
  port( 
    clk       	: in std_logic;
    a_alpha   	: in signed(31 downto 0);	-- Q15.16
    a_beta    	: in signed(31 downto 0);	-- Q15.16
	 a_theta		: in signed(31 downto 0);	-- Q15.16
	 a_sync_in	: in std_logic;
    b_alpha   	: in signed(31 downto 0);	-- Q15.16
    b_beta    	: in signed(31 downto 0);	-- Q15.16
	 b_theta		: in signed(31 downto 0);	-- Q15.16
	 b_sync_in	: in std_logic;
	 select_a	: in std_logic;
    
    alpha   	: out signed(31 downto 0);	-- Q15.16
    beta    	: out signed(31 downto 0);	-- Q15.16
	 theta		: out signed(31 downto 0);	-- Q15.16
	 sync_out	: out std_logic
  );
end alpha_beta_selector;

architecture behavioural of alpha_beta_selector is
begin
	process(clk)
	begin
		if rising_edge(clk) then
			if (select_a = '1') then
				alpha <= a_alpha;
				beta <= a_beta;
				theta <= a_theta;
				sync_out <= a_sync_in;
			else
				alpha <= b_alpha;
				beta <= b_beta;
				theta <= b_theta;
				sync_out <= b_sync_in;
			end if;
		end if;
	end process;
end behavioural;
