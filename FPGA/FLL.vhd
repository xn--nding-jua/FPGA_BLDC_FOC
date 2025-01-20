-- Frequency Locked Loop (FLL) for Dual-SOGI-PLL
-- 2024 Dr.-Ing. Christian Noeding
-- christian.noeding@uni-kassel.de
-- 09.10.2024
--
-- This file contains a Frequency Locked Loop to lock on the current frequency

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity FLL is
   generic (
		f_init			: natural := 50 -- initial frequency in Hertz
	);
	PORT
	(
		clk				: in std_logic;
		alpha				: in signed(31 downto 0);		-- Q15.16
		q_alpha			: in signed(31 downto 0);		-- Q15.16
		epsilon_alpha	: in signed(31 downto 0);		-- Q15.16
		beta				: in signed(31 downto 0);		-- Q15.16
		q_beta			: in signed(31 downto 0);		-- Q15.16
		epsilon_beta	: in signed(31 downto 0);		-- Q15.16
		Ts					: in signed(31 downto 0); 		-- Q0.31
		reset				: in std_logic;
		sync_in			: in std_logic;

		omega				: out signed(31 downto 0);		-- Q15.16
		sync_out			: out std_logic
	);    
end FLL;

architecture behavioral of FLL is
	-- constants
	constant c       				: signed(15 downto 0) := to_signed(1600, 16); 		-- Q7.8: c = gamma = 5/0.8
	constant omega_init			: signed(47 downto 0) := to_signed(105414357 * f_init, 48); 	-- Q23.24 = 2*pi*f_init

	-- internal signals and constants
	signal state					: natural range 0 to 11 := 0;
	signal Ts_int					: signed(31 downto 0); -- Q0.31
	signal omega_int				: signed(47 downto 0); -- Q23.24

	signal v1, v2, v3, v4, v5	: signed(47 downto 0); -- Q23.24
	signal SUM		       		: signed(47 downto 0) := (others => '0'); -- Q23.24
	
	--signals for multiplier
	signal mult_in_a				:	signed(47 downto 0) := (others=>'0');
	signal mult_in_b				:	signed(47 downto 0) := (others=>'0');
	signal mult_out				:	signed(95 downto 0) := (others=>'0');

	-- signals for divider
	signal div_start				:	std_logic;
	signal div_busy				:	std_logic;
	signal div_dividend			:	unsigned(47 downto 0) := (others=>'0'); -- top Q23.24
	signal div_divisor			:	unsigned(47 downto 0) := (others=>'0'); -- bot Q39.8
	signal div_quotient			:	unsigned(47 downto 0) := (others=>'0'); -- result Q31.16

	-- copy inputs/outputs from Divider-entity
	component divider is
		generic (
			bit_width	:	natural range 4 to 48 := 48
		);
		port (
			clk			: in   std_logic;
			start			: in   std_logic;
			dividend		: in   unsigned(47 downto 0); -- top Q23.24
			divisor		: in   unsigned(47 downto 0); -- bot Q39.8
			quotient		: out  unsigned(47 downto 0); -- result Q31.16
			remainder	: out  unsigned(47 downto 0);
			busy			: out  std_logic
		);
	end component;
