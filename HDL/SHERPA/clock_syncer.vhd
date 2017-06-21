library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

entity clock_syncer is
    Port ( dac_clk_in 	: in  STD_LOGIC;
           adc_clk_in 	: in  STD_LOGIC;
           reset_in		: in  STD_LOGIC;
           sync_out 		: out STD_LOGIC);
end clock_syncer;

architecture Behavioral of clock_syncer is
	signal sync 	: std_logic := '0';
	signal init 	: std_logic := '0';
	signal counter : std_logic_vector(12 downto 0) := (others => '1');
	
	alias rst : std_logic is reset_in;
begin
	sync_out <= sync;
	
	-- This solution is clearly NOT ideal, but it does work.
	syncer : process (rst, dac_clk_in, adc_clk_in)
	begin
		if ( rst = '1' ) then
			sync <= '0';
			init <= '0';
			counter <= (others => '1');
		elsif (rising_edge(adc_clk_in)) then
			if ( dac_clk_in = '1' ) then 
				sync <= '1';
				init <= '1';
				counter <= (others => '0');
			elsif (to_integer(unsigned(counter)) < 8000) then
				sync <= '1';
				if (init = '1') then
					counter <= std_logic_vector(unsigned(counter) + 1);
				end if;
			else
				sync <= '0';
			end if;
		end if;
	end process;
end Behavioral;

