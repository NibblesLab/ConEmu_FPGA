----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:16:47 02/22/2014 
-- Design Name: 
-- Module Name:    CRTEMU - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity CRTEMU is
    Port (
		-- RGB in
		xRI : in  STD_LOGIC;
		xGI : in  STD_LOGIC;
		xBI : in  STD_LOGIC;
		xVSI : in  STD_LOGIC;
		xHSI : in  STD_LOGIC;
		-- RGB out
		RO : out  STD_LOGIC;
		GO : out  STD_LOGIC;
		BO : out  STD_LOGIC;
		VSO : out  STD_LOGIC;
		HSO : out  STD_LOGIC;
		-- FT232H Signals
		FT_CLK : in std_logic;
		FT_DT : inout std_logic_vector(7 downto 0);
		FT_RXF_x : in std_logic;
		FT_TXE_x : in std_logic;
		FT_RD_x : out std_logic;
		FT_WR_x : out std_logic;
		FT_SIWU_x : out std_logic;
		FT_OE_x : out std_logic;
		-- Keyboard/Mouse Signals
		KBDT : out std_logic;
		REQ : in std_logic;
		MSDT : out std_logic;
		-- Board Function
		CLK : in  STD_LOGIC;
		LED : out std_logic_vector(1 downto 0);
		TST : out std_logic_vector(3 downto 0);
		SW : in  STD_LOGIC
	);
end CRTEMU;

architecture Behavioral of CRTEMU is

