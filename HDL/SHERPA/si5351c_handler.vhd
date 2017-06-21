library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity si5351c_handler is
	port (
		clock_in  : in std_logic;
      reset_in  : in std_logic;
		done_out  : out std_logic;
		sda_inout : inout std_logic;
		scl_inout : inout std_logic
	);
end si5351c_handler;

architecture Behavioral of si5351c_handler is
	type state_type is (idle,fetching,sending); 
	signal state : state_type := sending; 
	
	signal i2c_busy		:	std_logic							:=	'0';
	signal i2c_ena			:	std_logic							:= '0';
	signal i2c_addr		:	std_logic_vector(6 downto 0)	:= "0000000";
	signal i2c_rw			:	std_logic							:= '0';	
	signal i2c_data_wr	:	std_logic_vector(7 downto 0)	:= "00000000";
	signal i2c_data_rd	:	std_logic_vector(7 downto 0)	:= "00000000";
	signal busy_prev 		:	std_logic							:= '0';
	
	signal si5351c_config_addra : std_logic_vector(6 downto 0);
	signal si5351c_config_data  : std_logic_vector(15 downto 0);
	
	signal rst_n	:	std_logic;
	
	alias clk : std_logic is clock_in;
	alias rst : std_logic is reset_in;
	alias sda : std_logic is sda_inout;
	alias scl : std_logic is scl_inout;
begin
	rst_n <= not rst;
	done_out <= '0' when state = idle else '1';
	
	si5351c_config_rom : entity work.si5351c_config_rom
		port map (
			clka 			=> clk,
			addra 		=> si5351c_config_addra,
			douta 		=> si5351c_config_data
		);
		
	i2c_interface : entity work.i2c_master
		port map (
			 clk       =>	clk,    
			 reset_n   =>	rst_n,
			 ena       =>  i2c_ena,
			 addr      =>	i2c_addr,
			 rw        =>	i2c_rw,  
			 data_wr   =>	i2c_data_wr,
			 busy      =>	i2c_busy,   
			 data_rd   =>	i2c_data_rd,	
			 ack_error =>	open,         
			 sda       =>	sda,          
			 scl       =>	scl           
		);
		
	state_machine : process(clk, rst, i2c_busy, si5351c_config_addra)	
		variable busy_counter 		: integer range 0 to 2    := 0;
		variable delay_counter 		: integer range 0 to 1001 := 0;
		constant delay_threshold 	: integer 					  := 1000;
	begin
		if (rst = '1') then
			si5351c_config_addra <= "0000000";
			busy_counter   		:= 0;
			delay_counter  		:= 0;
			state 					<= sending;
		elsif (rising_edge(clk)) then
			case state is
				when fetching =>
					delay_counter := delay_counter + 1; 
				
					if (delay_counter = delay_threshold) then					
						si5351c_config_addra <= std_logic_vector(unsigned(si5351c_config_addra) + 1);
					elsif (delay_counter = delay_threshold + 1) then
						delay_counter := 0;
						state <= sending;							
					end if;			
				when sending =>  
					busy_prev <= i2c_busy;                       						
					if(busy_prev = '0' and i2c_busy = '1') then  						
						busy_counter := busy_counter + 1;                 				
					end if;
					case busy_counter is                             						
						when 0 =>                                  						
						  i2c_ena <= '1';                            					
						  i2c_addr <= "1100000";                    						
						  i2c_rw <= '0';                             					
						  i2c_data_wr <= si5351c_config_data(15 downto 8);          
						when  1 =>                                  						
						  i2c_data_wr <= si5351c_config_data(7 downto 0);           
						when 2 =>                                  						
						  i2c_ena <= '0';                            
						  if(i2c_busy = '0') then                    
							 busy_counter := 0;  
								
							 if (to_integer(unsigned(si5351c_config_addra)) = 69) then
								state <= idle;
							 else
								state <= fetching; 
 							 end if;
						  end if;
						when others => null;
					end case;
				when idle => null;
				when others => null;
			end case;
		end if;
	end process;
end Behavioral;