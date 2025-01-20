-- Input Logic Debouncer
-- v1.0 08.05.2014
-- Christian Felgemacher
-- copied from http://www.deathbylogic.com/2011/03/vhdl-debounce/

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity debounce is
  port (
    CLK 	: in  STD_LOGIC;
    x 	: in  STD_LOGIC;
    DBx 	: out  STD_LOGIC
  );
end debounce;
 
architecture Behavioral of debounce is
  type State_Type is (S0, S1);
  signal State : State_Type := S0;
 
  signal DPB, SPB : STD_LOGIC;
  signal DReg : STD_LOGIC_VECTOR (7 downto 0);
begin
  process (CLK, x)
    variable SDC : integer range 0 to 255;
    constant Delay : integer := 10; --output delay is 8 * Delay = 80 f_clk cycles = 0.8us
  begin
    if rising_edge(CLK) then
      -- Double latch input signal
      DPB <= SPB;
      SPB <= x;
 
      case State is
        when S0 =>
          DReg <= DReg(6 downto 0) & DPB;
 
          SDC := Delay;
 
          State <= S1;
        when S1 =>
          SDC := SDC - 1;
 
          if SDC = 0 then
            State <= S0;
          end if;
        when others =>
          State <= S0;
      end case;
 
      if DReg = X"FF" then
        DBx <= '1';
      elsif DReg = X"00" then
        DBx <= '0';
      end if;
    end if;
  end process;
end Behavioral;
