library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_level is
port(
	-- FX2LP interface ---------------------------------------------------------------------------
	fx2Clk_in      : in    std_logic;                    -- 48MHz clock from FX2LP
	fx2Addr_out    : out   std_logic_vector(1 downto 0); -- select FIFO: "00" for EP2OUT, "10" for EP6IN
	fx2Data_io     : inout std_logic_vector(7 downto 0); -- 8-bit data to/from FX2LP

	-- When EP2OUT selected:
	fx2Read_out    : out   std_logic;                    -- asserted (active-low) when reading from FX2LP
	fx2OE_out      : out   std_logic;                    -- asserted (active-low) to tell FX2LP to drive bus
	fx2GotData_in  : in    std_logic;                    -- asserted (active-high) when FX2LP has data for us

	-- When EP6IN selected:
	fx2Write_out   : out   std_logic;                    -- asserted (active-low) when writing to FX2LP
	fx2GotRoom_in  : in    std_logic;                    -- asserted (active-high) when FX2LP has room for more data from us
	fx2PktEnd_out  : out   std_logic;                    -- asserted (active-low) when a host read needs to be committed early

	-- Onboard peripherals -----------------------------------------------------------------------
	sseg_out       : out   std_logic_vector(7 downto 0); -- seven-segment display cathodes (one for each segment)
	anode_out      : out   std_logic_vector(3 downto 0); -- seven-segment display anodes (one for each digit)
	led_out        : out   std_logic_vector(7 downto 0); -- eight LEDs
	sw_in          : in    std_logic_vector(7 downto 0); -- eight switches
	clk				: in	  std_logic;
	
	-- External peripherals ----------------------------------------------------------------------
	RX_DATA			: in	  std_logic_vector(7 downto 0);
	TX_DATA			: out	  std_logic_vector(7 downto 0);
	
	CLOCK_ADC		: in 		std_logic;
	CLOCK_ADC_OUT	: out		std_logic_vector(2 downto 0);
	
	CLOCK_DAC		: in 		std_logic;
	CLOCK_DAC_OUT	: out		std_logic_vector(2 downto 0);
	
	CONFIG_SDA		: inout	std_logic;
	CONFIG_SCL		: inout	std_logic;
	CONFIG_DIN		: out		std_logic;
	CONFIG_SCLK		: out		std_logic;
	CONFIG_CS		: out		std_logic;
	CONFIG_SHDN		: out		std_logic;
	CONFIG_RXTX		: out		std_logic;
	CONFIG_CW		: out		std_logic
	
);
end entity;

architecture structural of top_level is
	-- Channel read/write interface -----------------------------------------------------------------
	signal fx2Data   : std_logic_vector(7 downto 0);  -- data lines used when the host reads from a channel
	signal fx2Valid  : std_logic;                     -- channel logic can drive this low to say "I don't have data ready for you"
	signal fx2Ready  : std_logic;                     -- '1' means "on the next clock rising edge, put your next byte of data on f2hData"
	-- ----------------------------------------------------------------------------------------------

	-- Needed so that the fx2_interface module can drive both fx2Read_out and fx2OE_out
	signal fx2Read   : std_logic;

	-- Reset signal so host can delay startup
	signal fx2Reset  : std_logic;
	
	alias dac_clk 	: 	std_logic is CLOCK_DAC;
	alias adc_clk 	: 	std_logic is CLOCK_ADC;
	
	signal reset : std_logic := '0';
	
	signal configClock : std_logic := '0';
	signal configDone  : std_logic := '1'; -- Active Low
begin
	CLOCK_ADC_OUT <= CLOCK_ADC & CLOCK_ADC & CLOCK_ADC;
	CLOCK_DAC_OUT <= CLOCK_DAC & CLOCK_DAC & CLOCK_DAC;

	-- CommFPGA module
	fx2Read_out <= fx2Read;
	fx2OE_out <= fx2Read;
	fx2Addr_out(0) <= '0' when fx2Reset = '0'	else 'Z'; -- So fx2Addr_out(1)='0' selects EP2OUT, fx2Addr_out(1)='1' selects EP6IN
	reset <= '0';
	fx2_interface : entity work.fx2_interface
		port map(
			clk_in         => fx2Clk_in,
			reset_in       => '0',
			reset_out      => fx2Reset,
			
			-- FX2LP interface
			fx2FifoSel_out => fx2Addr_out(1),
			fx2Data_io     => fx2Data_io,
			fx2Read_out    => fx2Read,
			fx2GotData_in  => fx2GotData_in,
			fx2Write_out   => fx2Write_out,
			fx2GotRoom_in  => fx2GotRoom_in,
			fx2PktEnd_out  => fx2PktEnd_out,

			-- DVR interface -> Connects to application module
			chanAddr_out   => open,
			h2fData_out    => open,
			h2fValid_out   => open,
			h2fReady_in    => '0',
			f2hData_in     => fx2Data,
			f2hValid_in    => fx2Valid,
			f2hReady_out   => fx2Ready
		);

	-- Transceiver link module
	sherpa_rxtx : entity work.sherpa_rxtx
		port map(
			adc_clk_in 	 => adc_clk,
			dac_clk_in 	 => dac_clk,
			usb_clk_in   => fx2Clk_in,
			reset_in     => '0',
			
			-- DVR interface -> Connects to fx2_interface module
			data_out  => fx2Data,
			valid_out => fx2Valid,
			ready_in  => fx2Ready,
			
			-- External interface
			sseg_out     => sseg_out,
			anode_out    => anode_out,
			led_out      => led_out,
			sw_in			 => sw_in,
			
			RX_in		 	 => RX_DATA,
			TX_out	 	 => TX_DATA,
			dacCW_out	 => CONFIG_CW,
			RXTX_out	 	 => CONFIG_RXTX,
			
			sync_clk_out => open --CLOCK_DAC_OUT1 --CLOCK_SYNC
		);
		
	clock_divider : process (clk)	begin
			if (rising_edge(clk)) then
				configClock <= not configClock;
			end if;
		end process;

	-- Initialize the SI5351C Clock Generator Chip
	si5351c_handler : entity work.si5351c_handler
		port map (
			clock_in 	=> configClock,
			reset_in 	=> '0',
			done_out		=> configDone,
			sda_inout 	=> CONFIG_SDA,
			scl_inout	=> CONFIG_SCL
		);
	
	-- Initialize the MAX2830 analog front end
	max2830_handler : entity work.max2830_handler
		port map (
			clock_in => configClock,
			reset_in => configDone,
			din_out	=>	CONFIG_DIN,
			sclk_out =>	CONFIG_SCLK,
			cs_out   => CONFIG_CS,
			sw_in		=> sw_in
		);	
		
	CONFIG_SHDN	<= '1';
end architecture;
