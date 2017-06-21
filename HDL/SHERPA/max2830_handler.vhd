library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity max2830_handler is
	port (
		clock_in : in std_logic;
      reset_in : in std_logic;
		sw_in	 	: in std_logic_vector(7 downto 0);
		din_out  : out std_logic;
		sclk_out : out std_logic;
		cs_out   : out std_logic
	);
end max2830_handler;

architecture Behavioral of max2830_handler is
	type state_type is (idle,fetching,sending,finishing,updating); 
	type spi_type   is (starting, ending); 
	signal state 	  : state_type := fetching; 
	signal spi_state : spi_type   := starting; 
		
	signal max2830_config_addra : std_logic_vector(3 downto 0)  := "0000";
	signal max2830_config_data  : std_logic_vector(17 downto 0);
	
	signal spi_ena	   :	std_logic  :=  '0';
	signal spi_valid  :	std_logic;
	
	signal delay_counter : integer range 0 to 101  := 0;
	
	signal swState_current  : std_logic_vector(7 downto 0) := "00111111";
	signal swState_old  		: std_logic_vector(7 downto 0) := "00111111";
	
	alias clk  : std_logic is clock_in;
	alias rst  : std_logic is reset_in;
	alias din  : std_logic is din_out;
	alias sclk : std_logic is sclk_out;
	alias cs   : std_logic is cs_out;
begin
		
    spi_interface : entity work.spi_master
		generic map ( N => 18 )
		port map (
			 sclk_i    	=>	 clk,    
			 pclk_i    	=>	 clk,    
			 rst_i		=>  rst,
			 spi_ssel_o =>	 cs,
			 spi_sck_o	=>	 sclk,
			 spi_mosi_o	=>	 din,
			 spi_miso_i =>  open,
			 di_req_o 	=>  open,
			 di_i			=>  max2830_config_data,
			 wren_i		=>	 spi_ena,
			 wr_ack_o	=>	 open,
			 do_valid_o =>	 spi_valid,
			 do_o			=>	 open         
		);
		
	state_machine : process(clk, rst, max2830_config_addra)	
		constant delay_threshold 	: integer := 100;
		type max2839_config_data is array (15 downto 0) of std_logic_vector(17 downto 0);
		variable max2839_config : max2839_config_data := 
		  ("010" & "1" & "1101000000" 							& "0000",
			"0" & "1" & "000110011010" 							& "0001",
			"01000000000011" 											& "0010",
			"10011" & "001111010" 								  	& "0011",
			"01100110011001" 										  	& "0100",
			"0000" & "0" & "010" & "0" & "00" & "1" & "00" 	& "0101",
			"0" & "00" & "0000" & "0" & "1000" & "0" & "0" 	& "0110",
			"01" & "000000" & "010" & "010" 						& "0111",
			"1" & "1" & "0" & "0" & "00" & "001000" & "00"  & "1000",
			"000" & "1" & "1110110101" 							& "1001",
			"0111" & "011" & "0100" & "100" 						& "1010",
			"0000000" & "00" & "00000" 							& "1011",
			"00000101" & "000000" 									& "1100",
			"0011" & "1010" & "010010" 							& "1101",
			"000" & "0" & "0" & "10" & "0111011" 				& "1110",
			"00" & "01" & "0101000101" 							& "1111");
	begin
		if (rst = '1') then
			max2830_config_addra <= "0000";
			delay_counter  		<= 0;
			state 					<= fetching;
		elsif (rising_edge(clk)) then
			case state is
				when fetching =>
					delay_counter <= delay_counter + 1; 
					spi_ena <= '0';
				
					if (delay_counter = delay_threshold) then
						max2830_config_data  <= max2839_config(to_integer(15-unsigned(max2830_config_addra)));
					elsif (delay_counter = delay_threshold + 1) then
						delay_counter <= 0;
						state <= sending;	
						spi_state <= starting;						
					end if;		
					
				when sending =>  		
					case spi_state is
						when starting =>
							spi_ena <= '1';
							spi_state <= ending;
						when ending =>
							spi_ena <= '0';	
							if (spi_valid = '1') then							
								if (to_integer(unsigned(max2830_config_addra)) = 15) then
									state <= finishing;
								else
									state <= fetching;
									max2830_config_addra <= std_logic_vector(unsigned(max2830_config_addra) + 1);
								end if;
							end if;				
						when others => null; 
					end case;	
					
				when finishing =>
					delay_counter <= delay_counter + 1; 
					spi_ena <= '0';
				
					if (delay_counter = delay_threshold) then
						delay_counter <= 0;
						state <= idle;	
					end if;
					
				when idle => 
					spi_ena <= '0';	
					swState_current <= sw_in;
					swState_old <= swState_current;
					
					if (swState_current /= swState_old) then
						state <= updating;
						spi_state <= starting;
						
						if (swState_current(7) = '1') then 
							max2830_config_data <= "00000101" & swState_current(5 downto 0) & "1100";
						else
							max2830_config_data <= "0000000"  & swState_current(6 downto 0) & "1011";
						end if;
					end if;
					
				when updating =>					
					case spi_state is
						when starting =>
							spi_ena <= '1';
							spi_state <= ending;
						when ending =>
							spi_ena <= '0';	
							if (spi_valid = '1') then							
								state <= idle;
							end if;				
					end case;					
				when others => null;
			end case;
		end if;
	end process;
end Behavioral;