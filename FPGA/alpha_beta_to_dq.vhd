-- Alpha/Beta to dq Conversion (Park-Transformation)
-- 2024 Dr.-Ing. Christian Noeding
-- christian.noeding@uni-kassel.de
-- 09.10.2024
--
-- This file contains a conversion of Alpha/Beta signals (SRF) into dq-coordinates in rotor-reference-frame (RRF)

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alpha_beta_to_dq is
	PORT
	(
		clk			: in std_logic;
		alpha			: in signed(31 downto 0); -- Q15.16
		beta			: in signed(31 downto 0); -- Q15.16
		theta			: in signed(31 downto 0); -- Q15.16 | values between 0 and 2*pi
		sync_in		: in std_logic;

		d				: out signed(31 downto 0);
		q				: out signed(31 downto 0);
		sync_out		: out std_logic
	);    
end alpha_beta_to_dq;

architecture behavioral of alpha_beta_to_dq is  
	signal state					: natural range 0 to 10 := 0;
	signal reset_cordic			: std_logic := '0';
	signal start_cordic			: std_logic := '0';

	signal cordic_mini_done 	: std_logic;
	signal sine, cosine 			: signed(15 downto 0) := (others => '0'); -- type: Q0.15
	signal sine_int, cosine_int : signed(31 downto 0) := (others => '0'); -- type: Q15.16
	signal theta_int				: signed(15 downto 0) := (others => '0'); -- type: Q0.15

	--signals for multiplier
	signal mult_in_a	:	signed(31 downto 0) := (others=>'0');
	signal mult_in_b	:	signed(31 downto 0) := (others=>'0');
	signal mult_out	:	signed(63 downto 0) := (others=>'0');
	signal mult_out_tmp	:	signed(31 downto 0) := (others=>'0');

	component cordic_mini is
	generic(
		XY_WIDTH    : integer := 16;	                        -- OUTPUT WIDTH
		ANGLE_WIDTH : integer := 16;                          -- ANGLE WIDTH
		STAGE       : integer := 14                           -- NUMBER OF ITERATIONS
	);
	port(
		clock      : in  std_logic;                           -- CLOCK INPUT
		angle      : in  signed (ANGLE_WIDTH-1 downto 0);     -- ANGLE INPUT from -360 to 360
		load       : in  std_logic;                           -- LOAD SIGNAL TO ENABLE THE CORE
		reset      : in  std_logic;                           -- ASYNC ACTIVE-HIGH RESET
		done       : out std_logic;                           -- STATUS SIGNAL TO SHOW WHETHER COMPUTATION IS FINISHED
		Xout       : out signed (XY_WIDTH-1 downto 0);        -- COSINE OUTPUT
		Yout       : out signed (XY_WIDTH-1 downto 0)         -- SINE OUTPUT
	);
	end component;
begin
	-- multiplier
	process(mult_in_a, mult_in_b)
	begin
		mult_out <= mult_in_a * mult_in_b;
	end process;

	process(clk)
	begin
		if (rising_edge(clk)) then
			if (sync_in = '1' and state = 0) then
				-- rescale theta from 0..2*pi to 0...+1 as cordic implementation accepts values between -1 to +1 and interpretes as -360 to +360
				mult_in_a <= shift_right(theta, 1); -- theta/2
				mult_in_b <= to_signed(5215, 32); -- 1/(2*pi) = 0.159149169921875
				
				state <= 1; -- start of state-machine
				
			elsif (state = 1) then
				theta_int <= resize(shift_right(mult_out, 15), 16); -- convert Q15.16 to Qx.15 of calculate (theta / (2 * pi))
				reset_cordic <= '1';
				start_cordic <= '0';
				
				state <= state + 1;
				
			elsif (state = 2) then
				-- stop resetting
				reset_cordic <= '0';
				
				state <= state + 1;

			elsif (state = 3) then
				-- start mini-cordic. As it takes 16 clocks to calculate we have to wait until it is ready
				start_cordic <= '1';
				
				state <= state + 1;

			elsif (state = 4 and cordic_mini_done = '1') then
				sine_int <= shift_left(resize(sine, 32), 1); -- convert Q0.15 into Q15.16
				cosine_int <= shift_left(resize(cosine, 32), 1); -- convert Q0.15 into Q15.16

				state <= state + 1;

			elsif (state = 5) then
				mult_in_a <= alpha;
				mult_in_b <= cosine_int;
				
				state <= state + 1;
				
			elsif (state = 6) then
				mult_out_tmp <= resize(shift_right(mult_out, 16), mult_out_tmp'length);
				mult_in_a <= beta;
				mult_in_b <= sine_int;
				
				state <= state + 1;
				
			elsif (state = 7) then
				d <= resize(mult_out_tmp + shift_right(mult_out, 16), 32);
				mult_in_a <= beta;
				mult_in_b <= cosine_int;
				
				state <= state + 1;
				
			elsif (state = 8) then
				mult_out_tmp <= resize(shift_right(mult_out, 16), mult_out_tmp'length);
				mult_in_a <= alpha;
				mult_in_b <= sine_int;
				
				state <= state + 1;
			
			elsif (state = 9) then
				q <= resize(mult_out_tmp - shift_right(mult_out, 16), 32);
				
				sync_out <= '1';

				state <= state + 1;

			elsif (state = 10) then
				sync_out <= '0';
				
				state <= 0;
			end if;
		end if;
	end process;

	cordic_sine_cos2 : cordic_mini
	port map (
		clock => clk, -- CLOCK INPUT
		angle => theta_int, -- ANGLE INPUT from -360 to 360 as Q0.15
		load  => start_cordic, -- LOAD SIGNAL TO ENABLE THE CORE
		reset => reset_cordic, -- ASYNC ACTIVE-HIGH RESET
		done  => cordic_mini_done, -- STATUS SIGNAL TO SHOW WHETHER COMPUTATION IS FINISHED
		Xout  => cosine, -- COSINE OUTPUT as Q0.15
		Yout  => sine -- SINE OUTPUT as Q0.15
	);
end behavioral;