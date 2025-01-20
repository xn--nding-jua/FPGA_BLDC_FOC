-- SPI Interface for ADS7953 for sampling on channel after the other in manual mode
-- 2014 Dr.-Ing. Christian Felgemacher
-- 2024 Dr.-Ing. Christian Noeding
-- christian.noeding@uni-kassel.de
--
-- This file contains a SPI-interface for the ADS7953 16ch ADC

LIBRARY IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;


entity ADS7953 is
	port 
	(
		clk_in      : in std_logic;                           -- max 40 MHz, as the ADS has to be operated at or below 20MHz SPI sclk!
    
		start_conv  : in std_logic;
    
		miso        : in std_logic;
		sck         : out std_logic := '0';
		mosi        : out std_logic := '0';
		cs          : out std_logic := '1';
		
		ch0_data    : out std_logic_vector(11 downto 0) := (others => '0');
		ch1_data    : out std_logic_vector(11 downto 0) := (others => '0');
		ch2_data    : out std_logic_vector(11 downto 0) := (others => '0');
		ch3_data    : out std_logic_vector(11 downto 0) := (others => '0');
		ch4_data    : out std_logic_vector(11 downto 0) := (others => '0');
		ch5_data    : out std_logic_vector(11 downto 0) := (others => '0');
		ch6_data    : out std_logic_vector(11 downto 0) := (others => '0');
		ch7_data    : out std_logic_vector(11 downto 0) := (others => '0');
		ch8_data    : out std_logic_vector(11 downto 0) := (others => '0');
		ch9_data    : out std_logic_vector(11 downto 0) := (others => '0');
		ch10_data   : out std_logic_vector(11 downto 0) := (others => '0');
		ch11_data   : out std_logic_vector(11 downto 0) := (others => '0');
		ch12_data   : out std_logic_vector(11 downto 0) := (others => '0');
		ch13_data   : out std_logic_vector(11 downto 0) := (others => '0');
		ch14_data   : out std_logic_vector(11 downto 0) := (others => '0');
		ch15_data   : out std_logic_vector(11 downto 0) := (others => '0')
    );
end ADS7953;

architecture bhv of ADS7953 is
	type state_type is (INIT, CONVERT, READY);                                    -- type declaration for FSM
	type data_type  is array(0 to 15) of std_logic_vector(11 downto 0);           -- type declaration for storage of results
	type tx_data_type  is array(0 to 15) of std_logic_vector(15 downto 0);        -- type declaration for storage of MOSI for conversion
	type tx_data_type2 is array(0 to  6) of std_logic_vector(15 downto 0);        -- type declaration for storage of MOSI for init
	
	type state_var_type is record
		state       : state_type;
		sclk        : std_logic;
		mosi        : std_logic;
		cs          : std_logic;
		data        : data_type;
		start       : std_logic;
		input_frame : std_logic_vector(15 downto 0);
		bit_count   : integer range -3 to 15;
		frame_count : integer range -1 to 15;
	end record;

	signal current_state,next_state : state_var_type :=
	(
		state         => INIT,
		sclk          => '1',
		mosi          => '0',
		cs            => '1', -- active low, so start high,
		data          => (others => (others => '0')),
		start         => '1',
		input_frame   => (others => '0'),
		bit_count     => -1,
		frame_count   => -1
	);

