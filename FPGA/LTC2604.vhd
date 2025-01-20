-- Parallel-To-Serial SPI-Converter for LTC2604 DAC
-- v1.0 24.07.2009 Hans-Werner M. (Microcontroller-Forum)
-- v2.0 10.04.2013 Christian Nöding (Enhancements for 4-channel output at 16 bit)
-- christian.noeding@uni-kassel.de
--
-- This file calculates 6 signals in SRF (Stator Reference Frame) out of a two-phase Alpha-Beta-Signal

library IEEE;
use ieee.std_logic_1164.ALL;
use IEEE.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity LTC2604 is
    port(
		CLK_IN : in std_logic;
		CH1 : in unsigned(15 downto 0);
		CH2 : in unsigned(15 downto 0);
		CH3 : in unsigned(15 downto 0);
		CH4 : in unsigned(15 downto 0);

		SPI_SCK : out std_logic;
		SPI_MOSI : out std_logic;
		DAC_CLR : out std_logic;
		DAC_CS : out std_logic
    );
end entity LTC2604;

architecture rtl of LTC2604 is

	type dacStateType is (
		idle,
		sendBit,
		clockHigh,
		csHigh
	);
	signal dacState : dacStateType := csHigh;	
	signal dacData : unsigned(23 downto 0);
	signal dacCounter : integer range dacData'range;

	constant counter_value : unsigned(7 downto 0) := "00000010";
	signal counter : unsigned(7 downto 0) := counter_value;
	type states is (change, waitstate, test);
	signal state : states;
	type newstates is (count_up, count_down);
	signal newstate : newstates;
 
begin
 
process(CLK_IN, dacState, CH1, CH2, CH3, CH4, dacData, dacCounter)
	variable counter : integer range 0 to 3;
begin
	if rising_edge(CLK_IN) then		  
		case dacState is
			when idle =>
				DAC_CS <= '0';
				SPI_SCK <= '0';									
				dacCounter <= dacData'high;
				if (counter = 0) then
					dacData(23 downto 16) <= "00110000"; -- Command=0011, Address=0000 = CH1
					dacData(15 downto 0) <= CH1;
					counter:=counter+1;
				elsif (counter = 1) then
					dacData(23 downto 16) <= "00110001"; -- Command=0011, Address=0001 = CH2
					dacData(15 downto 0) <= CH2;
					counter:=counter+1;
				elsif (counter = 2) then
					dacData(23 downto 16) <= "00110010"; -- Command=0011, Address=0010 = CH3
					dacData(15 downto 0) <= CH3;
					counter:=counter+1;
				elsif (counter = 3) then
					dacData(23 downto 16) <= "00110011"; -- Command=0011, Address=0011 = CH4
					dacData(15 downto 0) <= CH4;
					counter:=0;
				end if;
				dacState <= sendBit;
			when sendBit =>
				SPI_SCK <= '0';
				SPI_MOSI <= dacData(dacData'high);
				dacData <= dacData(dacData'high-1 downto dacData'low) & "0";
				dacState <= clockHigh;
			when clockHigh =>
				SPI_SCK <= '1';
				if dacCounter = dacData'low then
					dacState <= csHigh;
				else
					dacCounter <= dacCounter - 1;
					dacState <= sendBit;
				end if;
			when csHigh =>
				SPI_MOSI <= '0';
				SPI_SCK <= '0';
				DAC_CS <= '1';
				dacState <= idle;
		end case;
	end if;
end process;

DAC_CLR <= '1';
end architecture rtl;
