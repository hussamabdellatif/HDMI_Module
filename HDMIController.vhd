library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_unsigned.all;
library UNISIM;
use UNISIM.VComponents.all;


entity hdmi_controller is
    Port ( sysclk : in std_logic;
          reset_btn   : in std_logic;
          red_data, green_data, blue_data : in std_logic_vector(7 downto 0);
          TMDS, TMDSB : out std_logic_vector(3 downto 0);
          hcount, vcount : out std_logic_vector(10 downto 0));
end hdmi_controller;


architecture Behavioral of hdmi_controller is

-- signals - Create global clock and synchronous system reset.
signal clk50m, clk50m_bufg : std_logic := '0';
signal pclk_lckd, pclk_lckd_n : std_logic;
signal pwrup, switch : std_logic;

-- signal - Switching screen formats 
signal busy : std_logic;
signal sws_sync : std_logic_vector(3 downto 0); -- synchronous output
signal sws_sync_q : std_logic_vector(3 downto 0); -- register
signal sw0_rdy, sw1_rdy, sw2_rdy, sw3_rdy : std_logic; -- debouncing
signal gopclk : std_logic;

-- signals - DCM_CLKGEN SPI controller 
signal progdone, progen, progdata : std_logic;

-- signals - DCM_CLKGEN to generate a pixel clock with a variable frequency 
signal clkfx, pclk : std_logic;

-- signals - Pixel Rate clock buffer 
signal pllclk0, pllclk1, pllclk2 : std_logic;
signal pclkx2, pclkx10, pll_lckd, pll_lckd_n : std_logic;
signal clkfbout : std_logic;
signal serdesstrobe : std_logic;
signal bufpll_lock : std_logic; 

-- Video Timing Parameters
--1280x720@60HZ
constant HPIXELS_HDTV720P : std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(1280, 11)); --Horizontal Live Pixels
constant VLINES_HDTV720P  : std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(720, 11));  --Vertical Live ines
constant HSYNCPW_HDTV720P : std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(80, 11));  --HSYNC Pulse Width
constant VSYNCPW_HDTV720P : std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(5, 11));    --VSYNC Pulse Width
constant HFNPRCH_HDTV720P : std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(72, 11));   --Horizontal Front Porch
constant VFNPRCH_HDTV720P : std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(3, 11));    --Vertical Front Porch
constant HBKPRCH_HDTV720P : std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(216, 11));  --Horizontal Front Porch
constant VBKPRCH_HDTV720P : std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(22, 11));   --Vertical Front Porch

constant pclk_M : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(36, 8));
constant pclk_D : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(24, 8)); 

constant tc_hsblnk: std_logic_vector(10 downto 0) := (HPIXELS_HDTV720P - 1);
constant tc_hssync: std_logic_vector(10 downto 0) := (HPIXELS_HDTV720P - 1 + HFNPRCH_HDTV720P);
constant tc_hesync: std_logic_vector(10 downto 0) := (HPIXELS_HDTV720P - 1 + HFNPRCH_HDTV720P + HSYNCPW_HDTV720P);
constant tc_heblnk: std_logic_vector(10 downto 0) := (HPIXELS_HDTV720P - 1 + HFNPRCH_HDTV720P + HSYNCPW_HDTV720P + HBKPRCH_HDTV720P);
constant tc_vsblnk: std_logic_vector(10 downto 0) := (VLINES_HDTV720P - 1);
constant tc_vssync: std_logic_vector(10 downto 0) := (VLINES_HDTV720P - 1 + VFNPRCH_HDTV720P);
constant tc_vesync: std_logic_vector(10 downto 0) := (VLINES_HDTV720P - 1 + VFNPRCH_HDTV720P + VSYNCPW_HDTV720P);
constant tc_veblnk: std_logic_vector(10 downto 0) := (VLINES_HDTV720P - 1 + VFNPRCH_HDTV720P + VSYNCPW_HDTV720P + VBKPRCH_HDTV720P);
signal sws_clk: std_logic_vector(3 downto 0); --clk synchronous output
signal sws_clk_sync: std_logic_vector(3 downto 0); --clk synchronous output

