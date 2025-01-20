-- Convert ADC signals to currents
-- 2024 Dr.-Ing. Christian Noeding
-- christian.noeding@uni-kassel.de
-- 11.10.2024

-- LTC2351 is supplied by 3.3V and uses 14 bit for ADC. FPGA-Board accepts input-voltages between 0...5V.
-- These 0..5V will be scaled to 0...2.5V for the ADC.
-- So 0...2^14-1 = 0..5V 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity convert_adc_current is 
  port( 
    clk			: in std_logic;
    i_ph1_raw	: in unsigned(13 downto 0); -- 14 bit raw signal
    i_ph2_raw	: in unsigned(13 downto 0); -- 14 bit raw signal
    i_ph3_raw	: in unsigned(13 downto 0); -- 14 bit raw signal
    i_ph4_raw	: in unsigned(13 downto 0); -- 14 bit raw signal
    i_ph5_raw	: in unsigned(13 downto 0); -- 14 bit raw signal
    i_ph6_raw	: in unsigned(13 downto 0); -- 14 bit raw signal
	 sync_in		: in std_logic;
    
	 i_ph1		: out signed(31 downto 0); -- Q15..16
	 i_ph2		: out signed(31 downto 0); -- Q15..16
	 i_ph3		: out signed(31 downto 0); -- Q15..16
	 i_ph4		: out signed(31 downto 0); -- Q15..16
	 i_ph5		: out signed(31 downto 0); -- Q15..16
	 i_ph6		: out signed(31 downto 0); -- Q15..16
	 sync_out 	: out std_logic
  );
end convert_adc_current;

