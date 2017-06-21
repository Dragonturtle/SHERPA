
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all ;

entity signal_corrector is
	generic (
		I_DCOffset			:	integer    := 0;
		Q_DCOffset			:	integer    := 0
	) ;
    Port ( 
				clock_in		: in	std_logic;
				reset_in		: in	std_logic;
				enable_in	: in	std_logic;							--Enable the processing
				I_in  		: in  std_logic_vector(7 downto 0);
				Q_in  		: in  std_logic_vector(7 downto 0);
				I_out 		: out std_logic_vector(8 downto 0);
				Q_out 		: out std_logic_vector(8 downto 0)
			);
end signal_corrector;

architecture Behavioral of signal_corrector is
	signal phase			:	std_logic_vector(8 downto 0) 	:= (others => '0');
	signal I_phase_in		:	std_logic_vector(8 downto 0) 	:= (others => '0');
	signal Q_phase_in		:	std_logic_vector(8 downto 0) 	:= (others => '0');
	signal I_phase_out	:	std_logic_vector(8 downto 0) 	:= (others => '0');
	signal Q_phase_out	:	std_logic_vector(8 downto 0) 	:= (others => '0');
	signal temp				: 	std_logic							:= '0';
	
	alias clk : std_logic is clock_in;
	alias rst : std_logic is reset_in;
	alias ena : std_logic is enable_in;
begin
	
	I_phase_in <= std_logic_vector(to_signed(to_integer(signed(I_in)) - I_DCOffset, 9));
	Q_phase_in <= std_logic_vector(to_signed(to_integer(signed(Q_in)) - Q_DCOffset, 9));
	rotator : entity work.cordic
		port map (
			 clk       	=>	clk,    
			 x_in      	=> I_phase_in,
			 y_in      	=>	Q_phase_in,
			 phase_in  	=>	std_logic_vector(phase),  
			 x_out	  	=>	I_phase_out,
			 y_out      =>	Q_phase_out 		 
		);

	I_out <= I_phase_out;
	Q_out <= Q_phase_out;
	
	phase_correction : process(clk, rst, ena)	
		variable counter : natural range 0 to 1023 := 0;
		variable eval 	  : natural range 0 to 1023 := 0;
	begin
		if (rst = '1') then
			phase 	<= (others => '0');
			temp 		<= '0';
			counter 	:= 0;
		elsif (rising_edge(clk) and ena = '1') then
			temp <= I_phase_out(8) xnor Q_phase_out(8);
			if (counter = 64) then
				counter := 0;
				eval := 0;
			elsif (counter = 62) then
				if (ena = '1') then 
					if (eval > 32) then 
						phase <= std_logic_vector(signed(phase) - 1);
					else 
						phase <= std_logic_vector(signed(phase) + 1);
					end if;
				end if;

				if (phase = 	"011001010" ) then
					phase <= 	"100110111";
				elsif (phase = "100111000" ) then
					phase <= 	"011001001";
				end if;
				
				counter := counter + 1;
			else
				if (temp = '1') then
					eval := eval + 1;
				end if;
				counter := counter + 1;
			end if;
		end if;
	end process;

end Behavioral;