-- RGB input
signal RI : std_logic;			-- Non-inverted R signal
signal GI : std_logic;			-- Non-inverted G signal
signal BI : std_logic;			-- Non-inverted B signal
signal VSI : std_logic;			-- Non-inverted V-Sync signal
signal HSI : std_logic;			-- Non-inverted H-Sync signal
signal CLK57M : std_logic;		-- 15kHz base Clock for input
signal ICTR : std_logic_vector(11 downto 0);	-- Address counter for RGB-in
signal BUFI : std_logic_vector(3 downto 0);	-- Write RGB data
signal Si0 : std_logic_vector(5 downto 0);	-- Shift Register for Detect H-sync (15kHz)
signal WEA : std_logic_vector(0 downto 0);	-- Write Enable for Scan Converter RAM
signal WEP : std_logic_vector(0 downto 0);	-- Write Enable for RGB-in (7bits every)
signal PCTR : std_logic_vector(2 downto 0);	-- Counter for Bits-Combining
signal PADR : std_logic_vector(7 downto 0);	-- Address counter for RGB-in (7bits every)
signal RS : std_logic_vector(6 downto 0);		-- Shift Register for R signal
signal GS : std_logic_vector(6 downto 0);		-- Shift Register for G signal
signal BS : std_logic_vector(6 downto 0);		-- Shift Register for B signal
signal RGBS : std_logic_vector(20 downto 0);	-- Signal for shifted RGB signals
signal CLK86M : std_logic;		-- 24kHz base Clock for input
signal Si4 : std_logic_vector(5 downto 0);	-- Shift Register for Detect H-sync (24kHz)
signal ICTR4 : std_logic_vector(1 downto 0);	-- Dot counter for RGB-in (24kHz)
signal PCTR4 : std_logic_vector(2 downto 0);	-- Counter for Bits-Combining (24kHz)
signal PADR4 : std_logic_vector(7 downto 0);	-- Address counter for RGB-in (7bits every, 24kHz)
signal RS4 : std_logic_vector(6 downto 0);		-- Shift Register for R signal (24kHz)
signal GS4 : std_logic_vector(6 downto 0);		-- Shift Register for G signal (24kHz)
signal BS4 : std_logic_vector(6 downto 0);		-- Shift Register for B signal (24kHz)
signal RGBS4 : std_logic_vector(20 downto 0);	-- Signal for shifted RGB signals (24kHz)
signal WEP4 : std_logic_vector(0 downto 0);	-- Write Enable for RGB-in (7bits every, 24kHz)
-- VGA output
signal RB : std_logic;			-- R signal read from BRAM
signal GB : std_logic;			-- G signal read from BRAM
signal BB : std_logic;			-- B signal read from BRAM
signal HS : std_logic;			-- H-Sync for VGA-out
signal HBLANK : std_logic;		-- Horizontal Blanking
signal CLK100M : std_logic;	-- VGA base Clock for output
signal OCTR : std_logic_vector(11 downto 0);	-- Address counter for VGA-out
signal CCTR100 : std_logic_vector(12 downto 0);	-- Dot counter for VGA-out (line doubler)
signal TS : std_logic_vector(11 downto 0);	-- Half of doubled line
signal BUFO : std_logic_vector(3 downto 0);	-- Read RGB data
signal Hi : std_logic_vector(5 downto 0);		-- Shift Register for Detect H-sync
-- Detect Frequency mode
signal FCTR : std_logic_vector(12 downto 0);	-- Counter for detect Frequency
signal FMODE : std_logic;		-- Frequency mode 0:24kHz 1:15kHz
signal FFLG : std_logic;		-- Frequency mode flag in 1 line
signal Si1 : std_logic_vector(5 downto 0);	-- Shift Register for Detect V-sync
-- Keyboard
signal KSDT : std_logic_vector(16 downto 0);	-- Key Data from USB
signal KST : std_logic;								-- Start Key Data to X1
signal KCTR : std_logic_vector(14 downto 0);	-- 1/15000 Counter for Key Serial Pulse
signal KBIT : std_logic_vector(4 downto 0);	-- Key Data's bit position
signal KFIN : std_logic_vector(15 downto 0);	-- Key Data to FIFO
signal KFOUT : std_logic_vector(15 downto 0);	-- Key Data from FIFO
signal KFULL : std_logic;							-- Key Data FIFO full
signal KEMPTY : std_logic;							-- Key Data FIFO empty
signal KREN : std_logic;							-- Key Data Read enable
signal KWEN : std_logic;							-- Key Data Write enable
-- Mouse
signal MCTR : std_logic_vector(14 downto 0);	-- 1/12000 Counter for Mouse Serial Data
signal Si5 : std_logic_vector(1 downto 0);	-- Shift Register for Detect Mouse request
signal MSSDT : std_logic_vector(28 downto 0) := "11111111111111111111111111111";	-- Shift Register for Mouse serial data
signal LBTN : std_logic;							-- Left Button of Mouse
signal RBTN : std_logic;							-- Right Button of Mouse
signal XCTR : std_logic_vector(7 downto 0) := "10000000";	-- Mouse movement for X-axis
signal YCTR : std_logic_vector(7 downto 0) := "10000000";	-- Mouse movement for Y-axis
signal OP_X : std_logic;							-- Add/Sub operation for X-axis
signal OP_Y : std_logic;							-- Add/Sub operation for Y-axis
signal RDT1 : std_logic_vector(7 downto 0);	-- Payload 1 from USB
signal XOVF : std_logic;							-- Over flow for X-axis
signal XUDF : std_logic;							-- Under flow for X-axis
signal YOVF : std_logic;							-- Over flow for Y-axis
signal YUDF : std_logic;							-- Under flow for Y-axis
signal ADDX : std_logic_vector(8 downto 0);	-- Increase X-axis value
signal SUBX : std_logic_vector(8 downto 0);	-- Decrease X-axis value
signal ADDY : std_logic_vector(8 downto 0);	-- Increase Y-axis value
signal SUBY : std_logic_vector(8 downto 0);	-- Decrease Y-axis value
-- for USB
signal BMODE : std_logic;							-- BOX Active
signal SEN_L : std_logic;							-- Send Enable for RGB dsta in range of Line number
signal SEN_F : std_logic;							-- Send Enable for RGB dsta by skipped lines
signal SSTART : std_logic;							-- Send Start Flag
signal SLINE : std_logic_vector(2 downto 0);	-- Send Line
signal Si2 : std_logic_vector(9 downto 0);	-- Shift Register for Detect H-sync
signal Si3 : std_logic_vector(9 downto 0);	-- Shift Register for Detect V-sync
signal LCTR : std_logic_vector(13 downto 0);	-- Line Number in RGB-in
signal L_BGN : std_logic_vector(13 downto 0);	-- Line Number in RGB-in for start of xfer
signal L_END : std_logic_vector(13 downto 0);	-- Line Number in RGB-in for end of xfer
signal L_BGN2 : std_logic_vector(13 downto 0) := "00000000100010";	-- Line Number in RGB-in for start of xfer (15kHz)
signal L_END2 : std_logic_vector(13 downto 0) := "00000011101010";	-- Line Number in RGB-in for end of xfer (15kHz)
signal L_BGN4 : std_logic_vector(13 downto 0) := "00000000100010";	-- Line Number in RGB-in for start of xfer (24kHz)
signal L_END4 : std_logic_vector(13 downto 0) := "00000110110010";	-- Line Number in RGB-in for end of xfer (24kHz)
signal LNUM_R : std_logic_vector(13 downto 0);	-- Line Number to send (register)
signal LNUM : std_logic_vector(13 downto 0);	-- Line Number to send
signal D_BGN2 : std_logic_vector(7 downto 0) := "00010100";	-- Dot Number in RGB-in for start of xfer (15kHz)
signal D_BGN4 : std_logic_vector(7 downto 0) := "00010100";	-- Dot Number in RGB-in for start of xfer (24kHz)
signal OFSTX : std_logic_vector(7 downto 0);	-- Dot counter for x-offset
signal OFSTX4 : std_logic_vector(7 downto 0);	-- Dot counter for x-offset (24kHz)
signal BCTR : std_logic_vector(7 downto 0);	-- Address counter for USB-out
signal VCTR : std_logic_vector(2 downto 0);	-- Frame counter for USB-out
signal MASK : std_logic_vector(2 downto 0) := "111";	-- Mask value for Frame counter
signal RX : std_logic_vector(7 downto 0);		-- R data to USB
signal GX : std_logic_vector(7 downto 0);		-- G data to USB
signal BX : std_logic_vector(7 downto 0);		-- B data to USB
signal RGBX : std_logic_vector(20 downto 0);	-- Signal for RGB datas to USB
signal RGBX4 : std_logic_vector(20 downto 0);	-- Signal for RGB datas to USB (24kHz)
signal FTR : std_logic_vector(7 downto 0);		-- Footer 0x80:15kHz 0x88:24kHz
signal RHDR : std_logic_vector(7 downto 0);	-- Header from USB
--signal RDT2 : std_logic_vector(7 downto 0);	-- Payload 2 from USB
-- Miscellaneous
signal CLKTMP0 : std_logic;	-- Clock between DCMs
signal CLKTMP1 : std_logic;	-- Clock between DCMs
signal CLKTMP2 : std_logic;	-- Clock between DCMs
-- for Test or Debug
--signal TMPC : integer range 0 to 50000000;
-- for State Machine
signal CUR : std_logic_vector(3 downto 0);	-- Current State
signal NXT : std_logic_vector(3 downto 0);	-- Next State
constant WAIT_HS : std_logic_vector(3 downto 0) := "0000";
constant WAIT_TXE : std_logic_vector(3 downto 0) := "0001";
constant WRIT_LNH : std_logic_vector(3 downto 0) := "0010";
constant WRIT_LNL : std_logic_vector(3 downto 0) := "0011";
constant WRIT_R : std_logic_vector(3 downto 0) := "0100";
constant WRIT_G : std_logic_vector(3 downto 0) := "0101";
constant WRIT_B : std_logic_vector(3 downto 0) := "0110";
constant WRIT_FTR : std_logic_vector(3 downto 0) := "0111";
constant SEND_SI : std_logic_vector(3 downto 0) := "1000";
constant WAIT_RXF : std_logic_vector(3 downto 0) := "1001";
constant SEND_OE : std_logic_vector(3 downto 0) := "1010";
constant READ_HDR : std_logic_vector(3 downto 0) := "1011";
constant READ_DT0 : std_logic_vector(3 downto 0) := "1100";
constant READ_DT1 : std_logic_vector(3 downto 0) := "1101";
constant READ_DT2 : std_logic_vector(3 downto 0) := "1110";
constant WAIT_SIE : std_logic_vector(3 downto 0) := "1111";
signal CUR2 : std_logic_vector(4 downto 0);	-- Current State
signal NXT2 : std_logic_vector(4 downto 0);	-- Next State
constant WAIT_KST : std_logic_vector(4 downto 0) := "00000";
constant SEND_KHD_L1 : std_logic_vector(4 downto 0) := "00001";
constant SEND_KHD_L2 : std_logic_vector(4 downto 0) := "00010";
constant SEND_KHD_L3 : std_logic_vector(4 downto 0) := "00011";
constant SEND_KHD_L4 : std_logic_vector(4 downto 0) := "00100";
constant SEND_KHD_H1 : std_logic_vector(4 downto 0) := "00101";
constant SEND_KHD_H2 : std_logic_vector(4 downto 0) := "00110";
constant SEND_KHD_H3 : std_logic_vector(4 downto 0) := "00111";
constant SEND_KDT_L : std_logic_vector(4 downto 0) := "01000";
constant SEND_KDT_H1 : std_logic_vector(4 downto 0) := "01001";
constant SEND_KDT_H2 : std_logic_vector(4 downto 0) := "01010";
constant SEND_KDT_H3 : std_logic_vector(4 downto 0) := "01011";
constant SEND_KDT_H4 : std_logic_vector(4 downto 0) := "01100";
constant SEND_KDT_H5 : std_logic_vector(4 downto 0) := "01101";
constant SEND_KDT_H6 : std_logic_vector(4 downto 0) := "01110";
constant SEND_KDT_H7 : std_logic_vector(4 downto 0) := "01111";
constant CLER_KST : std_logic_vector(4 downto 0) := "10000";

	--
	-- Components
	--
	component clk_45M
	port
		(-- Clock in ports
		CLK_IN1           : in     std_logic;
		-- Clock out ports
		CLK_OUT1          : out    std_logic;
		CLK_OUT2          : out    std_logic;
		CLK_OUT3          : out    std_logic
		);
	end component;

	component clk_57M
	port
		(-- Clock in ports
		CLK_IN1           : in     std_logic;
		-- Clock out ports
		CLK_OUT1          : out    std_logic
		);
	end component;

	component clk_17M
	port
		(-- Clock in ports
		CLK_IN1           : in     std_logic;
		-- Clock out ports
		CLK_OUT1          : out    std_logic
		);
	end component;

	component clk_86M
	port
		(-- Clock in ports
		CLK_IN1           : in     std_logic;
		-- Clock out ports
		CLK_OUT1          : out    std_logic
		);
	end component;

	COMPONENT usram
	PORT (
		clka : IN STD_LOGIC;
		wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
		addra : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
		dina : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
		clkb : IN STD_LOGIC;
		addrb : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
		doutb : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
	);
	END COMPONENT;

	COMPONENT ceram
	PORT (
		clka : IN STD_LOGIC;
		wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
		addra : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		dina : IN STD_LOGIC_VECTOR(20 DOWNTO 0);
		clkb : IN STD_LOGIC;
		addrb : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
		doutb : OUT STD_LOGIC_VECTOR(20 DOWNTO 0)
	);
	END COMPONENT;

	COMPONENT kfifo
	PORT (
		clk : IN STD_LOGIC;
		din : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		wr_en : IN STD_LOGIC;
		rd_en : IN STD_LOGIC;
		dout : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		full : OUT STD_LOGIC;
		empty : OUT STD_LOGIC
	);
	END COMPONENT;

