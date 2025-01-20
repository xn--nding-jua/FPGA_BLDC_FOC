-- Convert Q15.16 signals to 16-bit DAC
-- 2024 Dr.-Ing. Christian Noeding
-- christian.noeding@uni-kassel.de
-- 11.10.2024

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity convert_dac_values is 
	generic(
		ch1_offset		:	natural := 1;
		ch1_max			:  natural := 2;
		ch2_offset		:	natural := 1;
		ch2_max			:  natural := 2;
		ch3_offset		:	natural := 1;
		ch3_max			:  natural := 2;
		ch4_offset		:	natural := 1;
		ch4_max			:  natural := 2
	);
  port(
    clk				: in std_logic;
    q15_16_1_in	: in signed(31 downto 0); -- Q15..16 as value between -1...+1
    q15_16_2_in	: in signed(31 downto 0); -- Q15..16 as value between -1...+1
    q15_16_3_in	: in signed(31 downto 0); -- Q15..16 as value between -1...+1
    q15_16_4_in	: in signed(31 downto 0); -- Q15..16 as value between -1...+1
    
	 dac1_out		: out unsigned(15 downto 0); -- 16 bit unsigned raw signal as value between 0...2^16-1
	 dac2_out		: out unsigned(15 downto 0); -- 16 bit unsigned raw signal as value between 0...2^16-1
	 dac3_out		: out unsigned(15 downto 0); -- 16 bit unsigned raw signal as value between 0...2^16-1
	 dac4_out		: out unsigned(15 downto 0) -- 16 bit unsigned raw signal as value between 0...2^16-1
  );
end convert_dac_values;

architecture behavioural of convert_dac_values is
	-- internal signals
	signal state			: natural range 0 to 4 := 0;

	--signals for multiplier
	signal mult_in_a	:	unsigned(31 downto 0) := (others=>'0');
	signal mult_in_b	:	unsigned(31 downto 0) := (others=>'0');
	signal mult_out	:	unsigned(63 downto 0) := (others=>'0');
begin
	-- multiplier
	process(mult_in_a, mult_in_b)
	begin
		mult_out <= mult_in_a * mult_in_b;
	end process;

	process(clk)
	begin
		if rising_edge(clk) then
			-- scale Q15.16 to 0..12V = 0...65535 (for 12V supply)
			--dac1_out <= resize(unsigned(shift_right(q15_16_1_in, 1) + to_signed(32768, 32)), 16); --resize(unsigned(shift_right(q15_16_1_in, 1) + to_signed(32768, 32)), 16); -- input is Q15.16. (value/2 + 0.5) -> then take first 16 bits
			--dac2_out <= resize(unsigned(shift_right(q15_16_2_in, 1) + to_signed(32768, 32)), 16); --resize(unsigned(shift_right(q15_16_2_in, 1) + to_signed(32768, 32)), 16); -- input is Q15.16. (value/2 + 0.5) -> then take first 16 bits
			--dac3_out <= resize(unsigned(shift_right(q15_16_3_in, 1) + to_signed(32768, 32)), 16); -- input is Q15.16. (value/2 + 0.5) -> then take first 16 bits
			--dac4_out <= resize(unsigned(shift_right(q15_16_4_in, 1) + to_signed(32768, 32)), 16); -- input is Q15.16. (value/2 + 0.5) -> then take first 16 bits
			
			-- scale Q15.16 to 0..5V = 0..27342 (for 5V supply)
			--dac1_out <= resize(shift_right(unsigned(q15_16_1_in + to_signed(65536, 32)), 3), 16); -- first, convert to 0...2 = 0...131072, then scale to 0...16384 by dividing by 8 resulting in outputvoltages between 0V...V
			--dac2_out <= resize(shift_right(unsigned(q15_16_2_in + to_signed(65536, 32)), 3), 16); -- first, convert to 0...2 = 0...131072, then scale to 0...16384 by dividing by 8 resulting in outputvoltages between 0V...V
			--dac3_out <= resize(shift_right(unsigned(q15_16_3_in + to_signed(65536, 32)), 3), 16); -- first, convert to 0...2 = 0...131072, then scale to 0...16384 by dividing by 8 resulting in outputvoltages between 0V...V
			--dac4_out <= resize(shift_right(unsigned(q15_16_4_in + to_signed(65536, 32)), 3), 16); -- first, convert to 0...2 = 0...131072, then scale to 0...16384 by dividing by 8 resulting in outputvoltages between 0V...V
			
			-- scale Q15.16 to 0..5V = 0..27342 (for 5V supply)
			--dac1_out <= resize(shift_right(unsigned(q15_16_1_in + to_signed(ch1_offset * 2**16, 32)) * to_unsigned(27342 / ch1_max, 32), 16), 16); -- first, convert to 0...2 = 0...131072, then scale to 0...27342
			--dac2_out <= resize(shift_right(unsigned(q15_16_2_in + to_signed(ch2_offset * 2**16, 32)) * to_unsigned(27342 / ch2_max, 32), 16), 16); -- first, convert to 0...2 = 0...131072, then scale to 0...27342
			--dac3_out <= resize(shift_right(unsigned(q15_16_3_in + to_signed(ch3_offset * 2**16, 32)) * to_unsigned(27342 / ch3_max, 32), 16), 16); -- input is 0...2*pi = 0...411774, then scale to 0...27342
			--dac4_out <= resize(shift_right(unsigned(q15_16_4_in + to_signed(ch4_offset * 2**16, 32)) * to_unsigned(27342 / ch4_max, 32), 16), 16); -- first, convert to 0...2 = 0...131072, then scale to 0...27342

			if (state = 0) then
				mult_in_a <= unsigned(q15_16_1_in + to_signed(ch1_offset * 2**16, 32));
				mult_in_b <= to_unsigned(27342 / ch1_max, 32);

				state <= 1;
			elsif state = 1 then	
				dac1_out	<= resize(shift_right(mult_out, 16), 16);
				mult_in_a <= unsigned(q15_16_2_in + to_signed(ch2_offset * 2**16, 32));
				mult_in_b <= to_unsigned(27342 / ch2_max, 32);

				state <= state + 1;
			elsif state = 2 then		
				dac2_out	<= resize(shift_right(mult_out, 16), 16);
				mult_in_a <= unsigned(q15_16_3_in + to_signed(ch3_offset * 2**16, 32));
				mult_in_b <= to_unsigned(27342 / ch3_max, 32);

				state <= state + 1;
			elsif state = 3 then		
				dac3_out	<= resize(shift_right(mult_out, 16), 16);
				mult_in_a <= unsigned(q15_16_4_in + to_signed(ch4_offset * 2**16, 32));
				mult_in_b <= to_unsigned(27342 / ch4_max, 32);

				state <= state + 1;
			elsif state = 4 then
				dac4_out	<= resize(shift_right(mult_out, 16), 16);
			
				state <= 0;
			end if;
		end if;
	end process;
end behavioural;
