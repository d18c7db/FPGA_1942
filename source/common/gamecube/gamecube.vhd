--	(c) 2018 d18c7db(a)hotmail
--
--	This program is free software; you can redistribute it and/or modify it under
--	the terms of the GNU General Public License version 3 or, at your option,
--	any later version as published by the Free Software Foundation.
--
--	This program is distributed in the hope that it will be useful,
--	but WITHOUT ANY WARRANTY; without even the implied warranty of
--	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
--
-- For full details, see the GNU General Public License at www.gnu.org/licenses
----------------------------------------------------------------------------------
-- 1-wire bidirectional line, idle high
-- 0 bit = 3us low, 1us high
-- 1 bit = 1us low, 3us high
-- every sequence of bytes sent or received is followed by a 1 bit high idle
--	send 3 byte command x400302
-- receive 8 bytes as follows:
--	byte 0 : 0 0 0 Start Y    X      B       A
--	byte 1 : 1 L R Z     D-Up D-Down D-Right D-Left
--	byte 2 : Joy X
--	byte 3 : Joy Y
--	byte 4 : C-Stick X
--	byte 5 : C-Stick Y
--	byte 6 : Left Button
--	byte 7 : Right Button

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity gamecube is
	port (
		clk					: in std_logic;	-- 1MHz clock
		reset					: in std_logic;
		serio					: inout std_logic;

		but_S					: out std_logic;	-- button Start
		but_X					: out std_logic;	-- button X
		but_Y					: out std_logic;	-- button Y
		but_Z					: out std_logic;	-- button Z

		but_A					: out std_logic;	-- button A
		but_B					: out std_logic;	-- button B
		but_L					: out std_logic;	-- button Left
		but_R					: out std_logic;	-- button Right

		but_DU				: out std_logic;	-- button Dpad up
		but_DD				: out std_logic;	-- button Dpad down
		but_DL				: out std_logic;	-- button Dpad left
		but_DR				: out std_logic;	-- button Dpad right

		joy_X					: out std_logic_vector( 7 downto 0);	-- Joy X analog
		joy_Y					: out std_logic_vector( 7 downto 0);	-- Joy Y analog
		cst_X					: out std_logic_vector( 7 downto 0);	-- C-Stick X analog
		cst_Y					: out std_logic_vector( 7 downto 0);	-- C-Stick Y analog
		ana_L					: out std_logic_vector( 7 downto 0);	-- Left Button analog
		ana_R					: out std_logic_vector( 7 downto 0)		-- Right Button analog
	);
end gamecube;

architecture behavioral of gamecube is
	type machine is (
		send_lo_0, send_lo_1, send_lo_2, send_lo_3,
		send_hi_0, send_hi_1, send_hi_2, send_hi_3,
		recv_b0_0, recv_b0_1, recv_b0_2, recv_b0_3,
		init, cmd0
	);
	signal state			: machine;
	signal last_bit		: std_logic := '0';
	signal command			: std_logic_vector(23 downto 0) := x"400302";	--	3 byte command
	signal rx				: std_logic_vector( 7 downto 0) := (others=>'0');
	signal rx_bit			: integer range 0 to 15 := 0;
	signal rx_byte			: integer range 0 to 15 := 0;
	signal counter			: integer range 0 to 63 := 0;
begin
	process(clk, reset)
	begin
		if (reset = '1') then
			counter	<= 0;
			state		<= init;
			serio		<= 'Z';

			but_S		<= '0';
			but_X		<= '0';
			but_Y		<= '0';
			but_Z		<= '0';

			but_A		<= '0';
			but_B		<= '0';
			but_L		<= '0';
			but_R		<= '0';

			but_DU	<= '0';
			but_DD	<= '0';
			but_DL	<= '0';
			but_DR	<= '0';

			joy_X		<= (others=>'0');
			joy_Y		<= (others=>'0');
			cst_X		<= (others=>'0');
			cst_Y		<= (others=>'0');
			ana_L		<= (others=>'0');
			ana_R		<= (others=>'0');

		elsif (rising_edge(clk)) then
			case state is
				-------------------------------
				-- state machine initial state
				-------------------------------
				when init =>
					counter	<= 0;
					rx_bit	<= 0;
					rx_byte	<= 0;
					command	<= x"400302";
					serio		<= 'Z';
					state		<= cmd0;

				----------------
				-- send command
				----------------
				when cmd0 =>
					serio		<= '1';
					command	<= command(22 downto 0) & '1';
					counter	<= counter + 1;
					if counter = 25 then
						serio		<= 'Z';
						counter	<= 0;
						state		<= recv_b0_0;
					else
						if command(23) = '1' then
							state <= send_hi_0;
						else
							state <= send_lo_0;
						end if;
					end if;

				---------------------------
				-- send a high bit as _---
				---------------------------
				when send_hi_0 => serio <= '0';	state <= send_hi_1;
				when send_hi_1 =>	serio <= '1';	state <= send_hi_2;
				when send_hi_2 =>	serio <= '1';	state <= cmd0;

				--------------------------
				-- send a low bit as ___-
				--------------------------
				when send_lo_0 =>	serio <= '0';	state <= send_lo_1;
				when send_lo_1 =>	serio <= '0';	state <= send_lo_2;
				when send_lo_2 =>	serio <= '0';	state <= cmd0;

				------------------
				-- receive a byte
				------------------

				-- 1st quarter of bit must be 0
				when recv_b0_0 =>
					counter <= counter + 1;	-- timeout counter
					if serio = '0' then
						counter <= 0;
						state <= recv_b0_1;
					elsif counter = 63 then	-- if no bit received, restart state machine
						state <= init;
					elsif rx_byte = 8 then
						state	<= init;
					elsif rx_bit = 8 then
						rx_bit	<= 0;
						rx_byte	<= rx_byte + 1;
						rx			<= (others=>'0');
						case rx_byte is
							when 0 =>
								but_S		<= rx(4);
								but_Y		<= rx(3);
								but_X		<= rx(2);
								but_B		<= rx(1);
								but_A		<= rx(0);
							when 1 =>
								but_L		<= rx(6);
								but_R		<= rx(5);
								but_Z		<= rx(4);
								but_DU	<= rx(3);
								but_DD	<= rx(2);
								but_DR	<= rx(1);
								but_DL	<= rx(0);
							when 2 =>
								joy_X		<= rx;
							when 3 =>
								joy_Y		<= rx;
							when 4 =>
								cst_X		<= rx;
							when 5 =>
								cst_Y		<= rx;
							when 6 =>
								ana_L		<= rx;
							when 7 =>
								ana_R		<= rx;
							when others => null;
						end case;
					end if;

				-- 2nd quarter of bit is the value
				when recv_b0_1 =>
					last_bit	<= serio;
					state	<= recv_b0_2;
				-- 3rd quarter of bit must be same as 2nd
				when recv_b0_2 =>
					if last_bit = serio then
						state	<= recv_b0_3;
					else
						state	<= init;
					end if;
				-- 4th quarter of bit must be 1
				when recv_b0_3 =>
					if serio = '1' then
						rx			<= rx(6 downto 0) & last_bit;
						rx_bit	<= rx_bit + 1;
						state		<= recv_b0_0;
					else
						state <= init;
					end if;

				when others =>
					state <= init;
			end case;
		end if;
	end process;
end behavioral;