begin
	-- connect signals to outputs
	sck   <= current_state.sclk;
	mosi  <= current_state.mosi;
	cs    <= current_state.cs;
	ch0_data   <= current_state.data(0);
	ch1_data   <= current_state.data(1);
	ch2_data   <= current_state.data(2);
	ch3_data   <= current_state.data(3);
	ch4_data   <= current_state.data(4);
	ch5_data   <= current_state.data(5);
	ch6_data   <= current_state.data(6);
	ch7_data   <= current_state.data(7);
	ch8_data   <= current_state.data(8);
	ch9_data   <= current_state.data(9);
	ch10_data  <= current_state.data(10);
	ch11_data  <= current_state.data(11);
	ch12_data  <= current_state.data(12);
	ch13_data  <= current_state.data(13);
	ch14_data  <= current_state.data(14);
	ch15_data  <= current_state.data(15);
    
	-- Sequential processing of FSM (state changes on rising edge of CLK_IN
	seq_proc : process(clk_in)
	begin
		if rising_edge(clk_in) then
			current_state <= next_state;
		end if;
	end process seq_proc;
	 
	-- State machine process (combinatorial) -> Transitions & Actions of FSM
   comb_proc : process(current_state,miso)
      variable state_variable : state_var_type;
      constant convert_tx_data : tx_data_type := 
		(
			"0001000100000000", -- read ch2 next
			"0001000110000000", -- read ch3 next
			"0001001000000000", -- read ch4 next
			"0001001010000000", -- read ch5 next
			"0001001100000000", -- read ch6 next
			"0001001110000000", -- read ch7 next
			"0001010000000000", -- read ch8 next
			"0001010010000000", -- read ch9 next
			"0001010100000000", -- read ch10 next
			"0001010110000000", -- read ch11 next
			"0001011000000000", -- read ch12 next
			"0001011010000000", -- read ch13 next
			"0001011100000000", -- read ch14 next
			"0001011110000000", -- read ch15 next
			"0001000000000000", -- read ch0 next
			"0001000010000000"  -- read ch1 next
		);
		constant init_tx_data : tx_data_type2 :=
		(
			"0100001000000000", -- reset
			"0001100000000000", -- read once  (ch0 next)
			"0001100000000000", -- read again (ch0 next)
			"0001100000000000", -- read again (ch0 next)
			"0001100000000000", -- read again (ch0 next)
			"0001100000000000", -- read again (ch0 next)
			"0001100000000000"  -- read again (ch0 next)
		 );
  
	begin
		state_variable := current_state;
		state_variable.sclk := not current_state.sclk;      -- always toggle SCLK
		state_variable.start := start_conv;                 -- latch for start detection

		case current_state.state is
			when INIT =>    -- Current state is INIT, we will reset & setup the ADC
				-- operations for SCLK = '0'
				
				if current_state.sclk = '0' then
					-- create bit counter and frame counter (once it reaches 6 we move on to READY)
					if current_state.bit_count = -3 then
						if current_state.frame_count = 6 then
							state_variable.state := READY;
						else
							state_variable.frame_count := current_state.frame_count + 1;
							state_variable.bit_count := 15;
							--state_variable.cs := '0';
						end if;              
					else
						state_variable.bit_count := current_state.bit_count - 1;
					end if;
				else
					-- operations for SCLK = '1'
					
					if current_state.bit_count = -1 then
						state_variable.cs := '1';
					end if;
					
					if current_state.bit_count = 15 then
						state_variable.cs := '0';
					end if;
					
					if current_state.bit_count >= 0 then
						state_variable.mosi := init_tx_data(current_state.frame_count)(current_state.bit_count);
					end if;
				end if;
				
			when READY => -- wait for pulse on trig_conv before starting a new conversion run
				if start_conv = '1' and current_state.start = '0' then
					state_variable.state := CONVERT;
					state_variable.sclk := '1';
					state_variable.bit_count := -1;
					state_variable.frame_count := -1;
				end if;
				
			when CONVERT => -- Go Through Channels once until all 16 were read
				-- operations for SCLK = '0'
				if current_state.sclk = '0' then
					-- create bit counter and frame counter (once it reaches 15 we move on to READY)
					if current_state.bit_count = -3 then
						if current_state.frame_count = 15 then
							state_variable.state := READY;
						else
							state_variable.frame_count := current_state.frame_count + 1;
							state_variable.bit_count := 15;
							--state_variable.cs := '0';
							if current_state.frame_count /= -1 then
								state_variable.data(current_state.frame_count) := current_state.input_frame(11 downto 0);
							end if;
						end if;              
					else
						state_variable.bit_count := current_state.bit_count - 1;
					end if;
					
					if current_state.bit_count >= 0 then
						state_variable.input_frame(current_state.bit_count) := miso;
					end if;
					
				else
					-- operations for SCLK = '1'
					if current_state.bit_count = -1 then
						state_variable.cs := '1';
					end if;

					if current_state.bit_count = 15 then
						state_variable.cs := '0';
					end if;

					if current_state.bit_count >= 0 then
						state_variable.mosi := convert_tx_data(current_state.frame_count)(current_state.bit_count);
--                  state_variable.input_frame(current_state.bit_count) := miso;
					end if;
				end if;
		end case;
		
		next_state <= state_variable;
	end process comb_proc;
end bhv;
