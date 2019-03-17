//============================================================================
//  Dominos port to MiSTer
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
	output        VGA_CLK,

	//Multiple resolutions are supported using different VGA_CE rates.
	//Must be based on CLK_VIDEO
	output        VGA_CE,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)

	//Base video clock. Usually equals to CLK_SYS.
	output        HDMI_CLK,

	//Multiple resolutions are supported using different HDMI_CE rates.
	//Must be based on CLK_VIDEO
	output        HDMI_CE,

	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_DE,   // = ~(VBlank | HBlank)
	output  [1:0] HDMI_SL,   // scanlines fx

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] HDMI_ARX,
	output  [7:0] HDMI_ARY,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S    // 1 - signed audio samples, 0 - unsigned
);

assign LED_USER  = ioctl_download;
assign LED_DISK  = lamp2;
assign LED_POWER = lamp1;

assign HDMI_ARX = status[1] ? 8'd16 : 8'd4;
assign HDMI_ARY = status[1] ? 8'd9  : 8'd3;


`include "build_id.v"
localparam CONF_STR = {
	"A.DOMINOS;;",
	"-;",
	"O1,Aspect Ratio,Original,Wide;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",  
	"-;",
	"OAB,Points to Win,3,4,5,6;",
	"OD,Test,Off,On;",
	"-;",
	"R0,Reset;",
	"J1,Start,Start 1P,Start 2P;",
	"V,v",`BUILD_DATE
};


wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire [7:0] ioctl_data;

wire [10:0] ps2_key;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy0 =  joystick_0;
wire [15:0] joy1 =  joystick_1;


hps_io #(.STRLEN(($size(CONF_STR)>>3) )) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),
	
	.buttons(buttons),
	.status(status),
	.forced_scandoubler(forced_scandoubler),


	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_data),
	
	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
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
			'h029: btn_coin_1         <= pressed; // space
			'h014: btn_coin_2         <= pressed; // ctrl

			'h005: btn_one_player  <= pressed; // F1
			'h006: btn_two_players <= pressed; // F2
			// JPAC/IPAC/MAME Style Codes
			'h016: btn_start_1     <= pressed; // 1
			'h01E: btn_start_2     <= pressed; // 2
			'h02E: btn_coin_1      <= pressed; // 5
			'h036: btn_coin_2      <= pressed; // 6
		endcase
	end
end

reg btn_start_1=0;
reg btn_start_2=0;

reg btn_coin_1 = 0;
reg btn_coin_2 = 0;
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

wire m_coin1 = btn_coin_1 | joy0[4];
wire m_coin2 = btn_coin_2 | joy1[4];
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

wire [3:0] SW1 = {status[11:10],1'b1,1'b0};



wire videowht,videoblk,compositesync,lamp1,lamp2;


dominos dominos(
	.Clk_50_I(CLK_50M),
	.Reset_I(~(RESET | status[0] | buttons[1] | ioctl_download)),

	.dn_addr(ioctl_addr[16:0]),
	.dn_data(ioctl_data),
	.dn_wr(ioctl_wr),

	.VideoW_O(videowht),
	.VideoB_O(videoblk),

	.Sync_O(compositesync),
	.Audio_O(audio1),

	// ????
	.Coin1_I(~(m_start1|btn_start_1)),
	.Coin2_I(~(m_start2|btn_start_2)),
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
	
	.Test_I	(~status[13]),
	.Lamp1_O(lamp1),
	.Lamp2_O(lamp2),
	.hs_O(hs),
	.vs_O(vs),
	.hblank_O(hblank),
	.vblank_O(vblank),
	.clk_12(clk_12),
	.clk_6_O(clk_6),
	.SW1_I(SW1)
	);
			
wire [6:0] audio1;
wire [6:0] audio2;
wire [1:0] video;
///////////////////////////////////////////////////
wire clk_24,clk_12,clk_6;
wire clk_sys,locked;
reg [7:0] vid_mono;

always @(posedge clk_sys) begin
		casex({videowht,videoblk})
			2'b01: vid_mono<=8'b01010000;
			2'b10: vid_mono<=8'b10000110;
			2'b11: vid_mono<=8'b11111111;
			2'b00: vid_mono<=8'b00000000;
		endcase
end

assign r=vid_mono[7:5];
assign g=vid_mono[7:5];
assign b=vid_mono[7:5];

assign AUDIO_L={audio1,1'b0,8'b00000000};
assign AUDIO_R=AUDIO_L;
assign AUDIO_S = 0;
wire hblank, vblank;
wire hs, vs;
wire [2:0] r,g;
wire [2:0] b;

reg ce_pix;
always @(posedge clk_24) begin
        reg old_clk;

        old_clk <= clk_6;
        ce_pix <= old_clk & ~clk_6;
end

arcade_fx #(320,9) arcade_video
(
        .*,

        .clk_video(clk_24),

        .RGB_in({r,g,b}),
        .HBlank(hblank),
        .VBlank(vblank),
        .HSync(hs),
        .VSync(vs),

        .fx(status[5:3])
);

pll pll (
	.refclk ( CLK_50M   ),
	.rst(0),
	.locked 		( locked    ),        // PLL is running stable
	.outclk_0	( clk_24	),        // 24 MHz
	.outclk_1	( clk_12	)        // 12 MHz
	 );

assign clk_sys=clk_12;


endmodule
