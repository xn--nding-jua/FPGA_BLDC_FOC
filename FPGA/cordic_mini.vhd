-------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------
--- Design         : MINI-CORDIC IP CORE
--- Version        : v.1.0
--- Description    : SINE-COSINE-WAVE GENERATOR 
--                   16-bit core, Computation latency = 3-18 cycles
--                   Angle Input : -360 TO 360 with precision of 0.003 
--                   Output cosine sine result precision : 0.01
--                   All arithmetics are fixed point arithmetic with binary scaling of 2^15; Refer to Doc in my Blog
--                     -- Representing angle values from -360 to 360
--                     -- Representing result values from -1 to +1
--                   Blog Link: https://www.instructables.com/id/Cordic-Algorithm-Using-VHDL/
--  Tested on      : Virtex-4 FPGA, Timing verified for 100 MHz at optimal synthesis
--                   No dedicated FPGA IPs used, Pure RTL code
--- Developers     : Mitu Raj , Roshan Raju
--- Date Modified  : Jan 2023
--- Contact        : iammituraj@gmail.com
--- Copyright      : Open Source Licensed Design
-------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------


---%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- LIBRARIES ------------------------------------------------------------------------------------------------------------
---%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

---%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- ENTITY DEFINITION ----------------------------------------------------------------------------------------------------
---%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
entity cordic_mini is
  generic(
    XY_WIDTH    : integer := 16;	                         -- OUTPUT WIDTH
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
end cordic_mini;

--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- ARCHITECTURE DEFINITION ----------------------------------------------------------------------------------------------
--%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
architecture archi_cordic_mini of cordic_mini is

-------------------------------------------------------------------------------------------------------------------------
--
--                  REGISTER & ARRAY DECLARATIONS
--
-------------------------------------------------------------------------------------------------------------------------
type xyarray is array (natural range <>) of signed (XY_WIDTH-1 downto 0);

type intarray is array (natural range <>) of integer ;

type zarray is array (natural range <>) of signed (ANGLE_WIDTH-1 downto 0);

type atan_lut is array ( natural range <>) of signed (ANGLE_WIDTH-1 downto 0);

    -- TAN INVERSE (ARCTAN) array format 1,16 in DEGREES, CORDIC TABLE
    constant TAN_ARRAY : atan_lut (0 to STAGE-1) := (
                          
                          "0001000000000000",   -- 45
                          "0000100101110010",   -- 26.565
                          "0000010011111101",   -- 14.036
                          "0000001010001000",   -- 7.125
                          "0000000101000101",   -- 3.576
                          "0000000010100010",   -- 1.79
                          "0000000001010001",   -- 0.895
                          "0000000000101000",   -- 0.448
                          "0000000000010100",   -- 0.224
                          "0000000000001010",   -- 0.112
                          "0000000000000101",   -- 0.056
                          "0000000000000010",   -- 0.028
                          "0000000000000001",   -- 0.014                         
                          "0000000000000000" );
    constant J_ARRAY : intarray (0 to STAGE-1) := ( 1,2,4,8,16,32,64,128,256,512,1024,2048,4096,8192);

-------------------------------------------------------------------------------------------------------------------------

-- INTERNAL REGISTERS	        
signal STATE : std_logic_vector(2 downto 0);

begin

process(clock,reset)

 -- VARIABLES DECLARATION   
 variable Xo         : xyarray (0 to STAGE-1);              -- TO PROCESS COSINE ITERATIONS
 variable Yo         : xyarray (0 to STAGE-1);              -- TO PROCESS COSINE ITERATIONS
 variable Xo1        : xyarray (0 to STAGE-1);              -- TO PROCESS SINE ITERATIONS
 variable Yo1        : xyarray (0 to STAGE-1);              -- TO PROCESS SINE ITERATIONS
 variable Xoo        : signed (XY_WIDTH-1 downto 0);        -- FINAL COSINE RESULT
 variable Xo11       : signed (XY_WIDTH-1 downto 0);        -- FINAL SINE RESULT
 variable angle_new  : signed (ANGLE_WIDTH-1 downto 0);     -- TO STORE MODULUS OF INPUT ANGLE
 variable copy       : signed (ANGLE_WIDTH-1 downto 0 );    -- FOR INTERMEDIATE VALUE STORAGE
 variable Zo         : zarray (0 to STAGE-1);               -- TO PROCESS ANGLE ITERATIONS WHILE COSINE COMPUTATION
 variable Zo1        : zarray(0 to STAGE-1);                -- TO PROCESS ANGLE ITERATIONS WHILE SINE COMPUTATION
 variable intr       : zarray (0 to STAGE-1);               -- FOR INTERMEDIATE VALUE STORAGE
 variable j          : integer := 0;                        -- FOR COUNTER - COSINE ITERATIONS
 variable k          : integer := 0;                        -- FOR COUNTER - SINE ITERATIONS
 variable sine_sign  : std_logic := '0';                    -- TO STORE SIGN OF FINAL RESULT OF SINE COMPUTATION
 variable cos_sign   : std_logic  := '0';                   -- TO STORE SIGN OF FINAL RESULT OF COSINE COMPUTATION
 variable msbcheck   : std_logic := '0';                    -- TO STORE THE SIGN OF ANGLE - WHETHER NEGATIVE OR POSITIVE
 variable flag       : std_logic := '0' ;                   -- TO FLAG WHETHER COSINE COMPUTATION IS FINISHED
 variable flag1      : std_logic := '0' ;                   -- TO FLAG WHETHER SINE COMPUTATION IS FINISHED                   
 variable quadrant   : signed (1 downto 0 );                -- TO STORE THE QUADRANT TO WHICH INPUT ANGLE BELONGS
 variable Xo_offset  : signed (XY_WIDTH-1 downto 0);        -- X-OFFSET FOR COSINE ITERATIONS
 variable Yo_offset  : signed (XY_WIDTH-1 downto 0);        -- Y-OFFSET FOR COSINE ITERATIONS
 variable Xo1_offset : signed (XY_WIDTH-1 downto 0);        -- X-OFFSET FOR SINE ITERATIONS
 variable Yo1_offset : signed (XY_WIDTH-1 downto 0);        -- Y-OFFSET FOR SINE ITERATIONS
 variable zero       : unsigned (XY_WIDTH-1 downto 0);      -- TO STORE ZERO VECTOR

begin
-- RESET LOGIC
if(reset ='1') then                     
   j     := 0;
   k     := 0;
   flag  :='0';
   flag1 :='0';
   zero  := "0000000000000000";
   STATE <= "000";
   done  <= '0';
   Xout  <= (OTHERS => '0');
   Yout  <= (OTHERS => '0');
 -- SYNCHRONOUS LOGIC
elsif(rising_edge(clock)) then          
   if(load ='0') then
      j     :=  0;
      k     :=  0;
      flag  := '0';
      flag1 := '0';
      zero  := "0000000000000000";
      STATE <= "000";
      done  <= '0';
   else
      CASE STATE IS
          --------------------------------------------------------------------------------------------------------------
          -- %% INIT STATE %%
          -- TO MANIPULATE INPUT ANGLE
          -- CORRECTION FACTOR IS ALSO CALCULATED IN THIS STATE
          --------------------------------------------------------------------------------------------------------------      
          WHEN "000" =>  
                     -- STORING THE SIGN OF INPUT ANGLE         
                     if(angle(ANGLE_WIDTH-1) = '1') then 
                        msbcheck := '1';
                     else
                        msbcheck := '0';
                     end if;
      
                     copy := angle ;         

                     -- CONVERTING -VE ANGLE FROM TWO'S COMPLIMENT FORM TO ITS POSITIVE MAGNITUDE NOTATION
                     if (angle(ANGLE_WIDTH-1) = '1') then   
                        copy(ANGLE_WIDTH-1) := '0';
                        copy := (copy XOR "0111111111111111") + 1 ;
                     end if ;      

                     copy(ANGLE_WIDTH-1) := '0';
                     angle_new           := copy ;         -- NEW ANGLE INPUT FOR FURTHER STAGES
                     Zo(0)               := angle_new;     -- FOR CORDIC ITERATION LOGIC
                     intr(0)             := angle_new;

                     -- INITIAL VALUES FOR CORDIC ITERATIONS
                     Xo(0) := "0100110110111001";          -- FOR COSINE
                     Yo(0) := "0000000000000000";
                     Xo1(0):= "0100110110111001";          -- FOR SINE
                     Yo1(0):= "0000000000000000";

                     -- LOGIC TO FIND THE QUADRANT OF THE ANGLE
                     quadrant := angle_new (ANGLE_WIDTH-2 downto ANGLE_WIDTH-3);

                     --------------------------------------------------------------------------------------------------
                     --- QUADRANT ANALYSER - LOGIC FOR MAPPING ANGLE TO FIRST QUADRANT
                     ---         
                     --- ___01___|___00___
                     ---    10   |   11
                     --------------------------------------------------------------------------------------------------        
                     case quadrant is   
                        when "00"  =>   
                                   Zo(0)     := angle_new;                           -- INITIAL ANGLE VALUE FOR COSINE ITERATIONS
                                   Zo1(0)    := "0010000000000000" - angle_new ;     -- INITIAL ANGLE VALUE FOR SINE ITERATIONS, SIN(x) = COS(90-x)
                                   sine_sign := '0';                                 -- FINAL COSINE RESULTS' SIGN
                                   cos_sign  := '0';                                 -- FINAL SINE RESULT'S SIGN
                        when "01"  =>    
                                   if(Zo(0) /= "0010000000000000")then               -- IGNORE IF 90
                                      intr(0)   := "0100000000000000" - angle_new ;  
                                      Zo(0)     := intr(0) ;                         -- COS(180-x) = -COS(x)   
                                      Zo1(0)    := "0010000000000000" - intr(0);     -- SIN(x) = COS(90-x)
                                      sine_sign := '0';
                                      cos_sign  := '1';                                   
                                   else                                              -- IF 90
                                      sine_sign := '0';
                                      cos_sign  := '0';
                                   end if ;
                        when "10"  =>   
                                   if(Zo(0) /= "0100000000000000")then                -- IGNORE IF 180
                                      intr(0)   := "0110000000000000" - angle_new ;    
                                      Zo(0)     := "0010000000000000" - intr(0) ;     -- COS(270-x) = -COS(90-x)
                                      Zo1(0)    := intr(0);                           -- COS(270-x) = -SIN(x)
                                      sine_sign := '1';
                                      cos_sign  := '1';
                                   else                                               -- IF 180
                                      sine_sign := '0';
                                      cos_sign  := '1';
                                   end if ;
                        when "11"  => 
                                   if(Zo(0) /= "0111111111111111")then
                                      if(Zo(0) /= "0110000000000000")then                -- IF NOT 270 OR 360
                                         intr(0)   := "0111111111111111" - angle_new ;  
                                         Zo1(0)    := "0010000000000000" - intr(0) ;     -- COS(90-x) = SIN(x)
                                         Zo(0)     := intr(0);                           -- COS(360-x) = COS(x) 
                                         sine_sign := '1';
                                         cos_sign  := '0';
                                      else                                               -- IF 270
                                         sine_sign := '1';
                                         cos_sign  := '0';
                                      end if ;
                                   else                                                  -- IF 360
                                      sine_sign := '0';
                                      cos_sign  := '0';
                                   end if ;
                        when others => flag := '0' ;  
                     end case ;    				 

                     STATE <= "001" ;      

          ------------------------------------------------------------------------------------------------------------
          -- %% QUICK ANALYSER STATE %%
          -- TO CHECK IF INPUT ANGLE IS : 0 OR 45 OR MULTIPLE OF 90
          -- CALCULATE CORRECTION FACTORS, MANIPULATE FLAGS AND SIGNS ACCORDINGLY
          ------------------------------------------------------------------------------------------------------------
          WHEN "001" =>    
                     if(Zo(0) = "0001000000000000") then    --45
                        Xo(0)     := "0101101010000010";
                        Xo1(0)    := "0101101010000010";                        
                        flag      := '1';
                        flag1     := '1';       				      
                     elsif(Zo(0) = "0000000000000000") then -- 0
                        Xo(0)     := "0111111111111111";
                        Xo1(0)    := "0000000000000000";
                        msbcheck  := '0';                        
                        flag      := '1';
                        flag1     := '1';       				    
                     elsif(Zo(0) = "0010000000000000") then --90
                        Xo1(0)    := "0111111111111111";
                        Xo(0)     := "0000000000000000";                        
                        flag      := '1';
                        flag1     := '1';       				    
                     elsif(Zo(0)="0100000000000000") then  --180
                        Xo(0)     := "1000000000000001";   -- -1
                        Xo1(0)    := "0000000000000000";
                        msbcheck  := '0';                        
                        flag      := '1';
                        flag1     := '1';       					
                     elsif(Zo(0)="0110000000000000") then  --270
                        Xo(0)     := "0000000000000000";   -- -1
                        Xo1(0)    := "1000000000000001";                        
                        flag      := '1';
                        flag1     := '1';       					
                     elsif(Zo(0)="0111111111111111") then   --360
                        Xo(0)     := "0111111111111111";
                        Xo1(0)    := "0000000000000000";
                        msbcheck  := '0';                        
                        flag      := '1';
                        flag1     := '1';       					
                     end if ;

                     STATE <= "011" ;

          -------------------------------------------------------------------------------------------------------------
          -- %% CORDIC ITERATOR STATE %%
          -- MAIN STATE WHERE CORDIC ITERATIONS HAPPEN FOR AROUND 14 CYCLES MAXIMUM
          -- END RESULT IS THE MAGNITUDE OF THE RESULT OF THE COSINE AND SINE RESULTS
          -------------------------------------------------------------------------------------------------------------
          WHEN "011" =>    
                     --------------------------------------------------------------------------------------------------
                     -- CORDIC ITERATION BLOCK FOR COSINE COMPUTATION
                     --------------------------------------------------------------------------------------------------  
                     if ( flag /= '1' and j <13) then 

                        -----------------------------------------------------------------------------------------------
                        -- %% LOGIC BLOCK FOR DIVISION OF A SIGNED NUMBER BY 2^N %%
                        -- THE MAGNITUDE/MODULUS OF THE QUOTIENT IS THE OFFSET FOR EVERY CORDIC ITERATION
                        -----------------------------------------------------------------------------------------------
                        Xo_offset := Yo(j) ; 
                        Yo_offset := Xo(j) ;

                        if(Xo_offset >=0) then
                           --zero      := "0000000000000000" + unsigned(Xo_offset(14 downto j)) ; --shift_right(unsigned(Xo_offset),j) **if unsupported in synthesis**
									zero      := shift_right(unsigned(Xo_offset),j);
									
                           Xo_offset := signed(zero) ;
                        else 
                           Xo_offset := (Xo_offset XOR "1111111111111111") + 1;
                           --zero      := "0000000000000000" + unsigned(Xo_offset(14 downto j)) ;
									zero      := shift_right(unsigned(Xo_offset),j);
									
                           Xo_offset := signed(zero) ;
                        end if;	
		  
                        if(Yo_offset >=0) then
                           --zero      := "0000000000000000" + unsigned(Yo_offset(14 downto j)) ;
									zero      := shift_right(unsigned(Yo_offset),j);
									
                           Yo_offset := signed(zero) ;
                        else 
                           Yo_offset := (Yo_offset XOR "1111111111111111" ) + 1;
                           --zero      := "0000000000000000" + unsigned(Yo_offset(14 downto j)) ;
									zero      := shift_right(unsigned(Yo_offset),j);
									
                           Yo_offset := signed(zero);
                        end if;	
                        ----------------------------------------------------------------------------------------------

                        ----------------------------------------------------------------------------------------------
                        -- 	CORDIC ALGORITHM - MAIN ITERATION LOGIC   		        
                        ----------------------------------------------------------------------------------------------
                        if (Zo(j)< 0) then 
                           Xo(j+1) := Xo(j) + Xo_offset ;   --Yo(j)/J_ARRAY(j);--Ysr;
                           Yo(j+1) := Yo(j) - Yo_offset ;   --Xo(j)/J_ARRAY(j);--Xsr;
                           Zo(j+1) := Zo(j) + TAN_ARRAY(j);
                           j       := j + 1 ;
                        elsif (Zo(j) > 0) then
                           Xo(j+1) := Xo(j) - Xo_offset ;   --Yo(j)/J_ARRAY(j);--Ysr;
                           Yo(j+1) := Yo(j) + Yo_offset ;   --Xo(j)/J_ARRAY(j);--Xsr;
                           Zo(j+1) := Zo(j) - TAN_ARRAY(j); 
                           j       := j + 1 ;
                        elsif (Zo(j) = 0 ) then
                           flag    := '1';                  -- COMPUTATION FINISHED, STOP ITERATING
                        end if;
                        ----------------------------------------------------------------------------------------------

                     end if ;

                     -------------------------------------------------------------------------------------------------
                     -- CORDIC ITERATION BLOCK FOR SINE COMPUTATION
                     -------------------------------------------------------------------------------------------------  
                     if ( flag1 /= '1' and k <13) then 

                        ----------------------------------------------------------------------------------------------
                        -- LOGIC BLOCK FOR DIVISION OF A SIGNED NUMBER BY 2^N
                        -- THE MAGNITUDE/MODULUS OF THE QUOTIENT IS THE OFFSET FOR EVERY CORDIC ITERATION
                        ----------------------------------------------------------------------------------------------
                        Xo1_offset := Yo1(k) ;
                        Yo1_offset := Xo1(k) ;
                        		  
                        if(Xo1_offset >=0) then
                           --zero       := "0000000000000000" + unsigned(Xo1_offset(14 downto k)) ;
									zero      := shift_right(unsigned(Xo1_offset),k);
									
                           Xo1_offset := signed(zero) ;
                        else 
                           Xo1_offset := (Xo1_offset XOR "1111111111111111") + 1;
                           --zero       := "0000000000000000" + unsigned(Xo1_offset(14 downto k)) ;
									zero      := shift_right(unsigned(Xo1_offset),k);
									
                           Xo1_offset := signed(zero) ;
                        end if;	
		  
                        if(Yo1_offset >=0) then
                           --zero       := "0000000000000000" + unsigned(Yo1_offset(14 downto k)) ;
									zero      := shift_right(unsigned(Yo1_offset),k);
									
                           Yo1_offset := signed(zero) ;
                        else 
                           Yo1_offset := (Yo1_offset XOR "1111111111111111" ) + 1;
                           --zero       := "0000000000000000" + unsigned(Yo1_offset(14 downto k)) ;
									zero      := shift_right(unsigned(Yo1_offset),k);
									
                           Yo1_offset := signed(zero);
                        end if;
                        ----------------------------------------------------------------------------------------------	

                        ----------------------------------------------------------------------------------------------
                        -- 	CORDIC ALGORITHM - MAIN ITERATION LOGIC   		        
                        ----------------------------------------------------------------------------------------------
                        if (Zo1(k)< 0) then
                           Xo1(k+1) := Xo1(k) + Xo1_offset ;   --Yo1(k)/J_ARRAY(k);--Ysr;
                           Yo1(k+1) := Yo1(k) - Yo1_offset ;   --Xo1(k)/J_ARRAY(k);--Xsr;
                           Zo1(k+1) := Zo1(k) + TAN_ARRAY(k);
                           k:= k+1;
                        elsif (Zo1(k) > 0) then           
                           Xo1(k+1) := Xo1(k) - Xo1_offset ;   --Yo1(k)/J_ARRAY(k);--Ysr;
                           Yo1(k+1) := Yo1(k) + Yo1_offset ;   --Xo1(k)/J_ARRAY(k);--Xsr;
                           Zo1(k+1) := Zo1(k) - TAN_ARRAY(k); 
                           k:= k+1;
                        elsif (Zo1(k) = 0 ) then
                           flag1 := '1';                       -- COMPUTATION FINISHED, STOP ITERATING
                        end if;
                        ---------------------------------------------------------------------------------------------

                     end if ;
                      
                     -- CHECKS WHETHER COSINE AND SINE COMPUTATION IS FINISHED OR NOT
                     if( (flag = '1' and flag1 ='1') or j =13 )then 
                         STATE <= "010" ;                      -- FINISHED, GO TO NEXT STATE
                     else
                         STATE <= "011" ;                      -- NOT FINISHED, STAY IN THE SAME STATE
                     end if;

          -------------------------------------------------------------------------------------------------------------
          -- %% FINAL CORRECTIONS STATE %%
          -- STATE ERROR CORRECTIONS AND COMPENSATIONS ARE DONE
          -- SIGNS OF THE FINAL COSINE AND SINE RESULTS ARE ALSO ASSIGNED HERE
          -------------------------------------------------------------------------------------------------------------
          WHEN "010" =>  

                     Xoo    := Xo(j) ;            -- FINAL COSINE RESULT WITHOUT SIGN
                     Xo11   := Xo1(k) ;           -- FINAL COSINE RESULT WITHOUT SIGN
                     flag   := '0' ;              -- MARKING COSINE COMPUTATION AS COMPLETED
                     flag1  := '0' ;              -- MARKING SINE COMPUTATION AS COMPLETED

                     -- TO LATCH HOLD OUTPUTS IF INPUTS REMAIN SAME; 
                     -- SHOULD BE MADE ZERO BY LOAD PULSE, TO COMPUTE FOR NEXT/DIFFERENT INPUT ANGLE
                     j      := 14 ;               
                     k      := 14 ;   
      				   
                     --------------------------------------------------------------------------------------------------
                     -- %% NEGATIVE VALUE VALUE ERROR COMPENSATION LOGIC %%
                     -- THE FINAL RESULT SHOULD ALWAYS BE POSITIVE, HOWEVER SMALL ROUNDING OFF ERROR CAUSES -VE VALUES
                     -- RESULTS, WHICH HAS TO BE ROUNDED BACK TO POSITIVE MAGNITUDE
                     --------------------------------------------------------------------------------------------------
                     if(Xoo < 0) then
                        Xoo             := (Xoo XOR "0111111111111111" ) + 1 ;
                        Xoo(XY_WIDTH-1) := '0' ;
                     end if ;

                     if(Xo11 <0 ) then
                        Xo11            := (Xo11 XOR "0111111111111111" ) + 1 ;
                        Xoo(XY_WIDTH-1) := '0' ;
                     end if ;
                     --------------------------------------------------------------------------------------------------

                     --------------------------------------------------------------------------------------------------
                     -- SIGNS OF RESULT - ASSIGNMENT LOGIC
                     --------------------------------------------------------------------------------------------------
                     if(cos_sign ='1') then                    
                        Xoo := (Xoo XOR "0111111111111111" ) + 1 ;    -- CONVERTING -VE NUMBER TO ITS 2'S COMPLIMENT
                     end if ;

                     if( (sine_sign XOR msbcheck) = '1') then          -- CONVERTING -VE NUMBER TO ITS 2'S COMPLIMENT
                        Xo11 := (Xo11 XOR "0111111111111111") + 1 ;
                     end if ;
 
                     Xoo(XY_WIDTH-1)  := cos_sign ;                    -- SIGN ASSIGNMENT TO COSINE RESULT
                     Xo11(XY_WIDTH-1) := (sine_sign XOR msbcheck)  ;   -- SIGN ASSIGNMENT TO SINE RESULT
                     Xout             <= Xoo ;                         -- SEND COSINE RESULT TO OUTPUT PORT
                     Yout             <= Xo11 ;                        -- SEND SINE RESULT TO OUTPUT PORT
                     ---------------------------------------------------------------------------------------------------
           
                     STATE <= "110";

          -------------------------------------------------------------------------------------------------------------
          -- %% FINISH STATE %%
          -- WAIT HERE UNTIL A NEW LOAD PULSE OCCURS
          -------------------------------------------------------------------------------------------------------------
          WHEN "110" =>      
                     done <= '1';
       
          WHEN OTHERS =>
                     done <= '0';

      end CASE;
   end if ;       -- LOAD
end if;           -- RISING EDGE

end process ;

end archi_cordic_mini ;
-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------