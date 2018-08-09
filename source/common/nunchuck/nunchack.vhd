----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    20:01:02 10/10/2017 
-- Design Name: 
-- Module Name:    inst_nunchack - Behavioral 
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
use ieee.std_logic_unsigned.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity nunchack is
	port (
		sys_clk		: in std_logic;
		i2c_reset	: in std_logic;
		i2c_error	: buffer std_logic;
		i2c_sck		: inout std_logic;
		i2c_sda		: inout std_logic;
		but_c			: out std_logic;		-- button C positive logic (1 pressed, 0 released)
		but_z			: out std_logic;		-- button Z positive logic (1 pressed, 0 released)
		acc_x			: out std_logic_vector( 9 downto 0);	-- accelerometer Z
		acc_y			: out std_logic_vector( 9 downto 0);	-- accelerometer Y
		acc_z			: out std_logic_vector( 9 downto 0);	-- accelerometer Z
		joy_x			: out std_logic_vector( 7 downto 0);	-- joystick X
		joy_y			: out std_logic_vector( 7 downto 0)		-- joystick Y
	);
end nunchack;

architecture behavioral of nunchack is
	signal i2c_rw			: std_logic := '1';
	signal i2c_en			: std_logic := '1';
	signal i2c_busy		: std_logic := '1';
	signal i2c_busy_fall	: std_logic := '1';
	signal i2c_busy_rise	: std_logic := '1';
	signal i2c_busy_last	: std_logic := '1';
	signal i2c_local_rst	: std_logic := '1';
	signal i2c_di			: std_logic_vector( 7 downto 0) := (others => '0');
	signal i2c_do			: std_logic_vector( 7 downto 0) := (others => '0');
	signal delay			: integer range 0 to 128000;

	signal jx				: std_logic_vector( 7 downto 0) := (others => '0');
	signal jy				: std_logic_vector( 7 downto 0) := (others => '0');
	signal ax				: std_logic_vector( 7 downto 0) := (others => '0');
	signal ay				: std_logic_vector( 7 downto 0) := (others => '0');
	signal az				: std_logic_vector( 7 downto 0) := (others => '0');
	signal re				: std_logic_vector( 7 downto 0) := (others => '0');

	type machine is (reset, init0, init1, init2, init3, init4, init5, setup0, setup00, setup1, setup2, read0, read1, read11, read2, read3, read4, read5, read6, retval, stop);	-- states
	signal state		: machine;

begin
	inst_i2c_master: entity work.i2c_master
	generic map (input_clk=>4000000, bus_clk=>80000)
	port map(
		clk       => sys_clk,			-- system clock
		reset_n   => i2c_local_rst,	-- active low reset
		ena       => i2c_en,				-- latch in command
		addr      => "1010010",			-- address of target slave
		rw        => i2c_rw,		-- '0' is write, '1' is read
		data_wr   => i2c_di,		-- data to write to slave

		busy      => i2c_busy,	-- indicates transaction in progress
		data_rd   => i2c_do,		-- data read from slave
		ack_error => i2c_error,	-- flag if improper acknowledge from slave
		sda       => i2c_sda,	-- serial  data inout of i2c bus
		scl       => i2c_sck		-- serial clock inout of i2c bus
   );

	-- 
	process(sys_clk)
	begin
		if (rising_edge(sys_clk)) then
			i2c_busy_last <= i2c_busy;
			if (i2c_busy_last = '1' and i2c_busy = '0') then
				i2c_busy_fall <= '1';
			else
				i2c_busy_fall <= '0';
			end if;

			if (i2c_busy_last = '0' and i2c_busy = '1') then
				i2c_busy_rise <= '1';
			else
				i2c_busy_rise <= '0';
			end if;

		end if;
	end process;

-- WII protocol

