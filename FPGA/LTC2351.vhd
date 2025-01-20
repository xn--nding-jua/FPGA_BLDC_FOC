-- SPI Interface for LTC2351 6-channel ADC
-- 2014 Dr.-Ing. Christian Felgemacher
-- 2024 Dr.-Ing. Christian Noeding
-- christian.noeding@uni-kassel.de
-- 08.10.2024
--
-- This file reads a connected 6-channel LTC2351 ADC via SPI
-- based on work found on Github: https://github.com/dergraaf/loa/blob/master/fpga/modules/adc_ltc2351/hdl/adc_ltc2351.vhd#L149

LIBRARY IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;

entity LTC2351 is
	PORT(
		CLK_IN        : IN STD_LOGIC;
		CONV_TRIG_IN  : IN STD_LOGIC;
		 
		CH0_DATA      : OUT STD_LOGIC_vector (13 downto 0);
		CH1_DATA      : OUT STD_LOGIC_vector (13 downto 0);
		CH2_DATA      : OUT STD_LOGIC_vector (13 downto 0);
		CH3_DATA      : OUT STD_LOGIC_vector (13 downto 0);
		CH4_DATA      : OUT STD_LOGIC_vector (13 downto 0);
		CH5_DATA      : OUT STD_LOGIC_vector (13 downto 0);
		 
		DATA_RDY      : OUT STD_LOGIC;

		SDO           : IN STD_LOGIC;
		SCLK          : OUT STD_LOGIC;
		CONV          : OUT STD_LOGIC
	);    
end LTC2351;

ARCHITECTURE behavioral of LTC2351 is
  type state_type is (IDLE, SCLK_LOW, SCLK_HIGH);   -- type declaration of state machine

  type ltc2351_state_var_type is record
    state     : state_type;
    sck       : std_logic;
    conv      : std_logic;
    data_rdy  : std_logic;
    
    din       : std_logic_vector(1 to 98);
    count_bit : integer range 1 to 99;
    pre_delay : integer range 0 to 1;
    
    ch0       : std_logic_vector (13 downto 0);
    ch1       : std_logic_vector (13 downto 0);
    ch2       : std_logic_vector (13 downto 0);
    ch3       : std_logic_vector (13 downto 0);
    ch4       : std_logic_vector (13 downto 0);
    ch5       : std_logic_vector (13 downto 0);    
  end record;
    
  signal current_state,next_state: ltc2351_state_var_type := (
		state       => IDLE,      -- current and next state declaration
		sck         => '0',
		conv        => '0',
		data_rdy    => '0',
		din         => (others => '0'),
		count_bit   => 1,
		pre_delay   => 0,
		ch0         => (others => '0'),
		ch1         => (others => '0'),
		ch2         => (others => '0'),
		ch3         => (others => '0'),
		ch4         => (others => '0'),
		ch5         => (others => '0')
	);
begin
	-- connect signals to outputs
	SCLK <= current_state.sck;
	CONV <= current_state.conv;

	DATA_RDY <= current_state.data_rdy;

	CH0_DATA <= current_state.ch0;
	CH1_DATA <= current_state.ch1;
	CH2_DATA <= current_state.ch2;
	CH3_DATA <= current_state.ch3;
	CH4_DATA <= current_state.ch4;
	CH5_DATA <= current_state.ch5;

	-- Sequential processing of FSM (state changes on rising edge of CLK_IN
	seq_proc : process(CLK_IN)
	begin
		if rising_edge(CLK_IN) then
				current_state <= next_state;
		end if;
	end process seq_proc;

	-- State machine process (combinatorial) -> Transitions & Actions of FSM
	comb_proc : process(SDO, CONV_TRIG_IN, current_state)
		variable state_variable : ltc2351_state_var_type;
	begin
		state_variable := current_state;
		
		case current_state.state is
			when IDLE =>            -- Current state is IDLE --> wait for CONV_TRIG_IN
				state_variable.data_rdy := '0';
				if CONV_TRIG_IN = '1' then
					state_variable.state    := SCLK_LOW;
					state_variable.sck      := '0';
					state_variable.conv     := '1';
					state_variable.count_bit:= 1;
					state_variable.pre_delay:= 1;
				else
					state_variable.sck := not current_state.sck;
				end if;
		 
			when SCLK_LOW =>
				state_variable.state      := SCLK_HIGH;
				state_variable.sck        := '1';
			 
			 
			when SCLK_HIGH =>
				state_variable.state      := SCLK_LOW;
				state_variable.sck        := '0';
				state_variable.conv       := '0';
			  
				if current_state.count_bit = 99 then
					-- Last bit received
					state_variable.state    := IDLE;
					state_variable.sck      := '0';
					state_variable.data_rdy := '1';
					state_variable.ch0      := current_state.din(3 to 16);
					state_variable.ch1      := current_state.din(19 to 32);
					state_variable.ch2      := current_state.din(35 to 48);
					state_variable.ch3      := current_state.din(51 to 64);
					state_variable.ch4      := current_state.din(67 to 80);
					state_variable.ch5      := current_state.din(83 to 96);
				else
					state_variable.count_bit := current_state.count_bit + 1;
					-- sample SDO and store in din register on the H->L transition
					state_variable.din(current_state.count_bit) := SDO;
				end if;
		end case;
		  
		next_state <= state_variable;
	end process comb_proc;
end behavioral;
