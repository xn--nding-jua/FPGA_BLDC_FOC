-- SOGI with third order discrete integrator
-- 2015 Dr.-Ing. Christian Felgemacher
-- 2024 Dr.-Ing. Christian Noeding
-- christian.noeding@uni-kassel.de
-- 09.10.2024
--
-- This file contains a Second Order Generalized Integrator to filter a sine-wave at the input to a disturbance-free output
-- As replacement for the regular integrator it uses a special Third order integrator implementation suggested by Theodorescu et. al.
-- It reduces the ripple on the estimated amplitude and frequency compared to Second order integrator or trapezoidal methods.
-- 
-- Source: Ciobotarum, M.; Theodorescu, R.; Blaabjerg, F.: "A New Single-Phase PLL Structure Based on Second Order Generalized Integrator", 37th IEEE Power Electronics Specialists Conference, PESC '06, 2006, 1-6

-- TODO: this file uses lots of dsp-multiplicators. In future release we can reduce the amount to 1/10 by
-- using a multiplicator-process on top (already prepared).

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SOGI is
	PORT
	(
		clk		: in std_logic;
		v_in		: in signed(31 downto 0);		-- input voltage
		omega		: in signed(31 downto 0);		-- Q15.16
		Ts			: in signed(31 downto 0); 		-- Q0.31
		sync_in	: in std_logic;

		v_out		: out signed(31 downto 0);		-- in phase voltage signal (filtered)
		qv_out	: out signed(31 downto 0);		-- in quadature voltage signal (filtered)
		epsilon	: out signed(31 downto 0);		-- Q15.16
		sync_out	: out std_logic
	);    
end SOGI;

