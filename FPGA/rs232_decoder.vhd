-- RS232 command decoder
-- (c) 2023 Dr.-Ing. Christian Noeding
-- christian@noeding-online.de
-- Released under GNU General Public License v3
-- Source: https://www.github.com/xn--nding-jua/Audioplayer
--
-- This file contains a RS232 command-decoder with error-check.
-- It is like a signal demultiplexer, that will convert serial-data to parallel-data

library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;

entity rs232_decoder is 
	port
	(
		clk					: in std_logic;
	
		RX_DataReady		: in std_logic;
		RX_Data				: in std_logic_vector(7 downto 0);

		-- main-values
		amplitude			: out std_logic_vector(31 downto 0) := std_logic_vector(to_signed(0, 32)); -- Q15.16
		frequency			: out std_logic_vector(31 downto 0) := std_logic_vector(to_signed(1 * 2**16, 32)); -- Q15.16
		deadtime				: out std_logic_vector(7 downto 0)  := std_logic_vector(to_unsigned(80, 8)); -- Q8.0
		setpoint_position	: out std_logic_vector(31 downto 0) := std_logic_vector(to_signed(0, 32)); -- Q15.16
		setpoint_speed		: out std_logic_vector(31 downto 0) := std_logic_vector(to_signed(0, 32)); -- Q15.16
		kp_position			: out std_logic_vector(31 downto 0) := std_logic_vector(to_signed(0, 32)); -- Q10.21
		ki_position			: out std_logic_vector(31 downto 0) := std_logic_vector(to_signed(0, 32)); -- Q10.21
		kp_speed				: out std_logic_vector(31 downto 0) := std_logic_vector(to_signed(0, 32)); -- Q10.21
		ki_speed				: out std_logic_vector(31 downto 0) := std_logic_vector(to_signed(0, 32)); -- Q10.21
		kp_current			: out std_logic_vector(31 downto 0) := std_logic_vector(to_signed(0, 32)); -- Q10.21
		ki_current			: out std_logic_vector(31 downto 0) := std_logic_vector(to_signed(0, 32)); -- Q10.21
		openloop				: out std_logic := '1';
		position				: out std_logic := '0';
		reset					: out std_logic := '0'
	);
end entity;

architecture Behavioral of rs232_decoder is
	type t_SM_Decoder is (s_Idle, s_CalcSum, s_Check, s_Read);
	signal s_SM_Decoder 	: t_SM_Decoder := s_Idle;
	
	signal ErrorCheckWord	: unsigned(15 downto 0);
	signal PayloadSum			: unsigned(15 downto 0);
