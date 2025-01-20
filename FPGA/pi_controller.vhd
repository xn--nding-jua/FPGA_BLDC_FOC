-- PI-Controller
-- 2024 Dr.-Ing. Christian Noeding
-- christian.noeding@uni-kassel.de
-- 09.10.2024
--
-- This file contains a standard PI-controller

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pi_controller is
	PORT
	(
		clk			: in std_logic;
		actual		: in signed(31 downto 0); -- Q15.16
		setpoint		: in signed(31 downto 0); -- Q15.16
		kp				: in signed(31 downto 0); -- Q10.21
		ki				: in signed(31 downto 0); -- Q10.21
		Ts				: in signed(31 downto 0); -- Q0.31
		reset			: in std_logic;
		sync_in		: in std_logic;

		output		: out signed(31 downto 0); -- Q15.16
		sync_out		: out std_logic
	);    
end pi_controller;

architecture behavioral of pi_controller is
	signal state			:	natural range 0 to 5 := 0;

	constant omega_init	:	signed(47 downto 0) := to_signed(105414357, 48); -- Q23.24 = 2*pi*1
	
	signal actual_int		: signed(31 downto 0); -- Q15.16
	signal setpoint_int	: signed(31 downto 0); -- Q15.16
	signal kp_int			: signed(31 downto 0); -- Q10.21
	signal ki_int			: signed(31 downto 0); -- Q10.21
	signal Ts_int			: signed(31 downto 0); -- Q0.31
	
	signal error			: signed(23 downto 0); -- Q11.12
	signal i_gain_ts		: signed(31 downto 0); -- Q0.31
	
	signal p_part			: signed(47 downto 0); -- Q23.24
	signal i_inc			: signed(47 downto 0); -- Q23.24
	signal i_part			: signed(47 downto 0); -- Q23.24
begin
	process(clk)
	begin
		if (rising_edge(clk)) then
			if (sync_in = '1' and state = 0) then
				if (reset = '1') then
					i_part <= to_signed(0, 48);
				end if;
				
				actual_int <= actual;
				setpoint_int <= setpoint;
				kp_int <= kp;
				ki_int <= ki;
				Ts_int <= Ts;

				state <= 1; -- start of state-machine
			elsif (state = 1) then
				error <= resize(setpoint_int - actual_int, error'length);
				i_gain_ts <= resize(shift_right(ki_int * Ts_int, 21), 32); -- Q10.21 * Q0.31 = Qx.52 -> convert to Q0.31
				
				state <= state + 1;

			elsif (state = 2) then
				p_part <= resize(shift_right(kp_int * error, 9), p_part'length); -- Q10.21 * Q11.12 = Qx.33 -> convert to Q23.24
				i_inc <= resize(shift_right(i_gain_ts * error, 19), i_inc'length); -- Q0.31 * Q11.12 = Qx.43 -> convert to Q23.24
				
				state <= state + 1;
				
			elsif (state = 3) then
				i_part <= i_part + i_inc;
				
				state <= state + 1;

			elsif (state = 4) then
				output <= resize(shift_right(p_part + i_part + omega_init, 8), output'length); -- convert Q23.24 to Q15.16
				sync_out <= '1';

				state <= state + 1;

			elsif (state = 5) then
				sync_out <= '0';
				
				state <= 0;
				
			end if;
		end if;
	end process;
end behavioral;