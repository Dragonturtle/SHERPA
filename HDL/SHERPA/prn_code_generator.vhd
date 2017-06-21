library ieee ;
    use ieee.std_logic_1164.all ;
	 use ieee.numeric_std.all;
	 
entity prn_code_generator is
  generic (
	 idx1			:	natural    := 1;
	 idx2			:	natural    := 5
  ) ;
  port (
	 enable_in  :	in  std_logic ;
	 data_in		:	in  std_logic ;
    clock_in	:  in  std_logic ;
    I_out		:  out std_logic_vector(7 downto 0) ;
	 Q_out		:  out std_logic_vector(7 downto 0) := "00000000"
  ) ;
end entity ;	 

architecture arch of prn_code_generator is 
		alias ena : std_logic is enable_in;
		alias clk : std_logic is clock_in;
begin
	 ----------------------------
	 -- PRN Generation Process --
	 ----------------------------
    prncode : process( clk, ena )	  
		variable G1  	   : bit_vector(14 downto 0) := "111111111111111";
		variable G2  	   : bit_vector(14 downto 0) := "111111111111111";
		variable data_q   : bit := '0';
		variable G1_q 	   : bit := '0';
		variable G2_q 	   : bit := '0';
		variable counter  : natural range 0 to 32767 := 0 ; 
	 begin
        if( ena = '0' ) then
            I_out 	<= "10000000" ; -- 0
				Q_out 	<= "10000000" ; -- 0
            G1  		:= "111111111111111";
            G2  		:= "111111111111111";
				data_q 	:= '0';
				G1_q 		:= '0';
				G2_q 		:= '0';
				counter 	:=  0;
        elsif( rising_edge( clk ) ) then
				-------------------------
				-- PRN Code Generation --
				-------------------------
				data_q := (G1(14) xor G2(idx1) xor G2(idx2) xor to_bit(data_in));
				
				if ( data_q = '1' ) then
					I_out <= "11111111"; --  127
				else
					I_out <= "00000000"; -- -128
				end if;
				
--				G1_q := G1(7) xor G1(4) xor G1(6) xor G1(14);
--				G2_q := G2(1) xor G2(2) xor G2(3) xor G2(5) xor G2(7) xor G2(9) xor G2(10) xor G2(11) xor G2(13) xor G2(14);
				G1_q := G1(7) xor G1(14);
				G2_q := G2(8) xor G2(10) xor G2(11) xor G2(12) xor G2(13) xor G2(14);

				G1(14 downto 1) := G1(13 downto 0);-- sll 1; 
				G2(14 downto 1) := G2(13 downto 0);-- sll 1;
				
				G1(0) := G1_q;
				G2(0) := G2_q;
				
        end if ;
    end process ;
end architecture;