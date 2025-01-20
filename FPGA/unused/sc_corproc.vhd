--
-- sc_corproc.vhd
--
-- Calculates Sine and Cosine values
--
-- uses: p2r_codic.vhd and p2r_cordicpipe.vhd
--
--
--
-- system delay: 21 (data out delay: 20)
--
-- Optimized by Christian Felgemacher and Christian Nöding / University of Kassel / KDEE
 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity sc_corproc is
	port(
		clk	: in std_logic;
		theta : in signed(31 downto 0);  -- type: Q15.16

		sin	: out signed(31 downto 0); -- type: Q15.16
		cos	: out signed(31 downto 0)  -- type: Q15.16
		);
end entity;
 
architecture dataflow of sc_corproc is
	constant PipeLength : natural := 15;
	constant P : signed(15 downto 0) := x"4dba";	-- define aggregate constant
	
	signal theta_int : signed(31 downto 0); -- Q15.16
	
	signal angle_int : signed(15 downto 0);
	signal sin_int : signed(15 downto 0);
	signal cos_int : signed(15 downto 0);
 
	component p2r_cordic is
	generic(
		PIPELINE : integer := 15;
		WIDTH    : integer := 16);
	port(
		clk : in std_logic;
		ena : in std_logic;
 
		Xi : in signed(WIDTH - 1 downto 0);
		Yi : in signed(WIDTH - 1 downto 0) := (others => '0');
		Zi : in signed(WIDTH - 1 downto 0);
 
		Xo : out signed(WIDTH - 1 downto 0);
		Yo : out signed(WIDTH - 1 downto 0)
	);
	end component p2r_cordic;
begin
	process(clk)    
		variable Ain : signed(15 downto 0); -- Q0.16
	begin
		if rising_edge(clk) then
			-- cordic algorithm converges only between -90° ... +90°
			-- we convert the theta from 0 ... 2pi to -0.5 ... 0.5
		
			-- first calc theta_int as value from 0 to 1 as Q15.16
			theta_int <= resize(shift_right(theta * to_signed(10430, 32), 16), 32);  -- convert theta to Q15.16 scale to 0.0 to 1.0 ( * 1/(2*pi) ) | shift to right due to previous multiplication
	 
			-- now calc Ain as value from -0.5 to +0.5
			if theta_int < to_signed(32768, 32) then -- compare to 0.5 * 2^16 = 32768
				-- theta_int is between 0 and 0.5
				Ain := resize(theta_int, 16); -- convert Q15.16 to Q0.16
			else
				-- above 0.5, so subtract by 1
				Ain := resize(theta_int - to_signed(65536, 32), 16); -- subtract by 1 and convert to Q0.16
			end if;

--			-- the following code outputs a sinewave with small errors at the edges...
--			-- Ain is now in range -1 to 1
--			if Ain < to_signed(-16384, 16) then             -- -180 ... -90° --> map to -90° to 0°
--				angle_int <= to_signed(-32768, 32) - Ain;    -- map to -90° to 0°
--				sin <= resize(sin_int, 32);
--				cos <= resize(-cos_int, 32);
--			elsif Ain < to_signed(16384, 32) then           -- -90° to 90° (normal range)
--				angle_int <= Ain;
--				sin <= resize(sin_int, 32);
--				cos <= resize(cos_int, 32);
--			else											            -- 90° to 180°
--				angle_int <= to_signed(32767, 32) - Ain;     -- map to 0° to 90°
--				sin <= resize(sin_int, 32);
--				cos <= resize(-cos_int, 32);
--			end if;

			-- the following code tries to minimize the errors at the edges
			-- Ain is now in range -1 to 1
			if Ain < to_signed(-32585,16) then          			-- <-179° --> exception
				angle_int <= to_signed(-32768, 16) - Ain;  
				sin <= to_signed(0, 32); -- 0.0
				cos <= to_signed(-65536, 32); -- -1.0
			elsif Ain < to_signed(-16566,16) then              -- < range -91° to -179° --> map to -90° to 0°
				angle_int <= to_signed(-32768, 16) - Ain;       -- map to -90° to 0°      
				sin <= resize(sin_int,32);
				cos <= resize(-cos_int,32);
			elsif Ain < to_signed(-16201,16) then              -- -91° to -89° --> exception
				angle_int <= to_signed(-32768, 16) - Ain;
				sin <= to_signed(-65536, 32); -- -1.0
				cos <= to_signed(0, 32); -- 0.0
			elsif Ain < to_signed(-182,16) then                -- -89 to -1 (normal range)
				angle_int <= Ain;
				sin <= resize(sin_int,32);
				cos <= resize(cos_int,32);
			elsif Ain < to_signed(182,16) then                 -- -1° to 1° --> exception
				angle_int <= Ain;
				sin <= to_signed(0,32); -- 0.0
				cos <= to_signed(65536,32); -- 1.0
			elsif Ain < to_signed(16201, 16) then              -- 1° to 89° (normal range)
				angle_int <= Ain;
				sin <= resize(sin_int,32);
				cos <= resize(cos_int,32);
			elsif Ain < to_signed(16566, 16) then              -- 89° to 91° (exception)
				angle_int <= Ain;
				sin <= to_signed(65536,32); -- 1.0
				cos <= to_signed(0,32); -- 0.0
			elsif Ain < to_signed(32585, 16) then              -- 91° to 179°
				angle_int <= to_signed(32767, 16) - Ain;        -- map to 90° to 0°
				sin <= resize(sin_int,32);
				cos <= resize(-cos_int,32);
			else                                               -- 179° to 180° --> exception
				angle_int <= to_signed(32767, 16) - Ain;
				sin <= to_signed(0,32); -- 0.0
				cos <= to_signed(-65536, 32); -- -1.0
			end if;
		end if; --clk
	end process;
  
	u1:	p2r_cordic	
	generic map(
		PIPELINE => PipeLength,
		WIDTH => 16
	)
	port map(
		clk => clk,
		ena => '1',
		Xi => P,
		Zi => angle_int,
		Xo => cos_int,
		Yo => sin_int
	);
end architecture dataflow;