begin

	--
	-- Instantiation
	--
	CKGEN0 : clk_45M
		port map
		(	-- Clock in ports
			CLK_IN1 => CLK,
			-- Clock out ports
			CLK_OUT1 => CLKTMP0,
			CLK_OUT2 => CLK100M,
			CLK_OUT3 => CLKTMP1);

	CKGEN1 : clk_57M
		port map
		(	-- Clock in ports
			CLK_IN1 => CLKTMP0,
			-- Clock out ports
			CLK_OUT1 => CLK57M);

	CKGEN2 : clk_17M
		port map
		(	-- Clock in ports
			CLK_IN1 => CLKTMP1,
			-- Clock out ports
			CLK_OUT1 => CLKTMP2);

	CKGEN3 : clk_86M
		port map
		(	-- Clock in ports
			CLK_IN1 => CLKTMP2,
			-- Clock out ports
			CLK_OUT1 => CLK86M);

	RAM0 : usram
		PORT MAP (
			clka => CLK57M,
			wea => WEA,
			addra => ICTR(11 downto 2),
			dina => BUFI,
			clkb => CLK100M,
			addrb => OCTR(11 downto 2),
			doutb => BUFO
		);

	RAM1 : ceram
		PORT MAP (
			clka => CLK57M,
			wea => WEP,
			addra => PADR,
			dina => RGBS,
			clkb => not FT_CLK,
			addrb => BCTR,
			doutb => RGBX
		);

	RAM2 : ceram
		PORT MAP (
			clka => CLK86M,
			wea => WEP4,
			addra => PADR4,
			dina => RGBS4,
			clkb => not FT_CLK,
			addrb => BCTR,
			doutb => RGBX4
		);

	FIFO0 : kfifo
		PORT MAP (
			clk => FT_CLK,
			din => KFIN,
			wr_en => KWEN,
			rd_en => KREN,
			dout => KFOUT,
			full => KFULL,
			empty => KEMPTY
		);

	--
	-- External Signals
	--
	RI<=not xRI;
	GI<=not xGI;
	BI<=not xBI;
	VSI<=not xVSI;
	HSI<=not xHSI;
	VSO<=VSI;
	HSO<=HS when FMODE='1' else HSI;
	RO<=RB when FMODE='1' else RI;
	GO<=GB when FMODE='1' else GI;
	BO<=BB when FMODE='1' else BI;

	MSDT<=MSSDT(0);

	FT_SIWU_x<='1';

	LED(0)<=not FMODE;
	LED(1)<=not BMODE;
	-- Test Pin Location
	--  (3) (2)
	--  (1) (0)
	TST(3)<='0';
	TST(2)<='0';
	TST(1)<='0';
	TST(0)<='0';

	--
	-- Internal Signals
	--
	BUFI<='0'&GI&RI&BI;
	RB<='0' when HBLANK='1' else BUFO(1);
	GB<='0' when HBLANK='1' else BUFO(2);
	BB<='0' when HBLANK='1' else BUFO(0);
	RX<='0'&RGBX(20 downto 14) when FMODE='1' else '0'&RGBX4(20 downto 14);
	GX<='0'&RGBX(13 downto 7) when FMODE='1' else '0'&RGBX4(13 downto 7);
	BX<='0'&RGBX(6 downto 0) when FMODE='1' else '0'&RGBX4(6 downto 0);
	RGBS<=RS&GS&BS;
	RGBS4<=RS4&GS4&BS4;

	--
	-- Input Control (200 lines)
	--
	process( CLK57M ) begin
		if CLK57M'event and CLK57M='1' then

			-- Filtering HSI
			Si0<=Si0(4 downto 0)&HSI;

			-- Detect HSI's falling edge and start Counter
			if Si0="111000" then
				ICTR<="111011100000";	--EE0 (3B8*4)
				PCTR<=(others=>'0');
				PADR<=(others=>'0');
				OFSTX<=D_BGN2;
			else
				ICTR<=ICTR+'1';
			end if;

			-- Write Enable for Scan Convert Memory
			if ICTR(1 downto 0)="00" then
				WEA<="1";
				-- Shift in from RGB
				RS<=RI&RS(6 downto 1);
				GS<=GI&GS(6 downto 1);
				BS<=BI&BS(6 downto 1);
			else
				WEA<="0";
			end if;

			-- Count up Address Pointer for Transfer Memory
			if ICTR(1 downto 0)="01" then
				if OFSTX="00000000" then
					if PCTR="110" then	-- every 7 dots
						PCTR<=(others=>'0');
						PADR<=PADR+'1';
					else
						PCTR<=PCTR+'1';
					end if;
				else
					OFSTX<=OFSTX-'1';
				end if;
			end if;

			-- Write Enable for Console Emulator Memory
			if PCTR="000" and ICTR(1 downto 0)="00" then
				WEP<="1";
			else
				WEP<="0";
			end if;

		end if;
	end process;

	--
	-- Input Control (400 lines)
	--
	process( CLK86M ) begin
		if CLK86M'event and CLK86M='1' then

			-- Filtering HSI
			Si4<=Si4(4 downto 0)&HSI;

			-- Detect HSI's falling edge and start Counter
			if Si4="111000" then
				ICTR4<="00";
				PCTR4<=(others=>'0');
				PADR4<=(others=>'0');
				OFSTX4<=D_BGN4;
			else
				ICTR4<=ICTR4+'1';
			end if;

			-- Write Enable for Scan Convert Memory
			if ICTR4="01" then
				-- Shift in from RGB
				RS4<=RI&RS4(6 downto 1);
				GS4<=GI&GS4(6 downto 1);
				BS4<=BI&BS4(6 downto 1);
			end if;

			-- Count up Address Pointer for Transfer Memory
			if ICTR4="10" then
				if OFSTX4="00000000" then
					if PCTR4="110" then	-- every 7 dots
						PCTR4<=(others=>'0');
						PADR4<=PADR4+'1';
					else
						PCTR4<=PCTR4+'1';
					end if;
				else
					OFSTX4<=OFSTX4-'1';
				end if;
			end if;

			-- Write Enable for Console Emulator Memory
			if PCTR4="000" and ICTR4="00" then
				WEP4<="1";
			else
				WEP4<="0";
			end if;

		end if;
	end process;

	--
	-- Output Control for VGA
	--
	process( CLK100M ) begin
		if CLK100M'event and CLK100M='1' then

			-- Filtering HSI
			Hi<=Hi(4 downto 0)&HSI;

			-- Detect HSI's falling edge and start Counter
			if Hi="111000" then
				CCTR100<=(others=>'0');
				TS<=CCTR100(12 downto 1);	-- Estimate Half of 1 Line
				OCTR<=(others=>'0');
			elsif OCTR=TS then		-- Arrive at Half
				OCTR<=(others=>'0');
				CCTR100<=CCTR100+'1';
			else
				CCTR100<=CCTR100+'1';
				OCTR<=OCTR+'1';
			end if;

			-- Horizontal Sync generate
			if OCTR=0 then
				HS<='0';
			elsif OCTR=384 then
				HS<='1';
			end if;

			-- Horizontal Blanking Time counter
			if OCTR=0 then
				HBLANK<='1';
			elsif OCTR=494 then
				HBLANK<='0';
			elsif OCTR=3136 then
				HBLANK<='1';
			end if;

		end if;
	end process;

	--
	-- Output Control for FT232H
	--
	process( FT_CLK ) begin
		if FT_CLK'event and FT_CLK='1' then

			-- Filtering HSI/VSI
			Si2<=Si2(8 downto 0)&HSI;
			Si3<=Si3(8 downto 0)&VSI;

			-- Detect VSI's falling edge and reset Line number
			-- and Count up
			if Si3="1000000000" then
				LCTR<=(others=>'0');
				VCTR<=VCTR+'1';
				SLINE<=VCTR and MASK;
			end if;
			if Si2="1000000000" then
				LCTR<=LCTR+'1';
				if LCTR=L_BGN then
					SEN_L<=BMODE;
				end if;
				if LCTR=L_END then
					SEN_L<='0';
				end if;
				if (LCTR(2 downto 0) and MASK)=SLINE then
					SEN_F<=BMODE;
				else
					SEN_F<='0';
				end if;
			end if;

			LNUM_R<=LCTR-L_BGN-1;

			if Si2="0111111111" then
				SSTART<=BMODE;
			end if;
			if CUR=WAIT_TXE then
				SSTART<='0';
			end if;

			-- Read Address Counter
			if CUR=WRIT_LNH then
				if FMODE='1' then
					BCTR<="00011001";
				else
					BCTR<="00010011";
				end if;
			end if;
			if CUR=WRIT_G and FT_TXE_x='0' then
				BCTR<=BCTR+'1';
			end if;

			-- 250us Counter
			if KCTR=14999 then
				KCTR<=(others=>'0');
				CUR2<=NXT2;
				if CUR2=SEND_KDT_L then
					KSDT<=KSDT(15 downto 0)&'0';
					KBIT<=KBIT+'1';
				end if;
				if CUR2=WAIT_KST then
					KBIT<=(others=>'0');
				end if;
				if CUR2=CLER_KST then
					KST<='0';
				end if;
			else
				KCTR<=KCTR+'1';
			end if;

			-- 200us Counter
			if MCTR=11999 then
				MCTR<=(others=>'0');
				Si5<=Si5(0)&REQ;
				if Si5="01" then
					MSSDT<=(not YCTR(7))&YCTR(6 downto 0)&"01"&(not XCTR(7))&XCTR(6 downto 0)&"01"&YUDF&YOVF&XUDF&XOVF&"00"&RBTN&LBTN&'0';
					XCTR<="10000000";
					YCTR<="10000000";
					XOVF<='0';
					XUDF<='0';
					YOVF<='0';
					YUDF<='0';
				else
					MSSDT<='1'&MSSDT(28 downto 1);
				end if;
			else
				MCTR<=MCTR+'1';
			end if;

			-- for Keyboad FIFO
			if KEMPTY='0' and KST='0' and KREN='0' then
				KREN<='1';
			elsif KEMPTY='0' and KST='0' and KREN='1' then
				KSDT<='0'&KFOUT;
				KST<='1';
				KREN<='0';
			end if;

			-- Recieve Data
			if CUR=WAIT_HS then
				RHDR<=(others=>'0');
				KWEN<='0';
			end if;
			if CUR=READ_HDR then
				RHDR<=FT_DT;
			end if;
			if CUR=READ_DT0 then
				if RHDR=X"C0" then
					BMODE<=FT_DT(7);
					MASK<=FT_DT(2 downto 0);
				end if;
				if RHDR=X"C1" then
					D_BGN2<=FT_DT;
				end if;
				if RHDR=X"C2" then
					D_BGN4<=FT_DT;
				end if;
				if RHDR=X"C8" then
					KFIN(15 downto 8)<=FT_DT;
				end if;
				if RHDR=X"C9" then
					LBTN<=FT_DT(0);
					RBTN<=FT_DT(1);
					OP_Y<=FT_DT(6);
					OP_X<=FT_DT(7);
				end if;
			end if;
			if CUR=READ_DT1 then
				if RHDR=X"C1" then
					L_BGN2<="000000"&FT_DT;
					L_END2<=("000000"&FT_DT)+200;
				end if;
				if RHDR=X"C2" then
					L_BGN4<="000000"&FT_DT;
					L_END4<=("000000"&FT_DT)+400;
				end if;
				if RHDR=X"C8" then
					KFIN(7 downto 0)<=FT_DT;
					if KFULL='0' then
						KWEN<='1';
					end if;
				end if;
				if RHDR=X"C9" then
					RDT1<=FT_DT;
				end if;
			end if;
			if CUR=READ_DT2 then
				KWEN<='0';
				if RHDR=X"C9" then
					if OP_X='0' then
						XOVF<=ADDX(8);
						XCTR<=ADDX(7 downto 0);
					else
						XUDF<=SUBX(8);
						XCTR<=SUBX(7 downto 0);
					end if;
					if OP_Y='0' then
						YOVF<=ADDY(8);
						YCTR<=ADDY(7 downto 0);
					else
						YUDF<=SUBY(8);
						YCTR<=SUBY(7 downto 0);
					end if;
				end if;
			end if;

			-- State Movement
			CUR<=NXT;

		end if;
	end process;

	LNUM<=LNUM_R(12 downto 0)&'1' when FMODE='1' else LNUM_R;
	FTR<=X"80" when FMODE='1' else X"88";
	L_BGN<=L_BGN2 when FMODE='1' else L_BGN4;
	L_END<=L_END2 when FMODE='1' else L_END4;
	ADDX<=('0'&XCTR)+RDT1;
	SUBX<=('0'&XCTR)-RDT1;
	ADDY<=('0'&YCTR)+FT_DT;
	SUBY<=('0'&YCTR)-FT_DT;

	-- State Machine for USB
	process( CUR, Si2, LCTR(2 downto 0), BMODE, SSTART, SEN_L, SEN_F, FT_TXE_x, BCTR, FT_RXF_x ) begin
		case CUR is
			when WAIT_HS =>
				if BMODE='0' then
					NXT<=WAIT_RXF;
				elsif SSTART='1' and SEN_L='1' and SEN_F='1' then
					NXT<=WAIT_TXE;
				else
					NXT<=WAIT_HS;
				end if;
			when WAIT_TXE =>
				if FT_TXE_x='0' then
					NXT<=WRIT_LNH;
				else
					NXT<=WAIT_TXE;
				end if;
			when WRIT_LNH =>
				if FT_TXE_x='1' then
					NXT<=WRIT_LNH;
				else
					NXT<=WRIT_LNL;
				end if;
			when WRIT_LNL =>
				if FT_TXE_x='1' then
					NXT<=WRIT_LNL;
				else
					NXT<=WRIT_R;
				end if;
			when WRIT_R =>
				if FT_TXE_x='1' then
					NXT<=WRIT_R;
				else
					NXT<=WRIT_G;
				end if;
			when WRIT_G =>
				if FT_TXE_x='1' then
					NXT<=WRIT_G;
				else
					NXT<=WRIT_B;
				end if;
			when WRIT_B =>
				if FT_TXE_x='1' then
					NXT<=WRIT_B;
				elsif BCTR=118 then
					NXT<=WRIT_FTR;
				else
					NXT<=WRIT_R;
				end if;
			when WRIT_FTR =>
				if FT_TXE_x='1' then
					NXT<=WRIT_FTR;
				else
					NXT<=WAIT_RXF;
				end if;
			when WAIT_RXF =>
				if FT_RXF_x='1' then
					NXT<=WAIT_HS;
				else
					NXT<=SEND_OE;
				end if;
			when SEND_OE =>
				NXT<=READ_HDR;
			when READ_HDR =>
				NXT<=READ_DT0;
			when READ_DT0 =>
				NXT<=READ_DT1;
			when READ_DT1 =>
				NXT<=READ_DT2;
			when READ_DT2 =>
				NXT<=WAIT_HS;
			when others =>
				NXT<=WAIT_HS;
		end case;
	end process;

	process( CUR, LNUM, RX, GX, BX, FTR ) begin
		case CUR is
			when WRIT_LNH =>
				FT_DT<='0'&LNUM(13 downto 7);
				FT_WR_x<='0';
				FT_RD_x<='1';
				FT_OE_x<='1';
			when WRIT_LNL =>
				FT_DT<='0'&LNUM(6 downto 0);
				FT_WR_x<='0';
				FT_RD_x<='1';
				FT_OE_x<='1';
			when WRIT_R =>
				FT_DT<=RX;
				FT_WR_x<='0';
				FT_RD_x<='1';
				FT_OE_x<='1';
			when WRIT_G =>
				FT_DT<=GX;
				FT_WR_x<='0';
				FT_RD_x<='1';
				FT_OE_x<='1';
			when WRIT_B =>
				FT_DT<=BX;
				FT_WR_x<='0';
				FT_RD_x<='1';
				FT_OE_x<='1';
			when WRIT_FTR =>
				FT_DT<=FTR;
				FT_WR_x<='0';
				FT_RD_x<='1';
				FT_OE_x<='1';
			when SEND_SI =>
				FT_DT<="ZZZZZZZZ";
				FT_WR_x<='1';
				FT_RD_x<='1';
				FT_OE_x<='1';
			when SEND_OE =>
				FT_DT<="ZZZZZZZZ";
				FT_WR_x<='1';
				FT_RD_x<='1';
				FT_OE_x<='0';
			when READ_HDR|READ_DT0|READ_DT1|READ_DT2 =>
				FT_DT<="ZZZZZZZZ";
				FT_WR_x<='1';
				FT_RD_x<='0';
				FT_OE_x<='0';
			when others =>
				FT_DT<="ZZZZZZZZ";
				FT_WR_x<='1';
				FT_RD_x<='1';
				FT_OE_x<='1';
		end case;
	end process;

	-- State Machine for Keyboard
	process( CUR2, KST, KBIT, KSDT(16) ) begin
		case CUR2 is
			when WAIT_KST =>
				if KST='1' then
					NXT2<=SEND_KHD_L1;
				else
					NXT2<=WAIT_KST;
				end if;
			when SEND_KHD_L1 =>
				NXT2<=SEND_KHD_L2;
			when SEND_KHD_L2 =>
				NXT2<=SEND_KHD_L3;
			when SEND_KHD_L3 =>
				NXT2<=SEND_KHD_L4;
			when SEND_KHD_L4 =>
				NXT2<=SEND_KDT_H1;
			when SEND_KDT_H1 =>
				NXT2<=SEND_KDT_H2;
			when SEND_KDT_H2 =>
				NXT2<=SEND_KDT_H3;
			when SEND_KDT_H3 =>
				if KSDT(16)='0' then
					NXT2<=SEND_KDT_L;
				else
					NXT2<=SEND_KDT_H4;
				end if;
			when SEND_KDT_H4 =>
				NXT2<=SEND_KDT_H5;
			when SEND_KDT_H5 =>
				NXT2<=SEND_KDT_H6;
			when SEND_KDT_H6 =>
				NXT2<=SEND_KDT_H7;
			when SEND_KDT_H7 =>
				NXT2<=SEND_KDT_L;
			when SEND_KDT_L =>
				if KBIT=16 then
					NXT2<=CLER_KST;
				else
					NXT2<=SEND_KDT_H1;
				end if;
			when CLER_KST =>
				NXT2<=WAIT_KST;
			when others =>
				NXT2<=WAIT_KST;
		end case;
	end process;

	process( CUR2 ) begin
		case CUR2 is
			when SEND_KHD_L1|SEND_KHD_L2|SEND_KHD_L3|SEND_KHD_L4|SEND_KDT_L =>
				KBDT<='0';
			when others =>
				KBDT<='1';
		end case;
	end process;

	--
	-- Detect Display Frequency
	--
	process( CLK100M ) begin
		if CLK100M'event and CLK100M='1' then

			-- Filtering VSI
			Si1<=Si1(4 downto 0)&VSI;

			-- Pick up Flag and Clear
			if Si1="111000" then
				FMODE<=FFLG;
			elsif Si1="000111" then
				FFLG<='0';
			end if;

			-- Counter
			if Si0="111000" then		-- HSI
				FCTR<=(others=>'0');
			else
				FCTR<=FCTR+'1';
			end if;

			if FCTR="1001110001000" then	-- 50us
				FFLG<='1';
			end if;

		end if;
	end process;

--	process( CLK25M ) begin
--		if CLK25M'event and CLK25M='1' then
--			if TMPC=25000000 then
--				L<=not L;
--				TMPC<=0;
--			else
--				TMPC<=TMPC+1;
--			end if;
--		end if;
--	end process;

end Behavioral;

