----------------------------------------------------------------------------------
-- Original File: https://github.com/YetAnotherElectronicsChannel/FPGA-Class-D-Amplifier/blob/master/PWM_Modulator.vhd
-- Engineer: github.com/YetAnotherElectronicsChannel
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity PWM_Modulator is
	generic(
		bit_width	: natural range 1 to 24 := 5
	);
	port(
		 pwmclk 		: in std_logic;
		 
		 sample_in 	: in signed (bit_width - 1 downto 0);
		 pwm_en		: in std_logic;
		 sync_in 	: in std_logic;
		 
		 pwm_p 		: out std_logic := '0';
		 pwm_n 		: out std_logic := '0'
	);
end PWM_Modulator;  

architecture Behavioral of PWM_Modulator is
	signal timer : unsigned(bit_width - 1 downto 0) := (others=>'0');
	signal dir_counter : std_logic:= '0';
	signal vld_edge_detect : std_logic_vector (1 downto 0) := (others=>'0');
	signal threshold : unsigned(bit_width - 1 downto 0) := (others=>'0');
	signal data_in : unsigned(bit_width - 1 downto 0) := (others=>'0');
	signal pwm : std_logic:= '0';
	signal glitch_filt : std_logic_vector (2 downto 0) := (others=>'0');
begin
	data_in <= unsigned(std_logic_vector(sample_in));
	pwm <= '1' when timer < threshold else '0';

	process(pwmclk)
	begin
		if (rising_edge(pwmclk)) then

			vld_edge_detect <= vld_edge_detect(0) & sync_in;
			glitch_filt <= glitch_filt(1 downto 0) & pwm;
			
			--avoid glitches for 100% und 0% duty-cycle
			if (glitch_filt = "111") then
				pwm_p <= pwm_en;
				pwm_n <= '0';
			elsif (glitch_filt = "000") then
				pwm_p <= '0';
				pwm_n <= pwm_en;
			end if;
			
			--check if valid signal was aplied and start counter by 0 if sample has arrived to get PWM modulator fully in sync with other structure
			if (vld_edge_detect = "10") then            
				dir_counter <= '0';
				
				--invert bit(4) to get from signed value (2s complement) into linear scaled value 0..2^x-1
				threshold <= (NOT data_in(bit_width - 1))&data_in(bit_width - 2 downto 0);
				timer <= to_unsigned(0,bit_width);
				
				
				--do up and down counting from 0 to 2^x-1 and back down to 0
			elsif (timer = to_unsigned((2**bit_width)-1,bit_width) and dir_counter = '0') then
				dir_counter <= '1';
				timer <= to_unsigned((2**bit_width)-1,bit_width);
				
			elsif (timer = to_unsigned(0,bit_width) and dir_counter = '1') then
				dir_counter <= '0';
				timer <= to_unsigned(0,bit_width);  
					 
			elsif (dir_counter = '0') then
				timer <= timer + to_unsigned(1,bit_width);
				
			elsif (dir_counter = '1') then
				timer <= timer - to_unsigned(1,bit_width);
			end if;
		end if;
	end process;
end Behavioral;