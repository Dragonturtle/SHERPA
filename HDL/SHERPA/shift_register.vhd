library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity shift_register is
    Port ( I1_in	 		: in  	STD_LOGIC;
			  Q1_in	 		: in  	STD_LOGIC;
			  I2_in	 		: in  	STD_LOGIC;
			  Q2_in	 		: in  	STD_LOGIC;
           clock_in 		: in  	STD_LOGIC;
           reset_in 		: in  	STD_LOGIC;
           valid_out 	: out  	STD_LOGIC;
           data_out 		: out  	std_logic_vector (7 downto 0));
end shift_register;

architecture Behavioral of shift_register is
	signal counter 	: std_logic;
	signal shift_reg 	: std_logic_vector(7 downto 0) := (others => '0');
	
	alias clk 	: std_logic is clock_in;
	alias rst	: std_logic is reset_in;
	alias valid	: std_logic is valid_out;
	alias q 		: std_logic_vector(7 downto 0) is data_out;
begin
	
	shifter : process (clk, rst)
	begin
		if (rst = '1') then
			counter 		<= '0';
			shift_reg 	<= (others => '0');
		elsif (rising_edge(clk)) then
			shift_reg(3 downto 0) <= shift_reg(7 downto 4);
			shift_reg(7) <= Q2_in;
			shift_reg(6) <= Q1_in;
			shift_reg(5) <= I2_in;
			shift_reg(4) <= I1_in;
			
			counter <= not counter;
			if (counter = '0') then
				valid <= '1';
				q <= shift_reg;
			else
				valid <= '0';
			end if;
		end if;		
	end process;
end Behavioral;