begin
	process (clk)
		variable b1 : std_logic_vector(7 downto 0);	-- "A" = 0x41
		variable b2 : std_logic_vector(7 downto 0);	-- C
		variable b3 : std_logic_vector(7 downto 0);	-- V1 = MSB of payload with signed-bit
		variable b4 : std_logic_vector(7 downto 0);	-- V2
		variable b5 : std_logic_vector(7 downto 0);	-- V3
		variable b6 : std_logic_vector(7 downto 0);	-- V4
		variable b7 : std_logic_vector(7 downto 0);	-- V5
		variable b8 : std_logic_vector(7 downto 0);	-- V6 = LSB of payload
		variable b9 : std_logic_vector(7 downto 0);	-- ErrorCheckWord_MSB
		variable b10 : std_logic_vector(7 downto 0);	-- ErrorCheckWord_LSB
		variable b11 : std_logic_vector(7 downto 0);	-- "E" = 0x45
		
		variable selector: integer range 0 to 255;
	begin
		if (rising_edge(clk)) then
			if (RX_DataReady = '1' and s_SM_Decoder = s_Idle) then
				-- state 0 -> collect data
			
				-- move all bytes forward by one byte and put recent byte at b11
				b1 := b2;
				b2 := b3;
				b3 := b4;
				b4 := b5;
				b5 := b6;
				b6 := b7;
				b7 := b8;
				b8 := b9;
				b9 := b10;
				b10 := b11;
				b11 := RX_Data;

				s_SM_Decoder <= s_CalcSum;
			elsif s_SM_Decoder = s_CalcSum then
				-- build sum of payload and create ErrorCheckWord
				PayloadSum <= unsigned("00000000" & b3) + unsigned("00000000" & b4) + unsigned("00000000" & b5) + unsigned("00000000" & b6) + unsigned("00000000" & b7) + unsigned("00000000" & b8);

				ErrorCheckWord <= unsigned(b9 & b10);

				s_SM_Decoder <= s_Check;
			elsif s_SM_Decoder = s_Check then
				-- check if we have valid payload
				
				if ((unsigned(b1) = 65) and (unsigned(b11) = 69) and (PayloadSum = ErrorCheckWord)) then
					-- we have valid payload-data -> go into next state
					s_SM_Decoder <= s_Read;
				else
					-- unexpected values -> return to idle
					s_SM_Decoder <= s_Idle;
				end if;
			elsif s_SM_Decoder = s_Read then
				-- write data to output

				selector := to_integer(unsigned("0" & b2));
				case selector is
					when 0 =>
						amplitude(31 downto 24) <= b3;
						amplitude(23 downto 16) <= b4;
						amplitude(15 downto 8) <= b5;
						amplitude(7 downto 0) <= b6;

					when 1 =>
						frequency(31 downto 24) <= b3;
						frequency(23 downto 16) <= b4;
						frequency(15 downto 8) <= b5;
						frequency(7 downto 0) <= b6;

					when 2 =>
						--deadtime(31 downto 24) <= b3;
						--deadtime(23 downto 16) <= b4;
						--deadtime(15 downto 8) <= b5;
						deadtime(7 downto 0) <= b6;

					when 3 =>
						setpoint_position(31 downto 24) <= b3;
						setpoint_position(23 downto 16) <= b4;
						setpoint_position(15 downto 8) <= b5;
						setpoint_position(7 downto 0) <= b6;

					when 4 =>
						setpoint_speed(31 downto 24) <= b3;
						setpoint_speed(23 downto 16) <= b4;
						setpoint_speed(15 downto 8) <= b5;
						setpoint_speed(7 downto 0) <= b6;

					when 5 =>
						--kp_position(31 downto 24) <= b3;
						--kp_position(23 downto 16) <= b4;
						kp_position(15 downto 8) <= b5;
						kp_position(7 downto 0) <= b6;

					when 6 =>
						ki_position(31 downto 24) <= b3;
						ki_position(23 downto 16) <= b4;
						ki_position(15 downto 8) <= b5;
						ki_position(7 downto 0) <= b6;

					when 7 =>
						kp_speed(31 downto 24) <= b3;
						kp_speed(23 downto 16) <= b4;
						kp_speed(15 downto 8) <= b5;
						kp_speed(7 downto 0) <= b6;

					when 8 =>
						ki_speed(31 downto 24) <= b3;
						ki_speed(23 downto 16) <= b4;
						ki_speed(15 downto 8) <= b5;
						ki_speed(7 downto 0) <= b6;

					when 9 =>
						kp_current(31 downto 24) <= b3;
						kp_current(23 downto 16) <= b4;
						kp_current(15 downto 8) <= b5;
						kp_current(7 downto 0) <= b6;

					when 10 =>
						ki_current(31 downto 24) <= b3;
						ki_current(23 downto 16) <= b4;
						ki_current(15 downto 8) <= b5;
						ki_current(7 downto 0) <= b6;

					when 11 =>
					   openloop <= b6(0);
					   position <= b6(1);
					   reset <= b6(7);

					when others =>
				end case;

				-- we are done -> return to state 0
				s_SM_Decoder <= s_Idle;
			end if;
		end if;
	end process;
end Behavioral;