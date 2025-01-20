-- dq to Alpha/Beta reference signal
-- 2024 Dr.-Ing. Christian Noeding
-- christian.noeding@uni-kassel.de
-- 08.10.2024
--
-- This file calculates alpha and beta-signal based on the given dq-signal
-- It uses the cordic implementation of Mitu Raj that supports angles between -360° and 360°

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dq_to_alpha_beta is 
	generic (
		Vdc			: natural := 12
	);
	port( 
		clk     		: in std_logic;
		d	    		: in signed(31 downto 0);   -- Q15.16
		q	    		: in signed(31 downto 0);   -- Q15.16
		theta 		: in signed(31 downto 0);   -- Q15.16 | values between 0 and 2*pi
		sync_in		: in std_logic;
	
		alpha 		: out signed(31 downto 0);  -- Q15.16
		beta  		: out signed(31 downto 0);  -- Q15.16
		sync_out 	: out std_logic
	);
end dq_to_alpha_beta;

architecture behavioural of dq_to_alpha_beta is
	signal state					: natural range 0 to 11 := 0;
	signal reset_cordic			: std_logic := '0';
	signal start_cordic			: std_logic := '0';

	signal cordic_mini_done 	: std_logic;
	signal sine, cosine 			: signed(15 downto 0) := (others => '0'); -- type: Q0.15
	signal alpha_int, beta_int : signed(31 downto 0) := (others => '0'); -- type: Q15.16
	signal theta_int				: signed(15 downto 0) := (others => '0'); -- type: Q0.15

	--signals for multiplier
	signal mult_in_a	:	signed(31 downto 0) := (others=>'0');
	signal mult_in_b	:	signed(31 downto 0) := (others=>'0');
	signal mult_out	:	signed(63 downto 0) := (others=>'0');
	
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
		if rising_edge(clk) then
			if (sync_in = '1' and state = 0) then
				-- rescale theta from 0..2*pi to 0...+1 as cordic implementation accepts values between -1 to +1 and interpretes as -360 to +360
				-- convert Q15.16 to Qx.15 and calculate (theta / (2 * pi))
				mult_in_a <= shift_right(theta, 1); -- convert to Qx.15
				mult_in_b <= to_signed(5215, 32); -- 1/(2*pi) as Qx.15
				
				state <= 1; -- start of state-machine
			elsif (state = 1) then
				theta_int <= resize(shift_right(mult_out, 15), 16);
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
				-- alpha = (d * cossin(theta)) - (q * sin(theta))
				-- beta  = (d * sin(theta))    + (q * cossin(theta))
			
				mult_in_a <= d;
				mult_in_b <= shift_left(resize(cosine, 32), 1); -- convert Q0.15 to Q15.16
				
				state <= state + 1;
				
			elsif (state = 5) then
				alpha_int <= resize(shift_right(mult_out, 16), 32); -- Q15.16 * Q15.16 -> Qx.32 -> convert back to Q15.16
				mult_in_a <= d;
				mult_in_b <= shift_left(resize(sine, 32), 1); -- convert Q0.15 to Q15.16
				
				state <= state + 1;
				
			elsif (state = 6) then
				beta_int <= resize(shift_right(mult_out, 16), 32); -- Q15.16 * Q15.16 -> Qx.32 -> convert back to Q15.16
				mult_in_a <= q;
				mult_in_b <= shift_left(resize(sine, 32), 1); -- convert Q0.15 to Q15.16

				state <= state + 1;
				
			elsif (state = 7) then
				alpha_int <= alpha_int - resize(shift_right(mult_out, 16), 32);	-- Q15.16 * Q15.16 -> Qx.32 -> convert back to Q15.16
				mult_in_a <= q;
				mult_in_b <= shift_left(resize(cosine, 32), 1); -- convert Q0.15 to Q15.16
				
				state <= state + 1;
			
			elsif (state = 8) then
				beta_int <= beta_int + resize(shift_right(mult_out, 16), 32);	-- Q15.16 * Q15.16 -> Qx.32 -> convert back to Q15.16

				-- now rescale to PWM-values
				mult_in_a <= alpha_int;
				mult_in_b <= to_signed((2**16)/Vdc, 32); -- divide by Vdc
				
				state <= state + 1;

			elsif (state = 9) then
				alpha_int <= resize(shift_right(mult_out, 16), 32);
				mult_in_a <= beta_int;
				mult_in_b <= to_signed((2**16)/Vdc, 32); -- divide by Vdc
				
				state <= state + 1;
				
			elsif (state = 10) then
				-- set outputs
				alpha <= alpha_int;
				beta <= resize(shift_right(mult_out, 16), 32);

				sync_out <= '1';

				state <= state + 1;
				
			elsif (state = 11) then
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
end behavioural;
