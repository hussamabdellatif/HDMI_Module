library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Lab5 is
    Port ( sys_clk : in std_logic;
          reset_btn   : in std_logic;
          TMDS, TMDSB : out std_logic_vector(3 downto 0));
end Lab5;

architecture Behavioral of Lab5 is

component hdmi_controller 
    Port ( sysclk : in std_logic;
          reset_btn   : in std_logic;
          red_data, green_data, blue_data : in std_logic_vector(7 downto 0);
          TMDS, TMDSB : out std_logic_vector(3 downto 0);
          hcount, vcount : out std_logic_vector(10 downto 0));
end component;

signal red_data, green_data, blue_data : std_logic_vector(7 downto 0) := (others => '0');
signal color_data : std_logic_vector(7 downto 0) := (others => '0');
signal hcount, vcount : std_logic_vector(10 downto 0);
signal slow_clk : std_logic := '0';
signal slow_clk_count : unsigned(26 downto 0) := (others =>'0');
signal state : integer := 0;


begin

cont : hdmi_controller port map
	(sysclk => sys_clk,
	 reset_btn => reset_btn,
	 red_data => red_data,
	 green_data => green_data,
	 blue_data => blue_data,
	 TMDS => TMDS,
	 TMDSB => TMDSB,
	 hcount => hcount,
	 vcount => vcount);
	 

--To simplify the code, I suggest using a combinational process to drive red_data, green_data, and blue_data
--For example:
-- process(hcount, vcount, state)



	slow_clk_proc : process(sys_clk)
	begin
		if rising_edge(sys_clk) then
			if slow_clk_count = 100000000 then
				slow_clk <='1';
				slow_clk_count <= (others=>'0');
			else
				slow_clk <= '0';
				slow_clk_count <= slow_clk_count + 1;
			end if;
		end if;
	end process;
	
	state_proc : process(slow_clk)
	begin
		if slow_clk = '1' then
			if state < 3 then 
				state <= state + 1;
			else
				state <= 0;
			end if;
		end if;
	end process;
     
	 -- red_data <= X"FF" when hcount > X"21C" and hcount < X"2E4" and vcount > X"104" and vcount < X"1CC" else X"00"; 

	process(hcount, vcount, state)
		begin
		if hcount > X"21C" and hcount < X"2E4" and vcount > X"104" and vcount < X"1CC" then
			case state is 
				when 0 =>  red_data <= X"FF"; blue_data <= X"00"; green_data <=X"00"; 
				when 1 =>  red_data <= X"FF"; blue_data <= X"EE"; green_data <=X"89"; 
				when 2 =>  red_data <= X"B0"; blue_data <= X"FF"; green_data <=X"FE"; 
				when 3 =>  red_data <= X"4A"; blue_data <= X"BB"; green_data <=X"AA"; 
				when others => red_data <= X"00";blue_data <= X"00"; green_data <=X"00"; 
			end case;	
		else
			red_data <= X"00";blue_data <= X"00"; green_data <=X"00"; 
		end if;
	end process;
	  
end Behavioral;


