-- Positive-(Negative-)Sequence-Calculation-Block for Dual-SOGI
-- 2024 Dr.-Ing. Christian Noeding
-- christian.noeding@uni-kassel.de
-- 09.10.2024
--
-- This file calculates the alpha-beta-signal out of two SOGI-outputs with each v and qv outputs

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SOGI_PNSC is
	PORT
	(
		clk				: in std_logic;
		alpha_v			: in signed(31 downto 0); -- input as Q15.16
		alpha_qv			: in signed(31 downto 0); -- input as Q15.16
		beta_v			: in signed(31 downto 0); -- input as Q15.16
		beta_qv			: in signed(31 downto 0); -- input as Q15.16
		sync_in			: in std_logic;

		alpha				: out signed(31 downto 0); -- output as Q15.16
		beta				: out signed(31 downto 0); -- output as Q15.16
		sync_out			: out std_logic
	);
end SOGI_PNSC;

architecture behavioral of SOGI_PNSC is   
begin
	process(clk)
	begin
		if (rising_edge(clk)) then
			alpha <= shift_right(alpha_v, 1) - shift_right(beta_qv, 1);
			beta <= shift_right(alpha_qv, 1) + shift_right(beta_v, 1);

			sync_out <= sync_in;
		end if;
	end process;
end behavioral;