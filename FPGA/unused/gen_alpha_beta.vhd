-- Generate Alpha/Beta reference signal
-- 2024 Dr.-Ing. Christian Noeding
-- christian.noeding@uni-kassel.de
-- 08.10.2024
--
-- This file calculates alpha and beta-signal based on the given theta-signal
-- It uses the cordic implementation of Mitu Raj that supports angles between -360° and 360°

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gen_alpha_beta is 
	port( 
		clk     	: in std_logic;
		d	    	: in signed(31 downto 0);   -- Q15.16
		q 	   	: in signed(31 downto 0);   -- Q15.16
		theta 	: in signed(31 downto 0);   -- Q15.16 | values between 0 and 2*pi
		sync_in	: in std_logic;

		alpha 	: out signed(31 downto 0);  -- Q15.16
		beta  	: out signed(31 downto 0);  -- Q15.16
		sync_out : out std_logic
	);
end gen_alpha_beta;

architecture behavioural of gen_alpha_beta is
	signal state					: natural range 0 to 5 := 0;
	signal reset_cordic			: std_logic := '0';
	signal start_cordic			: std_logic := '0';

	signal cordic_mini_done 	: std_logic;
	signal sine, cosine 			: signed(15 downto 0) := (others => '0'); -- type: Q0.15
	signal alpha_int, beta_int : signed(31 downto 0) := (others => '0'); -- type: Q15.16
	signal theta_int				: signed(15 downto 0) := (others => '0'); -- type: Q0.15
	
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
	process(clk)
	begin
		if rising_edge(clk) then
			if (sync_in = '1' and state = 0) then
				-- rescale theta from 0..2*pi to 0...+1 as cordic implementation accepts values between -1 to +1 and interpretes as -360 to +360
				theta_int <= resize(shift_right( shift_right(theta, 1) * to_signed(5215, 32), 15), 16); -- convert Q15.16 to Qx.15 and calculate (theta / (2 * pi))
				reset_cordic <= '1';
				start_cordic <= '0';
				
				state <= 1; -- start of state-machine
				
			elsif (state = 1) then
				-- stop resetting
				reset_cordic <= '0';
				
				state <= state + 1;

			elsif (state = 2) then
				-- start mini-cordic. As it takes 16 clocks to calculate we have to wait until it is ready
				start_cordic <= '1';
				
				state <= state + 1;

			elsif (state = 3 and cordic_mini_done = '1') then
				alpha_int <= shift_left(resize(sine, 32), 1); -- resize to Q15.16 and convert Qx.15 to Qx.16
				beta_int <= shift_left(resize(-cosine, 32), 1); -- resize to Q15.16 and convert Qx.15 to Qx.16

				state <= state + 1;
				
			elsif (state = 4) then
				alpha <= resize(shift_right(alpha_int * ampl, 16), 32);	-- Q15.16 * Q15.16 -> Qx.32 -> convert back to Q15.16
				beta <= resize(shift_right(beta_int * ampl, 16), 32);		-- Q15.16 * Q15.16 -> Qx.32 -> convert back to Q15.16
				
				sync_out <= '1';

				state <= state + 1;
				
			elsif (state = 5) then
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
