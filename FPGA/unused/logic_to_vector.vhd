-- convert digital Hall-Signals to bit-vectors
-- 2024 Dr.-Ing. Christian Noeding
-- christian.noeding@uni-kassel.de
-- 11.10.2024

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity logic_to_vector is 
  port( 
    clk			: in std_logic;
    a_in			: in std_logic;
    b_in			: in std_logic;
    c_in			: in std_logic;
    d_in			: in std_logic;
    e_in			: in std_logic;
    f_in			: in std_logic;
	 sync_in		: in std_logic;
    
	 a_out		: out signed(31 downto 0); -- Q15.16
	 b_out		: out signed(31 downto 0); -- Q15.16
	 c_out		: out signed(31 downto 0); -- Q15.16
	 d_out		: out signed(31 downto 0); -- Q15.16
	 e_out		: out signed(31 downto 0); -- Q15.16
	 f_out		: out signed(31 downto 0); -- Q15.16
	 sync_out 	: out std_logic
  );
end logic_to_vector;

architecture behavioural of logic_to_vector is
begin
	process(clk)
--		variable beta_scaled : signed(31 downto 0);
	begin
		if rising_edge(clk) then
			if (sync_in = '1') then

				if a_in = '1' then
					a_out <= to_signed(120 * 2**16, 32);
				else
					a_out <= to_signed(-120 * 2**16, 32);
				end if;

				if b_in = '1' then
					b_out <= to_signed(120 * 2**16, 32);
				else
					b_out <= to_signed(-120 * 2**16, 32);
				end if;

				if c_in = '1' then
					c_out <= to_signed(120 * 2**16, 32);
				else
					c_out <= to_signed(-120 * 2**16, 32);
				end if;

				if d_in = '1' then
					d_out <= to_signed(120 * 2**16, 32);
				else
					d_out <= to_signed(-120 * 2**16, 32);
				end if;

				if e_in = '1' then
					e_out <= to_signed(120 * 2**16, 32);
				else
					e_out <= to_signed(-120 * 2**16, 32);
				end if;

				if f_in = '1' then
					f_out <= to_signed(120 * 2**16, 32);
				else
					f_out <= to_signed(-120 * 2**16, 32);
				end if;

				sync_out <= '1';
			else
				sync_out <= '0';
			end if;
		end if;
	end process;
end behavioural;