signal VGA_HSYNC_INT, VGA_VSYNC_INT: std_logic;
signal bgnd_hcount: std_logic_vector(10 downto 0);
signal bgnd_hsync: std_logic;
signal bgnd_hblnk: std_logic;
signal bgnd_vcount: std_logic_vector(10 downto 0);
signal bgnd_vsync: std_logic;
signal bgnd_vblnk: std_logic;

-- signals - V/H SYNC and DE generator 
signal active_q: std_logic;
signal VGA_HSYNC, VGA_VSYNC: std_logic;
signal vsync, hsync: std_logic;
signal de: std_logic;
signal active: std_logic; 
  

-- signals - DVI Encoder  
signal tmds_data0, tmds_data1, tmds_data2: std_logic_vector(4 downto 0);
signal tmdsint: std_logic_vector(2 downto 0);
signal serdes_rst: std_logic; 
signal tmdsclkint: std_logic_vector(4 downto 0) := "00000";
signal toggle: std_logic := '0';
signal tmdsclk: std_logic;
  
signal reset : std_logic;

	COMPONENT synchro
	PORT(
		async : IN std_logic;
		clk : IN std_logic;          
		sync : OUT std_logic
		);
	END COMPONENT;
	COMPONENT synchroType2
	PORT(
		async : IN std_logic;
		clk : IN std_logic;          
		sync : OUT std_logic
		);
	END COMPONENT;

-- described in Verilog in dcmspi.v;
	COMPONENT dcmspi
	PORT(
		RST : IN std_logic;
		PROGCLK : IN std_logic;
		PROGDONE : IN std_logic;
		DFSLCKD : IN std_logic;
		M : IN std_logic_vector(7 downto 0);
		D : IN std_logic_vector(7 downto 0);
		GO : IN std_logic;          
		BUSY : OUT std_logic;
		PROGEN : OUT std_logic;
		PROGDATA : OUT std_logic
		);
	END COMPONENT;	
-- described in Verilog in timing.v;
	COMPONENT timing
	PORT(
		tc_hsblnk : IN std_logic_vector(10 downto 0);
		tc_hssync : IN std_logic_vector(10 downto 0);
		tc_hesync : IN std_logic_vector(10 downto 0);
		tc_heblnk : IN std_logic_vector(10 downto 0);
		tc_vsblnk : IN std_logic_vector(10 downto 0);
		tc_vssync : IN std_logic_vector(10 downto 0);
		tc_vesync : IN std_logic_vector(10 downto 0);
		tc_veblnk : IN std_logic_vector(10 downto 0);
		restart : IN std_logic;
		clk : IN std_logic;          
		hcount : OUT std_logic_vector(10 downto 0);
		hsync : OUT std_logic;
		hblnk : OUT std_logic;
		vcount : OUT std_logic_vector(10 downto 0);
		vsync : OUT std_logic;
		vblnk : OUT std_logic
		);
	END COMPONENT;	

-- described in Verilog in dvi_encoder.v;
	COMPONENT dvi_encoder
	PORT(
		clkin : IN std_logic;
		clkx2in : IN std_logic;
		rstin : IN std_logic;
		blue_din : IN std_logic_vector(7 downto 0);
		green_din : IN std_logic_vector(7 downto 0);
		red_din : IN std_logic_vector(7 downto 0);
		hsync : IN std_logic;
		vsync : IN std_logic;
		de : IN std_logic;          
		tmds_data0 : OUT std_logic_vector(4 downto 0);
		tmds_data1 : OUT std_logic_vector(4 downto 0);
		tmds_data2 : OUT std_logic_vector(4 downto 0)
		);
	END COMPONENT;
-- described in Verilog in serdes_n_to_1.v;
	COMPONENT serdes_n_to_1
	PORT(
		ioclk : IN std_logic;
		serdesstrobe : IN std_logic;
		reset : IN std_logic;
		gclk : IN std_logic;
		datain : IN std_logic_vector(4 downto 0);          
		iob_data_out : OUT std_logic
		);
	END COMPONENT;
	
begin

--******************************************************************
-- Create global clock and synchronous system reset.                
--******************************************************************

process(clk50m_bufg)
begin
    if rising_edge(clk50m_bufg) then
        switch <= pwrup;
    end if;
end process;

-- off-chip clock signal > IBUF > BUFIO2 > BUFG on-chip clock signal
-- instance of IBUF
--sysclk_buf : IBUF port map(I=>SYS_CLK, O=>sysclk);

