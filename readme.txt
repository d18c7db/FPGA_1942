This is an FPGA implementation of the arcade game "1942" based on the Capcom schematic ciruit diagram.

Known Errors:
	This current release is about 99% functional, the only known problem is in the sprites section
	where some of the longer sprites (32 and 64 pixels long) are not displayed properly. At this point
	in time I have stared at the circuit diagram and waveforms in the simulator window for several days
	straight and I need to take a long break from this before I lose my mind.
	I may come back in the future and attempt to fix the sprites.
	
	There are errors or omissions in the schematic that may well contribute to this problem. For example
	in page 6/8 of the video schematic the ROMs L1, L2, N1, N2 don't have an A13 address line listed but
	the reality is that A13 is in fact connected to signal VOVER on previous page. This is just one example
	of errors in the schematic. I have also had to deviate from the schematic in one place to even have
	the sprites display at all, this is also on page 6/8 of the video in the creation of the VINZONE
	signal by the comparators L5, M5 where I had to elliminate gates N4 and M4 and simply feed the signal
	A>B inverted to gate N5. The explanation for this is quite complex but if you kind reader want to try
	your hand at fixing the sprites, that is a good starting point. The signal VINZONE is gated by OH into
	N11 and controls the chip enable of the K3 PROM. Essentially when this signal is active the PROM is
	allowed to output sprites, or else no sprites are displayed. This chip enable to the K3 PROM not only
	has to be active but it also has to be active at just the right time and disabled the rest of the time.

Description
	The schematic consists of a total of 16 pages, the fist 8 pages cover the main processor, audio board
	and character generation board 84100-01A while the last 8 pages cover the scroll generation, object
	generation and video mixing board 84100-02A. On the real arcade these are separate boards connected to
	each other via ribbon cables.
	
	The project has been split into functional modules which roughly correspond to the relevant schematic pages.
	* FPGA_1942.vhd is the arcade game top level module is which connects all the modules together.
	* CPUA_IO.vhd implements the main CPU, ROM, RAM and user I/O on pages 1 and 2 of 84100-01A
	* CPUB_PSG.vhd implements the audio CPU, ROM, RAM and PSG (programmable sound generators) page 3 and 4 of 84100-01A
	* SYNC.vhd implements the synchronization signal generation on page 5 of 84100-01A
	* CHR_GEN.vhd implements the character generation pages 6,7,8 of 84100-01A (this is video related but on main board)
	* SCR_GEN.vhd implements scroll (background generation) pages 1,2,3 of 84100-02A
	* VIDEO_MIX.vhd implements the video mixer on page 4 of 84100-02A
	* OBJ_GEN.vhd implements the object (sprite) generator on pages 5,6 of 84100-02A
	* OBJ_LINE_BUF.vhd implements the sprite line buffer on page 7,8 of 84100-02A
	
	For debugging in the simulator, each section can be easily debugged by commenting out unneccessary modules,
	for example if we want to debug the video sections we can do the following:
	
	To debug the background (SCR):
		in FPGA_1942.vhd comment out the modules CPUA_IO, CPUB_PSG, CHAR_GEN, OBJ_GEN, OBJ_LINE_BUF
		in SCR_GEN.vhd comment out the RAM_A9 block and uncomment the ROM_A9 block below it.
	To debug the text (CHR)
		in FPGA_1942.vhd comment out the modules CPUA_IO, CPUB_PSG, SCR_GEN, OBJ_GEN, OBJ_LINE_BUF
		in CHR_GEN.vhd comment out the RAM_D2 block and uncomment the ROM_D2 block below it.
	To debug the sprites (OBJ)
		in FPGA_1942.vhd comment out the modules CPUA_IO, CPUB_PSG, CHAR_GEN, SCR_GEN
		in OBJ_GEN.vhd comment out the RAM_H9_H10 block and uncomment the ROM_H9_H10 block below it.
	
	After making the above relevant changes run the testbench in the simulator for 20ms. At the end of the simulation
	in the "screens" folder the first frame of the video will be saved as a .ppm file (portable pixmap) which can be
	viewed with a suitable graphics viewer.
	
	ROM_A9, ROM_D2 and ROM_H9_H10 have been prepared with suitable contents to simulate what the respective RAMs would
	have been loaded with by the CPU had we not commented it out. This way we only have to simulate the video circuitry
	for a short 20ms while it writes the first video frame out, otherwise if we left all the game modules in, we would
	have to simulate several seconds while the CPU wastes precious simulation time erasing whole RAM sections and
	performing initialisation and other various tasks before it even writes anything useful to the screen.

Hardware
	This has been implemeted on a custom FPGA board called the Pipistrello based on a Spartan LX45 and designed by
	Saanlima.com (discontinued) but it should work on any FPGA able to fit the design and all the game ROMs.
	There are options for a PS2 keyboard or a Nintendo Nunchack to be used as game controllers
	In addition to analog VGA output there is an option to output digital DVID direct to your monitor.