--	1. Initialize the Nunchuk:
--	START 0xA4 ACK 0x40 ACK 0x00 ACK STOP
--	This sequence is the normal initialization sequence, which sets the
--	encryption algorithm to default. Every byte which is read from the
--	Nunchuk must then be decrypted with (x ^ 0x17) + 0x17
--	A better way is disabling encryption with this sequence:
--
--	2. Initialize the Nunchuk without encryption:
--	START 0xA4 ACK 0xF0 ACK 0x55 ACK STOP
--	START 0xA4 ACK 0xFB ACK 0x00 ACK STOP
--	This has the benefit that the actual data can be used without the
--	decryption formula and it will work with Nunchuk-clones as well.
--
--	3. Read the device ident from extension register:
--	START 0xA5 ACK 0xFA ACK b0 ACK b1 ACK b2 ACK b3 ACK b4 ACK b5 NACK STOP
--	At address 0xFA you can find the ident number of the device, which is
--	0xA4200000 for Nunchuck
--	0xA4200101 for Classic Controller
--	0xA4200402 for Balance and so on
--
--	4. Read measurements from the device:
--	START 0xA5 ACK 0x00 ACK b0 ACK b1 ACK b2 ACK b3 ACK b4 ACK b5 NACK STOP
--	What you get in return is described in this overview:
--
--	Byte	Bit 7 6 5 4 3 2 1 0
--	1		Joystick X-Axis [7:0]
--	2		Joystick Y-Axis [7:0]
--	3		Accelerometer X-Axis [9:2]
--	4		Accelerometer Y-Axis [9:2]
--	5		Accelerometer Z-Axis [9:2]
--	6		Az [1:0] Ay [1:0] Ax [1:0] Bc Bz

	process(sys_clk, i2c_reset)
	begin
		if (i2c_reset = '1') then
			state <= reset;
		elsif (rising_edge(sys_clk)) then
			case state is
				when reset =>
					delay <= 0;
					i2c_local_rst <= '0';
					i2c_en <= '0';	-- disable
					i2c_rw <= '1';	-- read
					i2c_di <= x"00";
					state <= init0;
				-- send F0 55
				when init0 =>
					i2c_local_rst <= '1';
					i2c_di <= x"F0";
					i2c_rw <= '0';		-- write
					if (i2c_busy_fall = '1') then
						state <= init1;
					end if;
				when init1 =>
					i2c_en <= '1';		-- enable
					if (i2c_busy_rise = '1') then
						i2c_di <= x"55";
						state <= init2;
					end if;
				when init2 =>
					if (i2c_busy_fall = '1') then
						i2c_en <= '0';		-- disable
						state <= init3;
					end if;

				-- send FB 00
				when init3 =>
					i2c_di <= x"FB";
					i2c_rw <= '0';		-- write
					if (i2c_busy_fall = '1') then
						state <= init4;
					end if;
				when init4 =>
					i2c_en <= '1';		-- enable
					if (i2c_busy_rise = '1') then
						i2c_di <= x"00";
						state <= init5;
					end if;
				when init5 =>
					if (i2c_busy_fall = '1') then
						i2c_en <= '0';		-- disable
						state <= setup0;
					end if;

				-- send 00
				when setup0 =>
					if (i2c_busy_fall = '1') then
						state <= setup00;
					end if;

				when setup00 =>
					if delay < 4000 then
						delay <= delay + 1;
					else
						delay <=0;
						i2c_di <= x"00";
						i2c_en <= '1';		-- enable
						i2c_rw <= '0';		-- write
						state <= setup1;
					end if;

				when setup1 =>
					if (i2c_busy_rise = '1') then
						i2c_en <= '0';		-- disable
						state <= read0;
					end if;
				-- send 00, read 6 bytes
				when read0 =>
					if (i2c_busy_fall = '1') then
						if i2c_error = '1' then
							i2c_di <= x"00";
							i2c_en <= '1';		-- enable
							i2c_rw <= '0';		-- write
							state <= setup1;
						else
--							i2c_di <= x"ff";
--							i2c_en <= '1';		-- enable
--							i2c_rw <= '1';		-- read
							state <= read11;
						end if;
					end if;
				when read11 =>
					if delay < 4000 then
						delay <= delay + 1;
					else
						delay <=0;
						i2c_di <= x"ff";
						i2c_en <= '1';		-- enable
						i2c_rw <= '1';		-- read
						state <= read1;
					end if;
				when read1 =>
					if (i2c_busy_fall = '1') then
						jx <= i2c_do;
						state <= read2;
					end if;
				when read2 =>
					if (i2c_busy_fall = '1') then
						jy <= i2c_do;
						state <= read3;
					end if;
				when read3 =>
					if (i2c_busy_fall = '1') then
						ax <= i2c_do;
						state <= read4;
					end if;
				when read4 =>
					if (i2c_busy_fall = '1') then
						ay <= i2c_do;
						state <= read5;
					end if;
				when read5 =>
					if (i2c_busy_fall = '1') then
						az <= i2c_do;
						state <= read6;
					end if;
				when read6 =>
					if (i2c_busy_fall = '1') then
						re <= i2c_do;
						i2c_en <= '0';		-- disable
						state <= retval;
					end if;
				when retval =>
					but_c <= not re(1);
					but_z <= not re(0);

					joy_x <= jx;
					joy_y <= jy;

					acc_x(9 downto 2) <= ax;
					acc_x(1 downto 0) <= re(3 downto 2);

					acc_y(9 downto 2) <= ay;
					acc_y(1 downto 0) <= re(5 downto 4);

					acc_z(9 downto 2) <= az;
					acc_z(1 downto 0) <= re(7 downto 6);

					state <= setup0;
				when others => null;
			end case;
		end if;
	end process;
end behavioral;
