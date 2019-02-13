//============================================================================
//  Sprint2 port to MiSTer
//  Copyright (c) 2019 Alan Steremberg - alanswx
//
//   
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [44:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] VIDEO_ARX,
	output  [7:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S, // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)
	input         TAPE_IN,

	// SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR
);

//`define SOUND_DBG
assign VGA_SL=0;

assign VGA_F1=0;
assign CE_PIXEL=1;

assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;

//assign VIDEO_ARX = status[9] ? 8'd16 : 8'd4;
//assign VIDEO_ARY = status[9] ? 8'd9  : 8'd3;


assign VIDEO_ARX = 4;
assign VIDEO_ARY = 3;

assign AUDIO_S = 0;
assign AUDIO_MIX = 0;

assign LED_DISK  = lamp1;
assign LED_POWER = lamp2;
assign LED_USER  = ioctl_download;

`include "build_id.v"
localparam CONF_STR = {
	"A.DOMINOS;;",
	"-;",
	"O12,Points to Win,3,4,5,6;",
	"O7,Test,Off,On;",
	"-;",
	"T6,Reset;",
	"J,Start,Start 1P,Start 2P;",
	"V,v",`BUILD_DATE
};


wire [31:0] status;
wire  [1:0] buttons;
wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [7:0] ioctl_data;

wire        forced_scandoubler;
wire [10:0] ps2_key;
//wire [24:0] ps2_mouse;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy0 =  joystick_0;
wire [15:0] joy1 =  joystick_1;


hps_io #(.STRLEN(($size(CONF_STR)>>3) )/*, .PS2DIV(1000), .WIDE(0)*/) hps_io
(
	.clk_sys(CLK_VIDEO/*clk_sys*/),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),
	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.buttons(buttons),
	.forced_scandoubler(forced_scandoubler),
	.new_vmode(new_vmode),

	.status(status),
	.status_in({status[31:8],region_req,status[5:0]}),
	.status_set(region_set),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),
	
	.ps2_key(ps2_key)
);



wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];
	
	if(old_state != ps2_key[10]) begin
		casex(code)
			'hX75: btn_up          <= pressed; // up
			'hX72: btn_down        <= pressed; // down
			'hX6B: btn_left        <= pressed; // left
			'hX74: btn_right       <= pressed; // right
			'h029: btn_coin1         <= pressed; // space
			'h014: btn_coin2         <= pressed; // ctrl

			'h005: btn_one_player  <= pressed; // F1
			'h006: btn_two_players <= pressed; // F2
		endcase
	end
end

reg btn_coin1 = 0;
reg btn_coin2 = 0;
reg btn_up    = 0;
reg btn_down  = 0;
reg btn_right = 0;
reg btn_left  = 0;
reg btn_one_player  = 0;
reg btn_two_players = 0;

wire m_left1			=  btn_left  | joy0[1];
wire m_right1		=  btn_right | joy0[0];
wire m_up1			=  btn_up  | joy0[3];
wire m_down1		=  btn_down | joy0[2];

wire m_left2   	=	joy1[1];
wire m_right2  	=  joy1[0];
wire m_up2   	=	joy1[3];
wire m_down2  	=  joy1[2];

wire m_coin1 = btn_coin1 | joy0[4];
wire m_coin2 = btn_coin2 | joy1[4];
wire m_start1 = btn_one_player  | joy0[5] | joy1[5];
wire m_start2 = btn_two_players | joy0[6] | joy1[6];
wire m_coin   = m_start1 | m_start2;



/*
-- Configuration DIP switches, these can be brought out to external switches if desired
-- See dominos 2 manual page 11 for complete information. Active low (0 = On, 1 = Off)
--    1 	2							Points to win		(00 - 3, 01 - 4, 10 - 5, 11 - 6)
--   			3	4					Game Cost		(10 - 1 Coin per player) 
--					5	6	7	8	Unused				

SW1 <= SW1_I; -- "1010"; -- Config dip switches 1-4


*/

wire [3:0] SW1 = {status[2:1],1'b1,1'b0};



wire videowht,videoblk,compositesync,lamp;


dominos dominos(
	.Clk_50_I(CLK_50M),
	.Reset_I(~(RESET | status[0] | status[6] | buttons[1] | ioctl_download)),

	.dn_addr(ioctl_addr[16:0]),
	.dn_data(ioctl_data),
	.dn_wr(ioctl_wr),

	.VideoW_O(videowht),
	.VideoB_O(videoblk),

	.Sync_O(compositesync),
	.Audio_O(audio1),
	//.Audio2_O(audio2),
	/*
	.Coin1_I(~m_coin1),
	.Coin2_I(~m_coin2),
	.Start1_I(~m_start1),
	.Start2_I(~m_start2),
	*/
	.Coin1_I(~m_start1),
	.Coin2_I(~m_start2),
	.Start1_I(~m_coin1),
	.Start2_I(~m_coin2),

	.Up1(~m_up1),
	.Down1(~m_down1),
	.Left1(~m_left1),
	.Right1(~m_right1),	
	
	.Up2(~m_up2),
	.Down2(~m_down2),
	.Left2(~m_left2),
	.Right2(~m_right2),
	
	.Test_I	(~status[7]),
	.Lamp1_O(lamp1),
	.Lamp2_O(lamp2),
	.hs_O(hs),
	.vs_O(vs),
	.hblank_O(hblank),
	.vblank_O(vblank),
	.clk_12(clk_12),
	.clk_6_O(CLK_VIDEO_2),
	.SW1_I(SW1)
	);
			
wire [6:0] audio1;
wire [6:0] audio2;
wire [1:0] video;
wire [3:0] videor;
///////////////////////////////////////////////////
//wire clk_sys, clk_ram, clk_ram2, clk_pixel, locked;
wire clk_sys,locked;
wire clk_12,CLK_VIDEO_2;
wire hs,vs,hblank,vblank;
assign VGA_HS=hs;
assign VGA_VS=vs;
assign VGA_HS=hs;
reg [7:0] vid_mono;
wire[1:0] sprint_vid;

//assign sprint_vid = {videowht,videoblk};
always @(posedge clk_sys) begin
		casex({videowht,videoblk})
			2'b01: vid_mono<=8'b01010000;
			2'b10: vid_mono<=8'b10000110;
			2'b11: vid_mono<=8'b11111111;
			2'b00: vid_mono<=8'b00000000;
		endcase
end

assign VGA_R=vid_mono;
assign VGA_G=vid_mono;
assign VGA_B=vid_mono;
/*
assign VGA_R={videowht,videoblk,videowht,videoblk,videowht,videoblk,videowht,videoblk};
assign VGA_G={videowht,videoblk,videowht,videoblk,videowht,videoblk,videowht,videoblk};
assign VGA_B={videowht,videoblk,videowht,videoblk,videowht,videoblk,videowht,videoblk};
*/
assign VGA_DE=~(vblank | hblank);
assign AUDIO_L={audio1,1'b0,8'b00000000};
assign AUDIO_R=AUDIO_L;
assign CLK_VIDEO=CLK_VIDEO_2;

//assign SDRAM_CLK=ram_clock;
pll pll (
	 .refclk ( CLK_50M   ),
	 .rst(0),
	 .locked 		( locked    ),        // PLL is running stable
	 .outclk_0		( clk_sys	),
	 .outclk_1		( clk_12		)        // 12 MHz
	 );

endmodule