architecture behavioural of convert_adc_current is
	-- constants for scaling to voltage
	--constant scaling	: signed(26 downto 0) := to_signed(640, 27);	-- Q5.21: 5V/2^14-1
	--constant offset		: signed(31 downto 0) := to_signed(-163840, 32);	-- Q15.16: -2.5 * 2^16
	
	-- constants for scaling to current
	constant scaling		: signed(26 downto 0) := to_signed(22859, 27);	-- Q5.21: convert 5V to Ampere: (5V/2^14-1) * (1A/0.028V)
	constant offset		: signed(14 downto 0) := to_signed(-8192, 15); -- half of 2^14

	-- internal signals and constants
	signal state			: natural range 0 to 8 := 0;
	signal i_ph1_int,i_ph2_int,i_ph3_int,i_ph4_int,i_ph5_int,i_ph6_int	: signed(14 downto 0);

	--signals for multiplier
	signal mult_in_a	:	signed(14 downto 0) := (others=>'0');
	signal mult_in_b	:	signed(26 downto 0) := (others=>'0');
	signal mult_out	:	signed(41 downto 0) := (others=>'0');
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
				-- scale to voltage
				--v_adc_ch1 <= resize(shift_right(signed(resize(i_ph1_raw, 15)) * scaling, 5), 32) + offset; -- Q14.0 * Q5.21 = Qx.21 -> rescale to Q15.16
				--v_adc_ch2 <= resize(shift_right(signed(resize(i_ph2_raw, 15)) * scaling, 5), 32) + offset; -- Q14.0 * Q5.21 = Qx.21 -> rescale to Q15.16
				--v_adc_ch3 <= resize(shift_right(signed(resize(i_ph3_raw, 15)) * scaling, 5), 32) + offset; -- Q14.0 * Q5.21 = Qx.21 -> rescale to Q15.16
				--v_adc_ch4 <= resize(shift_right(signed(resize(i_ph4_raw, 15)) * scaling, 5), 32) + offset; -- Q14.0 * Q5.21 = Qx.21 -> rescale to Q15.16
				--v_adc_ch5 <= resize(shift_right(signed(resize(i_ph5_raw, 15)) * scaling, 5), 32) + offset; -- Q14.0 * Q5.21 = Qx.21 -> rescale to Q15.16
				--v_adc_ch6 <= resize(shift_right(signed(resize(i_ph6_raw, 15)) * scaling, 5), 32) + offset; -- Q14.0 * Q5.21 = Qx.21 -> rescale to Q15.16

				--i_ph1 <= resize(shift_right((signed(resize(i_ph1_raw, 15)) + offset) * scaling, 5), 32); -- Q14.0 * Q5.21 = Qx.21 -> rescale to Q15.16
				--i_ph2 <= resize(shift_right((signed(resize(i_ph2_raw, 15)) + offset) * scaling, 5), 32); -- Q14.0 * Q5.21 = Qx.21 -> rescale to Q15.16
				--i_ph3 <= resize(shift_right((signed(resize(i_ph3_raw, 15)) + offset) * scaling, 5), 32); -- Q14.0 * Q5.21 = Qx.21 -> rescale to Q15.16
				--i_ph4 <= resize(shift_right((signed(resize(i_ph4_raw, 15)) + offset) * scaling, 5), 32); -- Q14.0 * Q5.21 = Qx.21 -> rescale to Q15.16
				--i_ph5 <= resize(shift_right((signed(resize(i_ph5_raw, 15)) + offset) * scaling, 5), 32); -- Q14.0 * Q5.21 = Qx.21 -> rescale to Q15.16
				--i_ph6 <= resize(shift_right((signed(resize(i_ph6_raw, 15)) + offset) * scaling, 5), 32); -- Q14.0 * Q5.21 = Qx.21 -> rescale to Q15.16

				i_ph1_int <= signed(resize(i_ph1_raw, 15)) + offset;
				i_ph2_int <= signed(resize(i_ph2_raw, 15)) + offset;
				i_ph3_int <= signed(resize(i_ph3_raw, 15)) + offset;
				i_ph4_int <= signed(resize(i_ph4_raw, 15)) + offset;
				i_ph5_int <= signed(resize(i_ph5_raw, 15)) + offset;
				i_ph6_int <= signed(resize(i_ph6_raw, 15)) + offset;
								
				sync_out <= '1';

				state <= 1;
				
			elsif state = 1 then
				mult_in_a <= i_ph1_int;
				mult_in_b <= scaling;
				
				state <= state + 1;
				
			elsif state = 2 then
				i_ph1 <= resize(shift_right(mult_out, 5), 32); -- Q14.0 * Q5.21 = Qx.21 -> rescale to Q15.16
				mult_in_a <= i_ph2_int;
				mult_in_b <= scaling;

				state <= state + 1;
				
			elsif state = 3 then
				i_ph2 <= resize(shift_right(mult_out, 5), 32); -- Q14.0 * Q5.21 = Qx.21 -> rescale to Q15.16
				mult_in_a <= i_ph3_int;
				mult_in_b <= scaling;

				state <= state + 1;
				
			elsif state = 4 then
				i_ph3 <= resize(shift_right(mult_out, 5), 32); -- Q14.0 * Q5.21 = Qx.21 -> rescale to Q15.16
				mult_in_a <= i_ph4_int;
				mult_in_b <= scaling;

				state <= state + 1;
				
			elsif state = 5 then
				i_ph4 <= resize(shift_right(mult_out, 5), 32); -- Q14.0 * Q5.21 = Qx.21 -> rescale to Q15.16
				mult_in_a <= i_ph5_int;
				mult_in_b <= scaling;

				state <= state + 1;
				
			elsif state = 6 then
				i_ph5 <= resize(shift_right(mult_out, 5), 32); -- Q14.0 * Q5.21 = Qx.21 -> rescale to Q15.16
				mult_in_a <= i_ph6_int;
				mult_in_b <= scaling;

				state <= state + 1;
				
			elsif state = 7 then
				i_ph6 <= resize(shift_right(mult_out, 5), 32); -- Q14.0 * Q5.21 = Qx.21 -> rescale to Q15.16

				sync_out <= '1';
				
				state <= state + 1;
				
			elsif state = 8 then
				sync_out <= '0';
			
				state <= 0;
			end if;
		end if;
	end process;
end behavioural;