process(sysclk)
begin
	if rising_edge(sysclk) then
		clk50m <= not clk50m;
	end if;
end process;

-- instance of I/O Clock Buffer used as divider
--sysclk_div : BUFIO2
--	generic map (
--		DIVIDE_BYPASS=>FALSE, 
--		DIVIDE=>2)
--	port map (
--		DIVCLK=>clk50m,
--		I=>sysclk);
	
-- instance of BUFG
clk50m_bufgbufg : BUFG port map (I=>clk50m, O=>clk50m_bufg);

--16 bit Shift Register LUT with Clock Enable
--more info: read 4_SRL16E_wp271.pdf from the archive of this lab
pwrup_0 : SRL16E 
	generic map (
		INIT => X"1111")
	port map(
		Q=>pwrup,
		A0=>'1',
		A1=>'1',
		A2=>'1',
		A3=>'1',
		CE=>pclk_lckd,
		CLK=>clk50m_bufg,
		D=>'0');

--******************************************************************
-- Switching screen formats               
--******************************************************************

  
SRL16E_0 : SRL16E port map (
	Q=>gopclk,
	A0=>'1',
	A1=>'1',
	A2=>'1',
	A3=>'1',
	CE=>'1',
	CLK=>clk50m_bufg,
	D=>switch);


--******************************************************************
-- DCM_CLKGEN SPI controller              
--******************************************************************
  
dcmspi_0 : dcmspi port map (
	RST=>switch,          --Synchronous Reset
	PROGCLK=>clk50m_bufg, --SPI clock
	PROGDONE=>progdone,   --DCM is ready to take next command
	DFSLCKD=>pclk_lckd,
	M=>pclk_M,            --DCM M value
	D=>pclk_D,            --DCM D value
	GO=>gopclk,           --Go programme the M and D value into DCM(1 cycle pulse)
	BUSY=>busy,
	PROGEN=>progen,       --SlaveSelect,
	PROGDATA=>progdata    --CommandData
);

--******************************************************************
-- DCM_CLKGEN to generate a pixel clock with a variable frequency     
--******************************************************************

PCLK_GEN_INST : DCM_CLKGEN 
	generic map (
		CLKFX_DIVIDE=>21,
		CLKFX_MULTIPLY=>31,
		CLKIN_PERIOD=>20.000)
   port map (
		CLKFX=>clkfx,
		--CLKFX180=>,
		--CLKFXDV=>,
		LOCKED=>pclk_lckd,
		PROGDONE=>progdone,
		--STATUS=>,
		CLKIN=>clk50m,
		FREEZEDCM=>'0',
		PROGCLK=>clk50m_bufg,
		PROGDATA=>progdata,
		PROGEN=>progen,
		RST=>'0');

--******************************************************************
-- Pixel Rate clock buffer     
--******************************************************************

pclkbufg : BUFG port map (I=>pllclk1, O=>pclk);

-- 2x pclk is going to be used to drive OSERDES2
-- on the GCLK side
pclkx2bufg : BUFG port map (I=>pllclk2, O=>pclkx2);

-- 10x pclk is used to drive IOCLK network so a bit rate reference
-- can be used by OSERDES2
PLL_OSERDES : PLL_BASE
	generic map (
		CLKIN_PERIOD=>13.0,
		CLKFBOUT_MULT=>10, --set VCO to 10x of CLKIN
		CLKOUT0_DIVIDE=>1,
		CLKOUT1_DIVIDE=>10,
		CLKOUT2_DIVIDE=>5,
		COMPENSATION=>"INTERNAL")  
	port map (
		CLKFBOUT=>clkfbout,
		CLKOUT0=>pllclk0,
		CLKOUT1=>pllclk1,
		CLKOUT2=>pllclk2,
		--CLKOUT3=>,
		--CLKOUT4=>,
		--CLKOUT5=>,
		LOCKED=>pll_lckd,
		CLKFBIN=>clkfbout,
		CLKIN=>clkfx,
		RST=>pclk_lckd_n);

ioclk_buf: BUFPLL 
	generic map (DIVIDE=>5) 
	port map (PLLIN=>pllclk0, GCLK=>pclkx2, LOCKED=>pll_lckd,
      IOCLK=>pclkx10, SERDESSTROBE=>serdesstrobe, LOCK=>bufpll_lock);

