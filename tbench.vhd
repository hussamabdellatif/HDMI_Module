--------------------------------------------------------------------------------
-- Company: 
-- Engineer: Hussam Abdellatif
--
-- Create Date:   21:51:41 10/24/2017
-- Design Name:   
-- Module Name: 
-- Project Name: 
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: Lab5
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY Lab5_tbench IS
END Lab5_tbench;
 
ARCHITECTURE behavior OF Lab5_tbench IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT Lab5
    PORT(
         sys_clk : IN  std_logic;
         reset_btn : IN  std_logic;
         TMDS : OUT  std_logic_vector(3 downto 0);
         TMDSB : OUT  std_logic_vector(3 downto 0)
        );
    END COMPONENT;
    

   --Inputs
   signal sys_clk : std_logic := '0';
   signal reset_btn : std_logic := '0';

 	--Outputs
   signal TMDS : std_logic_vector(3 downto 0);
   signal TMDSB : std_logic_vector(3 downto 0);

   -- Clock period definitions
   constant sys_clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: Lab5 PORT MAP (
          sys_clk => sys_clk,
          reset_btn => reset_btn,
          TMDS => TMDS,
          TMDSB => TMDSB
        );

   -- Clock process definitions
   sys_clk_process :process
   begin
		sys_clk <= '0';
		wait for sys_clk_period/2;
		sys_clk <= '1';
		wait for sys_clk_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
      wait for 100 ns;	

      wait for sys_clk_period*10;
		
		reset_btn <= '0';

      -- insert stimulus here 

      wait;
   end process;

END;
