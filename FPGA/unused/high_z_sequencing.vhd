-- Sequencer for PWM-Off-States for BLDC-Commutation-Blankings
-- 2024 Dr.-Ing. Christian Noeding
-- christian.noeding@uni-kassel.de
-- 15.10.2024
--
-- This file calculates 6 blanking-signals based on theta

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity high_z_sequencing is
  port( 
    clk       		: in std_logic;
	 theta			: in signed(31 downto 0); -- Q15.16
	 sync_in			: in std_logic;
	 
    pwm_en_ch1		: out std_logic;
    pwm_en_ch2		: out std_logic;
    pwm_en_ch3		: out std_logic;
    pwm_en_ch4		: out std_logic;
    pwm_en_ch5		: out std_logic;
    pwm_en_ch6		: out std_logic
  );
end high_z_sequencing;

architecture behavioural of high_z_sequencing is
	constant s0		: signed(31 downto 0) := to_signed(17157, 32); -- 0.5 * (2 * pi)/12
	constant s1		: signed(31 downto 0) := to_signed(51472, 32); -- 1.5 * (2 * pi)/12
	constant s2		: signed(31 downto 0) := to_signed(85786, 32); -- 2.5 * (2 * pi)/12
	constant s3		: signed(31 downto 0) := to_signed(120101, 32); -- 3.5 * (2 * pi)/12
	constant s4		: signed(31 downto 0) := to_signed(154416, 32); -- 4.5 * (2 * pi)/12
	constant s5		: signed(31 downto 0) := to_signed(188730, 32); -- 5.5 * (2 * pi)/12
	constant s6		: signed(31 downto 0) := to_signed(223045, 32); -- 6.5 * (2 * pi)/12
	constant s7		: signed(31 downto 0) := to_signed(257359, 32); -- 7.5 * (2 * pi)/12
	constant s8		: signed(31 downto 0) := to_signed(291674, 32); -- 8.5 * (2 * pi)/12
	constant s9		: signed(31 downto 0) := to_signed(325988, 32); -- 9.5 * (2 * pi)/12
	constant s10	: signed(31 downto 0) := to_signed(360303, 32); -- 10.5 * (2 * pi)/12
	constant s11	: signed(31 downto 0) := to_signed(394618, 32); -- 11.5 * (2 * pi)/12
begin
	process(clk)
	begin
		if rising_edge(clk) then
			if (sync_in = '1') then
				pwm_en_ch1 <= '1';
				pwm_en_ch2 <= '1';
				pwm_en_ch3 <= '1';
				pwm_en_ch4 <= '1';
				pwm_en_ch5 <= '1';
				pwm_en_ch6 <= '1';
			
--				if ((theta >= s11) or (theta < s0) or ((theta >= s5) and (theta < s6))) then
--					pwm_en_ch1 <= '0';
--				else
--					pwm_en_ch1 <= '1';
--				end if;
--			
--				if (((theta >= s0) and (theta < s1)) or ((theta >= s6) and (theta < s7))) then
--					pwm_en_ch2 <= '0';
--				else
--					pwm_en_ch2 <= '1';
--				end if;
--			
--				if (((theta >= s1) and (theta < s2)) or ((theta >= s7) and (theta < s8))) then
--					pwm_en_ch3 <= '0';
--				else
--					pwm_en_ch3 <= '1';
--				end if;
--			
--				if (((theta >= s2) and (theta < s3)) or ((theta >= s8) and (theta < s9))) then
--					pwm_en_ch4 <= '0';
--				else
--					pwm_en_ch4 <= '1';
--				end if;
--			
--				if (((theta >= s3) and (theta < s4)) or ((theta >= s9) and (theta < s10))) then
--					pwm_en_ch5 <= '0';
--				else
--					pwm_en_ch5 <= '1';
--				end if;
--			
--				if (((theta >= s4) and (theta < s5)) or ((theta >= s10) and (theta < s11))) then
--					pwm_en_ch6 <= '0';
--				else
--					pwm_en_ch6 <= '1';
--				end if;
			end if;
		end if;
	end process;
end behavioural;
