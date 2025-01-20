-- bEMF offset and d-q-current decoupling
-- 2024 Dr.-Ing. Christian Noeding
-- christian.noeding@uni-kassel.de
-- 08.10.2024
--
-- This file calculates decoupled control-voltages for an inverter-stage to control BLDC motor

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dq_decoupling is 
	port( 
		clk     	: in std_logic;
		vd_in   	: in signed(31 downto 0);   -- Q15.16
		vq_in   	: in signed(31 downto 0);   -- Q15.16
		id		 	: in signed(31 downto 0);   -- Q15.16
		iq		 	: in signed(31 downto 0);   -- Q15.16
		omega	 	: in signed(31 downto 0);   -- Q15.16
		Ls		 	: in signed(31 downto 0);   -- Q0.31
		Ke		 	: in signed(31 downto 0);   -- Q15.16
		sync_in	: in std_logic;

		vd_out 	: out signed(31 downto 0);  -- Q15.16
		vq_out 	: out signed(31 downto 0);  -- Q15.16
		sync_out : out std_logic
	);
end dq_decoupling;

architecture behavioural of dq_decoupling is
	signal state		: natural range 0 to 5 := 0;
	signal wLs			: signed(31 downto 0);	-- Q0.31
	signal wKe			: signed(31 downto 0);	-- Q15.16

	--signals for multiplier
	signal mult_in_a	:	signed(31 downto 0) := (others=>'0');
	signal mult_in_b	:	signed(31 downto 0) := (others=>'0');
	signal mult_out	:	signed(63 downto 0) := (others=>'0');
begin
	-- multiplier
	process(mult_in_a, mult_in_b)
	begin
		mult_out <= mult_in_a * mult_in_b;
	end process;

	process(clk)
	begin
		if rising_edge(clk) then
			--wLs <= resize(shift_right(omega * Ls, 16), 32);	-- Q15.16 * Q0.31 = Qx.47 -> convert back to Q0.31
			--wKe <= resize(shift_right(omega * Ke, 16), 32);	-- Q15.16 * Q15.16 = Qx.32 -> convert back to Q15.16
			--vd_out <= vd_in - resize(shift_right(wLs * iq, 31), 32);	-- Q0.31 * Q15.16 = Qx.47 -> convert to Q15.16
			--vq_out <= vq_in + resize(shift_right(wLs * id, 31), 32) + wKe;	-- Q0.31 * Q15.16 = Qx.47 -> convert to Q15.16

			if (sync_in = '1' and state = 0) then
				mult_in_a <= omega;
				mult_in_b <= Ls;
				
				state <= 1; -- start of state-machine
				
			elsif (state = 1) then
				wLs <= resize(shift_right(mult_out, 16), 32);	-- Q15.16 * Q0.31 = Qx.47 -> convert back to Q0.31
				mult_in_a <= omega;
				mult_in_b <= Ke;
				
				state <= state + 1;

			elsif (state = 2) then
				wKe <= resize(shift_right(mult_out, 16), 32);	-- Q15.16 * Q15.16 = Qx.32 -> convert back to Q15.16
				mult_in_a <= wLs;
				mult_in_b <= iq;
				
				state <= state + 1;
			elsif (state = 3) then
				vd_out <= vd_in - resize(shift_right(mult_out, 31), 32);	-- Q0.31 * Q15.16 = Qx.47 -> convert to Q15.16
				mult_in_a <= wLs;
				mult_in_b <= id;

				state <= state + 1;
			elsif (state = 4) then
				vq_out <= vq_in + resize(shift_right(mult_out, 31), 32) + wKe;	-- Q0.31 * Q15.16 = Qx.47 -> convert to Q15.16

				sync_out <= '1';

				state <= state + 1;
			elsif (state = 5) then
				sync_out <= '0';
				
				state <= 0;
			end if;
		end if;
	end process;
end behavioural;
