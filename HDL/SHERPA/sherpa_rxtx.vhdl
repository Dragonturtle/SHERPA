library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity sherpa_rxtx is
	port(
		reset_in     : in  std_logic;
		
		-- Clock interface --------------------------------------------------------------------------
		usb_clk_in   : in   std_logic;
		adc_clk_in   : in   std_logic;
		dac_clk_in   : in   std_logic;
		sync_clk_out : out  std_logic;

		-- DVR interface -----------------------------------------------------------------------------
		data_out  : out std_logic_vector(7 downto 0);  -- data lines used when the host reads from a channel
		valid_out : out std_logic;                     -- channel logic can drive this low to say "I don't have data ready for you"
		ready_in  : in  std_logic;                     -- '1' means "on the next clock rising edge, put your next byte of data on f2hData"

		-- Peripheral interface ----------------------------------------------------------------------
		sseg_out       : out   std_logic_vector(7 downto 0); -- seven-segment display cathodes (one for each segment)
		anode_out      : out   std_logic_vector(3 downto 0); -- seven-segment display anodes (one for each digit)
		led_out        : out   std_logic_vector(7 downto 0); -- eight LEDs
		sw_in 	      : in    std_logic_vector(7 downto 0);  -- eight switches
		
		RX_in				: in	  std_logic_vector(7 downto 0);
		TX_out			: out	  std_logic_vector(7 downto 0) := "00000000";
		dacCW_out		: out   std_logic;
		RXTX_out			: out   std_logic
	);
end entity;

architecture rtl of sherpa_rxtx is
	alias rst : std_logic is reset_in;
	
	-- Flags for display on the 7-seg decimal points
	signal flags               : std_logic_vector(3 downto 0);

	-- USB FIFO
	signal fifoCount           : std_logic_vector(14 downto 0); 
	signal fifoInputData       : std_logic_vector(7 downto 0);  -- producer: data
	signal fifoInputValid      : std_logic;                     --           valid flag
	signal fifoInputReady      : std_logic;                     --           ready flag
	signal fifoOutputData      : std_logic_vector(7 downto 0);  -- consumer: data
	signal fifoOutputValid     : std_logic;                     --           valid flag
	signal fifoOutputReady     : std_logic;                     --           ready flag

	-- Control states
	type 	 activityState_type is (initialize, idle, active); 
	type   functionState_type is (transmit, receive);
	
	signal activityState : activityState_type := initialize; 
	signal functionState : functionState_type := receive; 
	
	-- Data transfer
	signal transmitDataReady 	: std_logic;
	signal receiveDataReady	 	: std_logic;
	signal sync_clk 				: std_logic;
	
	signal dataCount 	:  std_logic_vector(7 downto 0)  := (others => '0');
	signal dataVector	: 	std_logic_vector(98 downto 0) := (others => '1');
	signal dataBit		:	std_logic := '0';
	
	-- Data compression
	signal shiftValue	:	std_logic_vector(7 downto 0)  := (others => '0');
	signal shiftValid	:	std_logic := '0';
	
	signal adc_data  			: std_logic;
	signal syncFlag			: std_logic := '0';
	
	signal counter  : std_logic_vector(15 downto 0) := (others => '0');
	
	signal dacControl : std_logic_vector(7 downto 0) := "01101000";
	signal prnSignal  : std_logic_vector(7 downto 0) := (others => '0');
	
	signal SSCount		:  std_logic_vector(15 downto 0) := (others => '0');
begin                                     

	--------------------------------------
	--- Generate synchronization clock ---
	--------------------------------------
	clock_syncer : entity work.clock_syncer
	port map (
		dac_clk_in 	=> dac_clk_in,
		adc_clk_in 	=> adc_clk_in,
		reset_in		=> rst,
		sync_out 	=> sync_clk
	);
	sync_clk_out <= sync_clk;
	
	-------------------------------------------------------
	--- Toggle between RX and TX at specified intervals ---
	-------------------------------------------------------
	transmitDataReady <= '1' when activityState = active and functionState = transmit else '0';
	receiveDataReady  <= '1' when activityState = active and functionState = receive  else '0';
	dataBit <= dataVector(to_integer(unsigned(dataCount)));
	TX_out <= dacControl when activityState = initialize else prnSignal;
	RXTX_out <= '1' when activityState = active and functionState = transmit else '0';
	
	functionState <= transmit when sw_in(7) = '1' else receive;
	
	state_machine : process(rst, sync_clk)	
	begin
		if (rst = '1') then
			dataCount		<= (others => '0');
			activityState	<= initialize;
--			functionState  <= initialize;
			syncFlag 		<= '0';
		elsif ( rising_edge(sync_clk) ) then	
			case activityState is
				when initialize =>
					if (to_integer(unsigned(dataCount)) = 2) then
						dataCount <= (others => '0');
						activityState <= idle;
						--functionState <= transmit;
						dacCW_out <= '1';
					else
						dacCW_out <= '0';
						dataCount <= std_logic_vector(unsigned(dataCount) + 1);
					end if;	
				when active => 	
					syncFlag <= not syncFlag;
					if (to_integer(unsigned(dataCount)) >= 98) then
						dataCount <= (others => '0');
						--activityState <= idle;
					else
						dataCount <= std_logic_vector(unsigned(dataCount) + 1);
					end if;	
				when idle =>
					if (functionState = transmit) then
						--functionState <= receive;
					else
						--functionState <= transmit;
					end if;
					activityState <= active;
			end case;
		end if;
	end process;


	-------------------------
	--- Generate PRN code ---
	-------------------------
	prn_code_generator : entity work.prn_code_generator
	generic map (
	  idx1	=>  1,
	  idx2	=>  5
	) port map (
	  enable_in	=>	transmitDataReady,
	  data_in	=>	dataBit,
	  clock_in  => dac_clk_in,
	  I_out    	=> prnSignal,
	  Q_out    	=> open
	);

	-------------------------
	--- Write to USB FIFO ---
	-------------------------
	fifoInputValid 	<= '1' when receiveDataReady = '1' else '0';	
	fifoOutputReady 	<= '1' when ready_in = '1' else '0';
	valid_out <= '0' when fifoOutputValid = '0' else '1';
	data_out <= fifoOutputData; 
	read_fifo : entity work.fifo_wrapper
		port map(
			wr_clk_in       => adc_clk_in,
			rd_clk_in     	 => usb_clk_in,
			depth_out       => fifoCount,

			-- Production end
			inputData_in    => RX_in, --fifoInputData,
			inputValid_in   => fifoInputValid,
			inputReady_out  => fifoInputReady,

			-- Consumption end
			outputData_out  => fifoOutputData,
			outputValid_out => fifoOutputValid,
			outputReady_in  => fifoOutputReady
		);

	--------------------------
	--- Handle LED Display ---
	--------------------------
	SSCount(6 downto 0) <= sw_in(6 downto 0);
	SSCount(8) <= '1' when functionState = transmit else '0';
	flags <= '0' & sync_clk & '0' & sync_clk;
	seven_seg : entity work.seven_seg
		port map(
			clk_in     => adc_clk_in,
			data_in    => SSCount,
			dots_in    => flags,
			segs_out   => sseg_out,
			anodes_out => anode_out
		);
end architecture;