synchro_reset : synchroType2 
   port map (async=>pll_lckd_n, sync=>reset, clk=>pclk);
  
--******************************************************************
-- Video Timing Parameters    
--******************************************************************
  

timing_inst : timing port map (
	tc_hsblnk=>tc_hsblnk, --input
	tc_hssync=>tc_hssync, --input
	tc_hesync=>tc_hesync, --input
	tc_heblnk=>tc_heblnk, --input
	hcount=>hcount, --output
	hsync=>VGA_HSYNC_INT, --output
	hblnk=>bgnd_hblnk, --output
	tc_vsblnk=>tc_vsblnk, --input
	tc_vssync=>tc_vssync, --input
	tc_vesync=>tc_vesync, --input
	tc_veblnk=>tc_veblnk, --input
	vcount=>vcount, --output
	vsync=>VGA_VSYNC_INT, --output
	vblnk=>bgnd_vblnk, --output
	restart=>reset,
	clk=>pclk);

--******************************************************************
-- V/H SYNC and DE generator   
--******************************************************************

active <= not(bgnd_hblnk) and not(bgnd_vblnk);


process (pclk)
begin
	if rising_edge (pclk) then
		hsync <= not VGA_HSYNC_INT;
		vsync <= not VGA_VSYNC_INT;
		VGA_HSYNC <= hsync;
		VGA_VSYNC <= vsync;
		active_q <= active;
		de <= active_q;
	end if;
end process;

--******************************************************************
-- DVI Encoder  
--******************************************************************

enc0 : dvi_encoder port map (
	clkin      =>pclk,
	clkx2in    =>pclkx2,
	rstin      =>reset,
	blue_din   =>blue_data,
	green_din  =>green_data,
	red_din    =>red_data,
	hsync      =>VGA_HSYNC,
	vsync      =>VGA_VSYNC,
	de         =>de,
	tmds_data0 =>tmds_data0,
	tmds_data1 =>tmds_data1,
	tmds_data2 =>tmds_data2);

serdes_rst <= reset_btn or not(bufpll_lock);


oserdes0 : serdes_n_to_1 
	port map(
		ioclk=>pclkx10,
		serdesstrobe=>serdesstrobe,
		reset=>serdes_rst,
		gclk=>pclkx2,
		datain=>tmds_data0,
		iob_data_out=>tmdsint(0));
		
oserdes1 : serdes_n_to_1 
	port map(
		ioclk=>pclkx10,
		serdesstrobe=>serdesstrobe,
		reset=>serdes_rst,
		gclk=>pclkx2,
		datain=>tmds_data1,
		iob_data_out=>tmdsint(1));
		
oserdes2 : serdes_n_to_1 
	port map(
		ioclk=>pclkx10,
		serdesstrobe=>serdesstrobe,
		reset=>serdes_rst,
		gclk=>pclkx2,
		datain=>tmds_data2,
		iob_data_out=>tmdsint(2));		

TMDS0 : OBUFDS port map (I=>tmdsint(0), O=>TMDS(0), OB=>TMDSB(0));
TMDS1 : OBUFDS port map (I=>tmdsint(1), O=>TMDS(1), OB=>TMDSB(1));
TMDS2 : OBUFDS port map (I=>tmdsint(2), O=>TMDS(2), OB=>TMDSB(2));
  
process (pclkx2, serdes_rst)
begin
	if serdes_rst = '1' then
		toggle <= '0';
	elsif rising_edge(pclkx2) then
		toggle <= not(toggle);	
	end if;
end process;

process (pclkx2)
begin
	if rising_edge(pclkx2) then
		if (toggle = '1') then
			tmdsclkint <= "11111";
		else
			tmdsclkint <= "00000";
		end if;
	end if;
end process;

clkout : serdes_n_to_1 port map (
	iob_data_out =>tmdsclk,
	ioclk        =>pclkx10,
	serdesstrobe =>serdesstrobe,
	gclk         =>pclkx2,
	reset        =>serdes_rst,
	datain       =>tmdsclkint);

TMDS3 : OBUFDS port map (I=>tmdsclk, O=>TMDS(3), OB=>TMDSB(3)); -- clock

pclk_lckd_n <= not pclk_lckd;
pll_lckd_n <= not pll_lckd;

end Behavioral;