begin
	-- multiplier
	process(mult_in_a, mult_in_b)
	begin
		mult_out <= mult_in_a * mult_in_b;
	end process;

	-- divider
	div : divider
		port map(
			clk => clk,
			start => div_start,
			dividend => div_dividend,
			divisor => div_divisor,
			quotient => div_quotient,
			remainder => open,
			busy => div_busy
		);

	process(clk)
	begin
		if (rising_edge(clk)) then
			if (sync_in = '1' and state = 0) then
				if (reset = '1') then
					SUM <= to_signed(0, 48);
				end if;

				Ts_int <= Ts;
				
				-- calculate the following equation:
				--    (k * omega * 5/0.8)
				--  ---------------------- * Ts * -1 * (epsilon_alpha * q_alpha) + (epsilon_beta * q_beta)
				--  (alpha^2 + beta^2 + 1)                                     
				-- 
				--          v1
				--     ------------- * Ts * -1 * (v4 + v5)
				--     (v2 + v3 + 1)       
				--
				-- omega is the integration of this equation
				
				-- first calculate four parts of the equation
				-- v1 = c = (k * 5/0.8 * omega)		- values in the range of 0 ... +500
				-- v2 = alpha^2							- values in the range of 0 ... +105000
				-- v3 = beta^2								- values in the range of 0 ... +105000
				-- v4 = (epsilon_alpha * q_alpha)	- values in the range of -3000 ... +3000
				-- v5 = (epsilon_beta * q_beta)		- values in the range of -3000 ... +3000
				
				mult_in_a <= resize(c, mult_in_a'length); -- Q7.8
				mult_in_b <= resize(omega_int, mult_in_b'length); -- Q23.24
				
				state <= 1; -- start state-machine
				
			elsif (state = 1) then
				v1 <= resize(shift_right(mult_out, 8), v1'length); -- Q7.8 * Q23.24 = Qx.32 -> convert to Qx.24
				mult_in_a <= resize(alpha, mult_in_a'length); -- Q15.16
				mult_in_b <= resize(alpha, mult_in_b'length); -- Q15.16
				
				state <= state + 1;
				
			elsif (state = 2) then
				v2 <= resize(shift_right(mult_out, 8), v2'length); -- Q15.16 *  Q15.16 = Qx.32 -> convert to Qx.24
				mult_in_a <= resize(beta, mult_in_a'length); -- Q15.16
				mult_in_b <= resize(beta, mult_in_b'length); -- Q15.16
				
				state <= state + 1;
				
			elsif (state = 3) then
				v3 <= resize(shift_right(mult_out, 8), v3'length); -- Q15.16 *  Q15.16 = Qx.32 -> convert to Qx.24
				mult_in_a <= resize(epsilon_alpha, mult_in_a'length); -- Q15.16
				mult_in_b <= resize(q_alpha, mult_in_b'length); -- Q15.16
				
				state <= state + 1;
				
			elsif (state = 4) then
				v4 <= resize(shift_right(mult_out, 8), v4'length); -- Q15.16 *  Q15.16 = Qx.32 -> convert to Qx.24
				mult_in_a <= resize(epsilon_beta, mult_in_a'length); -- Q15.16
				mult_in_b <= resize(q_beta, mult_in_b'length); -- Q15.16
				
				state <= state + 1;
				
			elsif (state = 5) then
				v5 <= resize(shift_right(mult_out, 8), v5'length); -- Q15.16 *  Q15.16 = Qx.32 -> convert to Qx.24
				
				-- calculate nominator and denominator
				--
				-- dividend = (k * 5/0.8 * omega) * [(epsilon_alpha * q_alpha) + (epsilon_beta * q_beta)]
				-- divisor = alpha^2 + beta^2
				--
				--      v1
				-- ------------- * Ts * -1 * (v4 + v5)
				-- (v2 + v3 + 1)       
				-- 
				div_dividend <= unsigned(v1); -- 23.24 -> keep this size
				div_divisor <= unsigned(resize(shift_right(v2 + v3 + to_signed(1 * 2**24, 48), 16), div_divisor'length)); -- Q23.24 -> convert to Q39.8

				-- start the division and wait until division is ready
				div_start <= '1';

				state <= state + 1;
				
			elsif (state = 6) then
				mult_in_a <= -v4 - v5; -- Q23.24
				mult_in_b <= resize(Ts_int, mult_in_b'length); -- Q0.31
				
				-- set divider-start to 0 for next cycle
				div_start <= '0';
				
				state <= state + 1;
				
			elsif (state = 7 and div_busy = '0') then
				mult_in_a <= signed(div_quotient); -- result of division is Q31.16
				mult_in_b <= resize(shift_right(mult_out, 31), mult_in_b'length); -- Q23.24 * Q0.31 = Qx.55 -> convert to Qx.24
				
				state <= state + 1;
				
			elsif (state = 8) then
				SUM <= SUM + resize(shift_right(mult_out, 16), SUM'length); -- Q31.16 * Qx.24 = Qx.40 -> convert to Qx.24

				state <= state + 1;

			elsif (state = 9) then
				-- omega_int will be stored for next cycle. Dont remove it here
				omega_int <= SUM + omega_init;

				state <= state + 1;

			elsif (state = 10) then
				omega <= resize(shift_right(omega_int, 8), omega'length); -- convert to Q15.16
				sync_out <= '1';
			
				state <= state + 1;
				
			elsif (state = 11) then
				sync_out <= '0';
			
				state <= 0;
				
			end if;
		end if;
	end process;
end behavioral;