architecture behavioral of SOGI is   
	-- constants
	constant k       				: signed(11 downto 0) := to_signed(205, 12); 	-- Q3.8: k = between 0.5 and 1.0. Theodorescu suggests 0.8
	constant one_by_twelve		: signed(15 downto 0) := to_signed(2731, 16); 	-- Q0.15
	constant c0      				: signed(7 downto 0) := to_signed(23, 8);			-- Q7.0: c0 = 23 (constant for third order integrator)
	constant c1      				: signed(7 downto 0) := to_signed(-16, 8);		-- Q7.0: c1 = -16 (constant for third order integrator)
	constant c2      				: signed(7 downto 0) := to_signed(5, 8);			-- Q7.0: c2 = 5 (constant for third order integrator)

	-- internal signals and constants
	signal state					: natural range 0 to 18 := 0;

	signal v_int					: signed(31 downto 0) := (others => '0'); -- Q15.16
	signal v_o, qv_o       		: signed(31 downto 0) := (others => '0'); -- Q15.16
	signal omega_ts  				: signed(23 downto 0) := (others => '0'); -- Q0.23

	signal MUL1,MUL2,MUL3		: signed(31 downto 0) := (others => '0'); -- Q15.16
	signal SUMa,SUMb       		: signed(31 downto 0) := (others => '0'); -- Q15.16
	signal DLYa0,DLYa1,DLYa2  	: signed(31 downto 0) := (others => '0'); -- Q15.16
	signal DLYb0,DLYb1,DLYb2  	: signed(31 downto 0) := (others => '0'); -- Q15.16

	signal MULa4,MULa5,MULa6 	: signed(31 downto 0) := (others => '0'); -- Q15.16
	signal MULb4,MULb5,MULb6 	: signed(31 downto 0) := (others => '0'); -- Q15.16

	--signals for multiplier
	signal mult_in_a				:	signed(31 downto 0) := (others=>'0');
	signal mult_in_b				:	signed(31 downto 0) := (others=>'0');
	signal mult_out				:	signed(63 downto 0) := (others=>'0');
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
				v_int <= v_in;
				mult_in_a <= omega;
				mult_in_b <= Ts;
				
				state <= 1; -- start of state-machine
			
			elsif (state = 1) then
				omega_ts <= resize(shift_right(mult_out, 24), omega_ts'length); -- Q15.16 * Q0.31 = Qx.47 -> convert to Q0.23
				
				state <= state + 1;
			
			elsif (state = 2) then
				-- divide omega_ts by 12
				mult_in_a <= resize(omega_ts, mult_in_a'length);
				mult_in_b <= resize(one_by_twelve, mult_in_b'length);
				
				state <= state + 1;
				
			elsif (state = 3) then
				omega_ts <= resize(shift_right(mult_out, 15), omega_ts'length); -- Q0.23 * Q0.15 = Q0.38 -> convert to Q0.23
				mult_in_a <= resize(k, mult_in_a'length);
				mult_in_b <= resize(v_int - v_o, mult_in_b'length); -- DIFF1 = v_int - v_o

				epsilon <= v_int - v_o; -- epsilon = DIFF1 = v_int - v_o
			
				state <= state + 1;
				
			elsif (state = 4) then
				MUL1 <= resize(shift_right(mult_out, 8), MUL1'length);
			
				state <= state + 1;

			elsif (state = 5) then
				mult_in_a <= resize(MUL1 - qv_o, mult_in_a'length); -- DIFF2 = MUL1 - qv_o
				mult_in_b <= resize(omega_ts, mult_in_b'length);
			
				state <= state + 1;
				
			elsif (state = 6) then
				MUL2 <= resize(shift_right(mult_out, 23), MUL2'length); -- DIFF2 = Q15.16 | omega = Q0.23 | resulting in Q15.39 -> convert to Q15.16
				mult_in_a <= resize(v_o, mult_in_a'length);
				mult_in_b <= resize(omega_ts, mult_in_b'length);
				
				state <= state + 1;
				
			elsif (state = 7) then
				MUL3 <= resize(shift_right(mult_out, 23), MUL3'length); -- v_o = Q15.16 | omega = Q0.23 | resulting in Q15.39 -> convert to Q15.16
			
				state <= state + 1;
				
			elsif (state = 8) then
				SUMa <= SUMa + MUL2;
				DLYa0 <= SUMa;
				DLYa1 <= DLYa0;
				DLYa2 <= DLYa1;
				SUMb <= SUMb + MUL3;
				DLYb0 <= SUMb;
				DLYb1 <= DLYb0;
				DLYb2 <= DLYb1;
			
				state <= state + 1;
				
			elsif (state = 9) then
				mult_in_a <= resize(DLYa0, mult_in_a'length);
				mult_in_b <= resize(c0, mult_in_b'length);
				
				state <= state + 1;
				
			elsif (state = 10) then
				MULa4 <= resize(mult_out, MULa4'length); -- Q15.16 * Q7.0 = Q23.16 -> just resize to Qx.16
				mult_in_a <= resize(DLYa1, mult_in_a'length);
				mult_in_b <= resize(c1, mult_in_b'length);
				
				state <= state + 1;
				
			elsif (state = 11) then
				MULa5 <= resize(mult_out, MULa5'length); -- Q15.16 * Q7.0 = Q23.16 -> just resize to Qx.16
				mult_in_a <= resize(DLYa2, mult_in_a'length);
				mult_in_b <= resize(c2, mult_in_b'length);
				
				state <= state + 1;
				
			elsif (state = 12) then
				MULa6 <= resize(mult_out, MULa6'length); -- Q15.16 * Q7.0 = Q23.16 -> just resize to Qx.16
				mult_in_a <= resize(DLYb0, mult_in_a'length);
				mult_in_b <= resize(c0, mult_in_b'length);
				
				state <= state + 1;
				
			elsif (state = 13) then
				MULb4 <= resize(mult_out, MULb4'length); -- Q15.16 * Q7.0 = Q23.16 -> just resize to Qx.16
				mult_in_a <= resize(DLYb1, mult_in_a'length);
				mult_in_b <= resize(c1, mult_in_b'length);
				
				state <= state + 1;
				
			elsif (state = 14) then
				MULb5 <= resize(mult_out, MULb5'length); -- Q15.16 * Q7.0 = Q23.16 -> just resize to Qx.16
				mult_in_a <= resize(DLYb2, mult_in_a'length);
				mult_in_b <= resize(c2, mult_in_b'length);
				
				state <= state + 1;
				
			elsif (state = 15) then
				MULb6 <= resize(mult_out, MULb6'length); -- Q15.16 * Q7.0 = Q23.16 -> just resize to Qx.16
				
				state <= state + 1;
				
			elsif (state = 16) then
				v_o <= MULa4 + MULa5 + MULa6;
				qv_o <= MULb4 + MULb5 + MULb6;
			
				state <= state + 1;
				
			elsif (state = 17) then
				v_out <= v_o;
				qv_out <= qv_o;
				sync_out <= '1';
			
				state <= state + 1;
				
			elsif (state = 18) then
				sync_out <= '0';
			
				state <= 0;
			end if;
		end if;
	end process;
end behavioral;
