
module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,
	output        HDMI_BOB_DEINT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
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

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_CLK, SDRAM_CKE, SDRAM_A, SDRAM_BA, SDRAM_DQ, SDRAM_DQML, SDRAM_DQMH, SDRAM_nCS, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nWE} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_RD, DDRAM_BE, DDRAM_WE} = 'Z;

assign {UART_RTS, UART_TXD, UART_DTR} = 'Z;
assign {BUTTONS, VGA_SL} = 'Z;

assign CE_PIXEL = ce_pix;

assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER  = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;


`include "build_id.v"
localparam CONF_STR = {
	"Galaksija;;",
	"-;",
   "F,TAP;",
	"-;",
	"O23,Screen Color,White,Green,Amber,Cyan;",
   "O1,Aspect Ratio,16:9,4:3;",
	"R5,Break;",
	"R9,Reset;",	
	"-;",	
	"T4,Type OLD before loading!;",
	"V,v0.1.",`BUILD_DATE
};
assign ADC_BUS  = 'Z;
assign USER_OUT = '1;

assign LED_USER = 0;
assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;
assign AUDIO_S = 0;
assign AUDIO_MIX = 0;

/* Keep the max volume reasonable */
assign AUDIO_R = {audio, 5'b0};
assign AUDIO_L = {audio, 5'b0};

assign VIDEO_ARX = status[1] ? 8'd4 : 8'd16;
assign VIDEO_ARY = status[1] ? 8'd3 : 8'd9;

wire				clk_6p25, clk_3p125;

/* Clock */
wire clk_sys;
wire locked;
pll pll
(
	.refclk(CLK_50M),
	.outclk_0(clk_sys),
	.locked(locked)
);

assign clk_6p25 = div_clk[2];
assign clk_3p125 = div_clk[3];
assign clk_1p7 = div_clk[4];
assign CLK_VIDEO = clk_sys;

reg ce_pix;
always @(posedge clk_sys) begin
    ce_pix <= (div_clk[2:0] == 3'd0);
end

reg [4:0] div_clk;

always @(posedge clk_sys) begin
	div_clk <= div_clk + 1'b1;
end

wire	[7:0] video;
wire 	hs, vs, blank;
wire	[1:0]  buttons;
wire	[31:0] status;
wire	[7:0]  audio;
wire  [10:0] ps2_key;

assign VGA_HS = hs;
assign VGA_VS = vs;

assign {VGA_R, VGA_G, VGA_B} = get_color(video);

assign VGA_DE = ~blank;

wire ioctl_download, ioctl_wr;
wire [26:0] ioctl_addr;
wire [7:0] ioctl_dout;

function [23:0] get_color;
   input [7:0] pixel;
begin
   case(status[3:2])
		2'b00: get_color = pixel ? 24'hffffff : 0;
		2'b01: get_color = pixel ? 24'h33ff33 : 0;
		2'b10: get_color = pixel ? 24'hffcc00 : 0;
		2'b11: get_color = pixel ? 24'h40ffa6 : 0;			
	endcase
end
endfunction


galaksija_top galaksija_top (
   .vidclk(clk_6p25),
   .cpuclk(clk_3p125),
   .audclk(clk_1p7),
	
   .reset_in(~(RESET | status[9] | buttons[1])),
   .ps2_key(ps2_key),
   .audio(audio),
	
   .video_dat(video),
   .video_hs(hs),
   .video_vs(vs),
   .video_blank(blank),
	
   .status(status),
   .ioctl_download(ioctl_download),
   .ioctl_wr(ioctl_wr),
   .ioctl_dout(ioctl_dout),
   .ioctl_addr(ioctl_addr)
);	

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
   .clk_sys        (clk_6p25       ),
   .HPS_BUS        (HPS_BUS        ),
   .buttons        (buttons        ),
   .ps2_key	       (ps2_key        ),	
   .status         (status         ),
   .ioctl_download (ioctl_download ),
   .ioctl_wr       (ioctl_wr       ),
   .ioctl_addr     (ioctl_addr     ),
   .ioctl_dout     (ioctl_dout     )
);

endmodule
