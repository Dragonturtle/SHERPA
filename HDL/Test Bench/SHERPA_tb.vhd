LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY SHERPA_tb IS
END SHERPA_tb;
 
ARCHITECTURE behavior OF SHERPA_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT top_level
    PORT(
         fx2Clk_in : IN  std_logic;
         fx2Addr_out : OUT  std_logic_vector(1 downto 0);
         fx2Data_io : INOUT  std_logic_vector(7 downto 0);
         fx2Read_out : OUT  std_logic;
         fx2OE_out : OUT  std_logic;
         fx2GotData_in : IN  std_logic;
         fx2Write_out : OUT  std_logic;
         fx2GotRoom_in : IN  std_logic;
         fx2PktEnd_out : OUT  std_logic;
         sseg_out : OUT  std_logic_vector(7 downto 0);
         anode_out : OUT  std_logic_vector(3 downto 0);
         led_out : OUT  std_logic_vector(7 downto 0);
         sw_in : IN  std_logic_vector(7 downto 0);
         ADC_I : IN  std_logic_vector(7 downto 0);
         ADC_Q : IN  std_logic_vector(7 downto 0);
         CLOCK : IN  std_logic_vector(7 downto 0);
			clk : IN  std_logic;
         CONFIG_SDA : INOUT  std_logic;
         CONFIG_SCL : INOUT  std_logic;
         CONFIG_DIN : OUT  std_logic;
         CONFIG_SCLK : OUT  std_logic;
         CONFIG_CS : OUT  std_logic;
         CONFIG_SHDN : OUT  std_logic;
         CONFIG_RXTX : OUT  std_logic;
         CONFIG_CW : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal fx2Clk_in : std_logic := '0';
   signal fx2GotData_in : std_logic := '0';
   signal fx2GotRoom_in : std_logic := '0';
   signal sw_in : std_logic_vector(7 downto 0) := (others => '0');
   signal ADC_I : std_logic_vector(7 downto 0) := (others => '0');
   signal ADC_Q : std_logic_vector(7 downto 0) := (others => '0');
   signal clk : std_logic := '0';
   signal CLOCK : std_logic_vector(7 downto 0) := (others => '0');
   
	--BiDirs
   signal fx2Data_io : std_logic_vector(7 downto 0);
   signal CONFIG_SDA : std_logic;
   signal CONFIG_SCL : std_logic;

 	--Outputs
   signal fx2Addr_out : std_logic_vector(1 downto 0);
   signal fx2Read_out : std_logic;
   signal fx2OE_out : std_logic;
   signal fx2Write_out : std_logic;
   signal fx2PktEnd_out : std_logic;
   signal sseg_out : std_logic_vector(7 downto 0);
   signal anode_out : std_logic_vector(3 downto 0);
   signal led_out : std_logic_vector(7 downto 0);
   signal CONFIG_DIN : std_logic;
   signal CONFIG_SCLK : std_logic;
   signal CONFIG_CS : std_logic;
   signal CONFIG_SHDN : std_logic;
   signal CONFIG_RXTX : std_logic;
   signal CONFIG_CW : std_logic;

   -- Clock period definitions
   constant clk_period  : time := 20 ns;
	constant fx2Clk_period  : time := 20.8333333333333 ns;
   constant clk0_period : time := 305.185 ns;
   constant clk1_period : time := 25 ns;
   constant clk2_period : time := 305.194 ns;
   constant clk3_period : time := 400000 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: top_level PORT MAP (
          fx2Clk_in => fx2Clk_in,
          fx2Addr_out => fx2Addr_out,
          fx2Data_io => fx2Data_io,
          fx2Read_out => fx2Read_out,
          fx2OE_out => fx2OE_out,
          fx2GotData_in => fx2GotData_in,
          fx2Write_out => fx2Write_out,
          fx2GotRoom_in => fx2GotRoom_in,
          fx2PktEnd_out => fx2PktEnd_out,
          sseg_out => sseg_out,
          anode_out => anode_out,
          led_out => led_out,
          sw_in => sw_in,
          ADC_I => ADC_I,
          ADC_Q => ADC_Q,
          clk => clk,
          CLOCK => CLOCK,
          CONFIG_SDA => CONFIG_SDA,
          CONFIG_SCL => CONFIG_SCL,
          CONFIG_DIN => CONFIG_DIN,
          CONFIG_SCLK => CONFIG_SCLK,
          CONFIG_CS => CONFIG_CS,
          CONFIG_SHDN => CONFIG_SHDN,
          CONFIG_RXTX => CONFIG_RXTX,
          CONFIG_CW => CONFIG_CW
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 
	fx2Clk_process :process
   begin
		fx2Clk_in <= '0';
		wait for fx2Clk_period/2;
		fx2Clk_in <= '1';
		wait for fx2Clk_period/2;
   end process;
	
   clk0_process :process
   begin
		CLOCK(0) <= '1';
		wait for clk0_period/2;
		CLOCK(0) <= '0';
		wait for clk0_period/2;
   end process;
 
   clk1_process :process
   begin
		CLOCK(1) <= '1';
		wait for clk1_period/2;
		CLOCK(1) <= '0';
		wait for clk1_period/2;
   end process;
 
   clk2_process :process
   begin
		CLOCK(2) <= '1';
		wait for clk2_period/2;
		CLOCK(2) <= '0';
		wait for clk2_period/2;
   end process;
 
   clk3_process :process
   begin
		CLOCK(3) <= '1';
		wait for clk3_period/2;
		CLOCK(3) <= '0';
		wait for clk3_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;	

      wait for clk_period*10;

      -- insert stimulus here 

      wait;
   end process;

END;
