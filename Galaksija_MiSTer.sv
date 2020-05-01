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
   
   output        HDMI_CLK,               /* Equals CLK_VIDEO */
   output        HDMI_CE,                /* Equals CE_PIXEL */
   output  [7:0] HDMI_R,
   output  [7:0] HDMI_G,
   output  [7:0] HDMI_B,
   output        HDMI_HS,
   output        HDMI_VS,
   output        HDMI_DE,                /* Equals VGA_DE */
   output  [1:0] HDMI_SL,                /* Scanlines fx */

   output        LED_USER,  // 1 - ON, 0 - OFF.

   // b[1]: 0 - LED status is system status ORed with b[0]
   //       1 - LED status is controled solely by b[0]
   // hint: supply 2'b00 to let the system control the LED.
   output  [1:0] LED_POWER,
   output  [1:0] LED_DISK,

   output [15:0] AUDIO_L,
   output [15:0] AUDIO_R,
   output        AUDIO_S, // 1 - signed audio samples, 0 - unsigned
   input         TAPE_IN,

   // SD-SPI
   output        SD_SCK,
   output        SD_MOSI,
   input         SD_MISO,
   output        SD_CS,
	
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
   output        SDRAM_nWE
);

assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_CLK, SDRAM_CKE, SDRAM_A, SDRAM_BA, SDRAM_DQ, SDRAM_DQML, SDRAM_DQMH, SDRAM_nCS, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nWE} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_RD, DDRAM_BE, DDRAM_WE} = 'Z;

assign {UART_RTS, UART_TXD, UART_DTR} = 'Z;
assign {BUTTONS, VGA_SL} = 'Z;

assign CE_PIXEL = 1'b1;

assign HDMI_CLK = CLK_VIDEO;
assign HDMI_CE  = 1'b1;
assign HDMI_R   = VGA_R;
assign HDMI_G   = VGA_G;
assign HDMI_B   = VGA_B;
assign HDMI_DE  = VGA_DE;
assign HDMI_HS  = VGA_HS;
assign HDMI_VS  = VGA_VS;
assign HDMI_SL  = 0;


`include "build_id.v"
localparam CONF_STR = {
	"Galaksija;;",
	"-;",
   "F,GTP;",
	"-;",
	"O8,Tape drive is,Stopped,Playing;",
   "O1,Aspect Ratio,4:3,16:9;",
	"T9,Reset;",
	"V,v0.1.",`BUILD_DATE
};

assign LED = 1'b1;
assign AUDIO_R = AUDIO_L;	

assign VIDEO_ARX = status[1] ? 8'd16 : 8'd4;
assign VIDEO_ARY = status[1] ? 8'd9 : 8'd3;

wire				clk_1p7, clk_25, clk_3p125;

pll pll (
	 .refclk	   ( CLK_50M  ),
	 .rst				( 1'b0	  ),
	 .outclk_0     ( clk_1p7  ),
	 .outclk_1     ( clk_25   ),
	 .outclk_2     ( clk_3p125)
	);

assign CLK_VIDEO = clk_25;

wire		[7:0] video;
wire				hs, vs, blank;
wire	[1:0] buttons;
wire	  [31:0] status;
wire		[7:0] audio;
wire    [10:0] ps2_key;

assign VGA_HS = hs;
assign VGA_VS = vs;

assign VGA_R = video;
assign VGA_G = video;
assign VGA_B = video;

assign VGA_DE = ~blank;

wire ioctl_download, ioctl_wr;
wire [26:0] ioctl_addr;
wire [7:0] ioctl_dout;


galaksija_top galaksija_top (
   .vidclk(clk_25),
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


hps_io #(.STRLEN(($size(CONF_STR)>>3))) hps_io 
(
   .clk_sys        (clk_25         ),
   .HPS_BUS        (HPS_BUS        ),
   .conf_str       (CONF_STR       ),	
   .buttons        (buttons        ),
   .ps2_key	   (ps2_key        ),	
   .status         (status         ),
   .ioctl_download (ioctl_download ),
   .ioctl_wr       (ioctl_wr       ),
   .ioctl_addr     (ioctl_addr     ),
   .ioctl_dout     (ioctl_dout     )
);

dac #(
   .C_bits(7))
dac (
   .clk_i(clk_25),
   .res_n_i(1'b1),
   .dac_i(audio),
   .dac_o(AUDIO_L)
  );
endmodule
