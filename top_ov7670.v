`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    17:11:23 05/31/2024 
// Design Name: 
// Module Name:    top_ov7670 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
//------------------------------------------------------------------------------
//   Felipe Machado Sanchez
//   Area de Tecnologia Electronica
//   Universidad Rey Juan Carlos
//   https://github.com/felipe-m
//
//   top module 
//   Add second memory and color processing
//---------------------------------------------------------------------------//

module top_ov7670
  # (parameter
      // QQVGA /2
      c_img_cols    = 160, // 8 bits
      c_img_rows    = 120, //  7 bits
      c_img_pxls    = c_img_cols * c_img_rows,
      c_nb_img_pxls =  15,  //160*120=19200 -> 2^15

       c_nb_buf_red   =  4,  // n bits for red in the buffer (memory)
       c_nb_buf_green =  4,  // n bits for green in the buffer (memory)
       c_nb_buf_blue  =  4,  // n bits for blue in the buffer (memory)
       // word width of the memory (buffer)
       c_nb_buf       =   c_nb_buf_red + c_nb_buf_green + c_nb_buf_blue
    )
    (input        rst,
     input        clk,
     output       ov7670_sioc,//SCL
     output       ov7670_siod,//SDA
     output       ov7670_rst_n,

     input        ov7670_vsync,
     input        ov7670_href,
     input        ov7670_pclk,
     output       ov7670_xclk,
     output       ov7670_pwdn,
     input  [7:0] ov7670_d,

     output reg [7:0] led,
     input        btnc_proc_ctrl,  //control of the color processing
	  
	  //VGA 
     output [3:0] vga_red,
     output [3:0] vga_green,
     output [3:0] vga_blue,
     output       vga_hsync,
     output       vga_vsync
    );
	 
	 
    wire          vga_visible;
	 
    wire          vga_new_pxl;
    wire [10-1:0] vga_col;
    wire [10-1:0] vga_row;
   
    wire [c_nb_img_pxls-1:0] display_img_addr;
    wire [c_nb_buf-1:0]      display_img_pxl;

    wire [c_nb_img_pxls-1:0] capture_addr;
    wire [c_nb_buf-1:0]    capture_data;
    wire          capture_we;

    wire [c_nb_img_pxls-1:0] orig_img_addr;
    wire [c_nb_buf-1:0]      orig_img_pxl;
    wire          proc_we;
    wire [c_nb_img_pxls-1:0] proc_img_addr;
    wire [c_nb_buf-1:0]      proc_img_pxl;

    wire          resend;
    wire          config_finished;

    wire          sdat_on;
    wire          sdat_out;  // not making it INOUT, just out, but 3-state

    wire          clk50mhz;
	 
	 assign clk50mhz = cntY[0] ; 
    reg [1:0] cntY;
	 
	 always@ (posedge clk or posedge rst)
		if (rst)
			cntY <=0; 
		else cntY <= cntY +1; 

    wire [7:0]    cnt_vsync_max_test;

    wire [11:0]   ov_capture_datatest;
    wire          rgbmode;

    wire [5:0]    camera_config_steps;
    wire [7:0]    centroid;
    wire [2:0]    proximity; // how close the detected object is

    parameter     testmode = 1'b0; // no test mode
    parameter     swap_r_b = 1'b1; // red and blue are swapped

    wire [2:0]    rgbfilter;



/*
  // 50 MHz clock
  pll i_pll100_50mhz
   (// Clock in ports
    .clk100mhz (clk),      // IN
    // Clock out ports
    .clk50mhz(clk50mhz),     // OUT
    // Status and control signals
    .RESET(rst)    // IN
   //.LOCKED(LOCKED)  // OUT
   );
*/

   vga_sync i_vga 
   (
     .rst     (rst),
     .clk     (clk50mhz),
     .visible (vga_visible),
     .new_pxl (vga_new_pxl),
     .hsync   (vga_hsync),
     .vsync   (vga_vsync),
     .col     (vga_col),
     .row     (vga_row)
  );

  assign rgbmode   = 1'b1;

  vga_display I_ov_display 
  (
     .rst        (rst),
     .clk        (clk50mhz),
     .visible    (vga_visible),
     .new_pxl    (vga_new_pxl),
     .hsync      (vga_hsync),
     .vsync      (vga_vsync),
     .rgbmode    (rgbmode),
     .testmode   (testmode),
     .centroid   (centroid),
     .proximity  (proximity),
     .rgbfilter  (rgbfilter),
     .col        (vga_col),
     .row        (vga_row),
     .frame_pixel(display_img_pxl),
     .frame_addr (display_img_addr),
     .vga_red    (vga_red),
     .vga_green  (vga_green),
     .vga_blue   (vga_blue)
  );


  // frame buffer from the camera, before processing
  frame_buffer cam_fb  
  (
     .clk     (clk50mhz),
     // ports from camera capture
     .wea     (capture_we),
     .addra   (capture_addr),
     .dina    (capture_data),
     // ports to processing module
     .addrb   (orig_img_addr),
     .doutb   (orig_img_pxl)
   );

  // image processing module
  color_proc img_proc
  (
     .rst        (rst),
     .clk        (clk50mhz),
     .proc_ctrl  (btnc_proc_ctrl),
     // from original image frame buffer
     .orig_addr  (orig_img_addr),
     .orig_pxl   (orig_img_pxl),
     // to processed image frame buffer
     .proc_we        (proc_we),
     .proc_addr  (proc_img_addr),
     .proc_pxl   (proc_img_pxl),
     .rgbfilter  (rgbfilter),
     .centroid   (centroid),
     .proximity  (proximity)
  );


  // processed frame buffer, to display on VGA
  frame_buffer proc_fb  
  (
     .clk     (clk50mhz),
     // ports from processing module
     .wea     (proc_we),
     .addra   (proc_img_addr),
     .dina    (proc_img_pxl),
     // ports to display
     .addrb   (display_img_addr),
     .doutb   (display_img_pxl)
   );


  ov7670_capture capture 
  (
     .rst          (rst),
     .clk          (clk50mhz),
     .pclk         (ov7670_pclk),
     .vsync        (ov7670_vsync),
     .href         (ov7670_href),
     .rgbmode      (rgbmode),
     .swap_r_b     (swap_r_b),
     //.dataout_test (ov_capture_datatest),
     //.led_test     (led[3:0]),
     .data         (ov7670_d),
     .addr         (capture_addr),
     .dout         (capture_data),
     .we           (capture_we)
  );
  
  ov7670_top_ctrl controller 
  (
     .rst          (rst),
     .clk          (clk50mhz),
     .resend       (resend),
     .rgbmode      (rgbmode),
     .testmode     (testmode),
     .cnt_reg_test (camera_config_steps),
     .done         (config_finished),
     .sclk         (ov7670_sioc),
     .sdat_on      (sdat_on),
     .sdat_out     (sdat_out),
     .ov7670_rst_n (ov7670_rst_n),
     .ov7670_clk   (ov7670_xclk),
     .ov7670_pwdn  (ov7670_pwdn)
  );

  assign resend = 1'b0;
  assign ov7670_siod = sdat_on ? sdat_out : 1'bz;

  always @ (*)
  begin
    if (config_finished)
      led = centroid;
    else begin
      led[7:6] = 1'b00;
      led[5:0] = camera_config_steps;
    end
  end

endmodule

/////////////////////////////////////////////////////////
//------------------------------------------------------------------------------
// Felipe Machado Sanchez
// Area de Tecnologia Electronica
// Universidad Rey Juan Carlos
// https://github.com/felipe-m
// using a 50 MHz clk

module vga_sync
  #(parameter
    c_pxl_visible    = 640,
    c_pxl_fporch     = 16,
    // from 0 to front porch
    c_pxl_2_fporch   = c_pxl_visible + c_pxl_fporch, // 656
    c_pxl_synch      = 96,
    // from 0 to synch
    c_pxl_2_synch    = c_pxl_2_fporch + c_pxl_synch, // 752
    // total horizontal pixels
    c_pxl_total      = 800,
    // number of pixels of the backporch
    c_pxl_bporch     = c_pxl_total - c_pxl_2_synch,  //  48
    // --------------- Number of rows (Vertical) ----------
    c_line_visible   = 480,
    c_line_fporch    = 9,
    // from 0 to front porch (vertical)
    c_line_2_fporch  = c_line_visible + c_line_fporch, // 489
    c_line_synch     = 2,
    // from init to synchro (vertical)
    c_line_2_synch   = c_line_2_fporch + c_line_synch, // 491
    // total number of lines
    c_line_total     = 520,
    // number of lines of the back porch
    c_line_bporch    = c_line_total - c_line_2_synch,  //  29

    // number of bits for each count
    c_nb_pxls        = 10,  //c_pxl_total      :  800, 
    c_nb_lines       = 10,  //c_line_total   :  520,

    // number of bits for each color RGB
    c_nb_red         = 4,
    c_nb_green       = 4,
    c_nb_blue        = 4,

    // VGA frequency
    c_freq_vga       = 25*10**6, // VGA 25MHz

    // active level of synchronization
    c_synch_act      = 0
   )
   (
    input           rst,
    input           clk,
    output          visible,
    output          new_pxl,
    output  reg     hsync,
    output  reg     vsync,
    output [10-1:0] col,
    output [10-1:0] row
   );
  

  reg            cnt_clk; // count 0 to 1: 2 clk cycles, from 50MHz to 25MHz
  reg  [10-1:0]  cnt_pxl;
  reg  [10-1:0]  cnt_line;

  wire   end_cnt_pxl;
  wire   end_cnt_line;
  wire   new_line;

  reg    visible_pxl;  
  reg    visible_line;

  // count 2 clock cycles to get a pixel cycle
  always @ (posedge rst, posedge clk)
  begin
    if (rst)
      cnt_clk <= 1'b0;
    else
      cnt_clk <= ~cnt_clk;
  end 

  assign new_pxl =  cnt_clk;

  assign col     = cnt_pxl;
  assign row     = cnt_line;
  assign visible = visible_pxl && visible_line;

  // counting 800 pixels (columns)
  always @ (posedge rst, posedge clk)
  begin
    if (rst)
      cnt_pxl <= 10'd0;
    else begin
      if (new_pxl) begin
        if (end_cnt_pxl) 
          cnt_pxl <= 10'd0;
        else
          cnt_pxl <= cnt_pxl + 1;
      end
    end
  end 

  // end of pixel count
  assign end_cnt_pxl =  (cnt_pxl == c_pxl_total-1) ? 1'b1 : 1'b0;
  // new line: when in the end of the count and there is a new pixel
  assign new_line = end_cnt_pxl && new_pxl;

  // combinational outputs of pixel count (horizontal)
  always @ (rst or cnt_pxl)
  begin
    if (rst) begin
      visible_pxl = 1'b0;
      hsync = ~c_synch_act;
    end
    else if (cnt_pxl < c_pxl_visible) begin
      visible_pxl = 1'b1;
      hsync = ~c_synch_act;
    end
    else if (cnt_pxl < c_pxl_2_fporch) begin
      visible_pxl = 1'b0;
      hsync = ~c_synch_act;
    end
    else if (cnt_pxl < c_pxl_2_synch) begin
      visible_pxl = 1'b0;
      hsync = c_synch_act; // synch active
    end
    else begin
      visible_pxl = 1'b0;
      hsync = ~c_synch_act; 
    end
  end

  // counting 520 lines (rows)
  always @ (posedge rst, posedge clk)
  begin
    if (rst)
      cnt_line <= 10'd0;
    else begin
      if (new_line) begin
        if (end_cnt_line) 
          cnt_line <= 10'd0;
        else
          cnt_line <= cnt_line + 1;
      end
    end
  end 

  // end of pixel count
  assign end_cnt_line =  (cnt_line == c_line_total-1) ? 1'b1 : 1'b0;

  // combinational outputs of line count (vertical)
  always @ (rst or cnt_line)
  begin
    if (rst) begin
      visible_line = 1'b0;
      vsync = ~c_synch_act;
    end
    else if (cnt_line < c_line_visible) begin
      visible_line = 1'b1;
      vsync = ~c_synch_act;
    end
    else if (cnt_line < c_line_2_fporch) begin
      visible_line = 1'b0;
      vsync = ~c_synch_act;
    end
    else if (cnt_line < c_line_2_synch) begin
      visible_line = 1'b0;
      vsync = c_synch_act; // synch active
    end
    else begin
      visible_line = 1'b0;
      vsync = ~c_synch_act; 
    end
  end

endmodule
///////////////////////////////////////////////
//------------------------------------------------------------------------------
//   Felipe Machado Sanchez
//   Area de Tecnologia Electronica
//   Universidad Rey Juan Carlos
//   https://github.com/felipe-m
//
//   vga_display.vhd
//   Displays the image on the frambuffer to the VGA
//

module vga_display
  # (parameter
      // VGA
      //c_img_cols    = 640, // 10 bits
      //c_img_rows    = 480, //  9 bits
      //c_img_pxls    = c_img_cols * c_img_rows,
      //c_nb_line_pxls = 10, // log2i(c_img_cols-1) + 1;
      // c_nb_img_pxls = log2i(c_img_pxls-1) + 1
      //c_nb_img_pxls =  19,  //640*480=307,200 -> 2^19=524,288
      // QQVGA
      c_img_cols    = 160, // 8 bits
      c_img_rows    = 120, //  7 bits
      c_img_pxls    = c_img_cols * c_img_rows,
      c_nb_img_pxls = $clog2(c_img_pxls), // 15 -> 160*120=19.200 -> 2^15
      // QQVGA /2
      //c_img_cols    = 80, // 7 bits
      //c_img_rows    = 60, //  6 bits
      //c_img_pxls    = c_img_cols * c_img_rows,
      //c_nb_img_pxls =  13,  //80*60=4800 -> 2^13



    c_nb_buf_red   =  4,  // n bits for red in the buffer (memory)
    c_nb_buf_green =  4,  // n bits for green in the buffer (memory)
    c_nb_buf_blue  =  4,  // n bits for blue in the buffer (memory)
    // word width of the memory (buffer)
    c_nb_buf       =   c_nb_buf_red + c_nb_buf_green + c_nb_buf_blue
  )
  (
    input          rst,       //reset, active high
    input          clk,       //fpga cloc
    input          visible,
    input          new_pxl,
    input          hsync,
    input          vsync,
    input          rgbmode,
    input          testmode,
    input [2:0]    rgbfilter,
    input [7:0]    centroid,
    input [2:0]    proximity,
    input [10-1:0] col,
    input [10-1:0] row,
    input  [c_nb_buf-1:0] frame_pixel,
    output reg [c_nb_img_pxls-1:0] frame_addr,
    output reg [4-1:0] vga_red,
    output reg [4-1:0] vga_green,
    output reg [4-1:0] vga_blue
  );

  reg  [7:0] char_rgbmode, char_testmode;
  wire [2:0] char_row;
  wire [2:0] char_col;
  wire [3:0] addr_rom_rgb;
  wire [3:0] addr_rom_test;

  assign char_row = row[2:0];
  assign char_col = col[2:0];
  assign addr_rom_rgb = {~rgbmode, char_row};
  assign addr_rom_test = {testmode, char_row};

  always @ (addr_rom_rgb) begin
    case (addr_rom_rgb)
      4'h0: char_rgbmode <= 8'b11111100; // R: RGB
      4'h1: char_rgbmode <= 8'b10000010;
      4'h2: char_rgbmode <= 8'b10000010;
      4'h3: char_rgbmode <= 8'b11111100;
      4'h4: char_rgbmode <= 8'b10001000;
      4'h5: char_rgbmode <= 8'b10000100;
      4'h6: char_rgbmode <= 8'b10000010;
      4'h7: char_rgbmode <= 8'b00000000;
      4'h8: char_rgbmode <= 8'b10000010; // Y: YUV
      4'h9: char_rgbmode <= 8'b01000100;
      4'hA: char_rgbmode <= 8'b00111000;
      4'hB: char_rgbmode <= 8'b00010000;
      4'hC: char_rgbmode <= 8'b00010000;
      4'hD: char_rgbmode <= 8'b00010000;
      4'hE: char_rgbmode <= 8'b00010000;
      4'hF: char_rgbmode <= 8'b00000000;
    endcase
  end

  always @ (addr_rom_test) begin
    case (addr_rom_test)
      4'h0: char_testmode <= 8'b10000010; // N: Normal
      4'h1: char_testmode <= 8'b11000010;
      4'h2: char_testmode <= 8'b10100010;
      4'h3: char_testmode <= 8'b10010010;
      4'h4: char_testmode <= 8'b10001010;
      4'h5: char_testmode <= 8'b10000110;
      4'h6: char_testmode <= 8'b10000010;
      4'h7: char_testmode <= 8'b00000000;
      4'h8: char_testmode <= 8'b11111110; // T: Test
      4'h9: char_testmode <= 8'b00010000;
      4'hA: char_testmode <= 8'b00010000;
      4'hB: char_testmode <= 8'b00010000;
      4'hC: char_testmode <= 8'b00010000;
      4'hD: char_testmode <= 8'b00010000;
      4'hE: char_testmode <= 8'b00010000;
      4'hF: char_testmode <= 8'b00000000;
    endcase
  end


  always @ (posedge rst, posedge clk)
  begin
    if (rst)
      frame_addr <= 0;
    else begin
      if (row < c_img_rows) begin
        if (col < c_img_cols) begin
          if (new_pxl)
            //it may have a simulation problem in the last pixel of the last row
            frame_addr <= frame_addr + 1;
        end
      end
      else
        frame_addr <= 0;
    end
  end


  always @ (*)
  begin
    vga_red   = 0;
    vga_green = 0;
    vga_blue  = 0;
    if (visible) begin
      vga_red   = {4{1'b0}};
      vga_green = {4{1'b0}};
      vga_blue  = {4{1'b0}};
      if ((col < c_img_cols) && (row < c_img_rows)) begin
          if (rgbmode) begin
            vga_red   = frame_pixel[c_nb_buf-1: c_nb_buf-c_nb_buf_red];
            vga_green = frame_pixel[c_nb_buf-c_nb_buf_red-1:c_nb_buf_blue];
            vga_blue  = frame_pixel[c_nb_buf_blue-1:0];
          end
          else begin
            vga_red   = frame_pixel[7:4];
            vga_green = frame_pixel[7:4];
            vga_blue  = frame_pixel[7:4];
          end
      end
      else if (row < 128-8 && col >= 256 && col < 256+8) begin
        // row 128 -> 7 bits, proximity is 3 bits. We want the bits 6:4
        // this is a vertical bar, when closest the bar will reach the top
        // proximity is 0 to 7, 7 maximum proximity
        // row 0 is on top
        // if proximity=7 -> ~proximity=0 -> all rows ON 
        // if proximity=6 -> ~proximity=1 -> rows 7 to 1 ON 
        // if proximity=5 -> ~proximity=2 -> rows 7 to 2 ON 

        // if proximity=0 -> ~proximity=7 -> rows 7 to 2 ON 
        if (~proximity <= row[6:4]) begin
          vga_red   = {4{rgbfilter[2]}};
          vga_green = {4{rgbfilter[1]}};
          vga_blue  = {4{rgbfilter[0]}};
        end
      end
      else if (row > 256 && row < 384 && col < 512) begin
         vga_red   = {col[8:7],2'b00};
         vga_green = {col[6:5],2'b00};
         vga_blue  = {row[6:5],2'b00};
      end
      else if ((col == c_img_cols) || (row == c_img_rows)) begin
         vga_red   = 4'b0000;
         vga_green = 4'b1000;
         vga_blue  = 4'b1000;
      end
      else if ((col == 2*c_img_cols) || (row == 2*c_img_rows)) begin
         vga_red   = 4'b1000;
         vga_green = 4'b1000;
         vga_blue  = 4'b0000;
      end
      else if ((col == 4*c_img_cols) || (row == 4*c_img_rows)) begin
         vga_red   = 4'b1000;
         vga_green = 4'b0000;
         vga_blue  = 4'b1000;
      end
      else if ((row > c_img_rows-1) && (row < c_img_rows + 8)) begin
         if (col < c_img_cols) begin
           if (col < 20) begin
             if (centroid[0]) begin
               vga_red   = {4{rgbfilter[2]}};
               vga_green = {4{rgbfilter[1]}};
               vga_blue  = {4{rgbfilter[0]}};
             end
           end
           else if (col < 40) begin
             if (centroid[1]) begin
               vga_red   = {4{rgbfilter[2]}};
               vga_green = {4{rgbfilter[1]}};
               vga_blue  = {4{rgbfilter[0]}};
             end
           end
           else if (col < 60) begin
             if (centroid[2]) begin
               vga_red   = {4{rgbfilter[2]}};
               vga_green = {4{rgbfilter[1]}};
               vga_blue  = {4{rgbfilter[0]}};
             end
           end
           else if (col < 80) begin
             if (centroid[3]) begin
               vga_red   = {4{rgbfilter[2]}};
               vga_green = {4{rgbfilter[1]}};
               vga_blue  = {4{rgbfilter[0]}};
             end
           end
           else if (col < 100) begin
             if (centroid[4]) begin
               vga_red   = {4{rgbfilter[2]}};
               vga_green = {4{rgbfilter[1]}};
               vga_blue  = {4{rgbfilter[0]}};
             end
           end
           else if (col < 120) begin
             if (centroid[5]) begin
               vga_red   = {4{rgbfilter[2]}};
               vga_green = {4{rgbfilter[1]}};
               vga_blue  = {4{rgbfilter[0]}};
             end
           end
           else if (col < 140) begin
             if (centroid[6]) begin
               vga_red   = {4{rgbfilter[2]}};
               vga_green = {4{rgbfilter[1]}};
               vga_blue  = {4{rgbfilter[0]}};
             end
           end
           else begin // less than 160
             if (centroid[7]) begin
               vga_red   = {4{rgbfilter[2]}};
               vga_green = {4{rgbfilter[1]}};
               vga_blue  = {4{rgbfilter[0]}};
             end
           end
         end
      end
      else if ((row > 127) && (row < 128 + 8)) begin
         if ((col > 7) && (col < 16)) begin // RGB MODE
           if (char_rgbmode[7-char_col]) begin
             vga_red   = 4'b1111;
             vga_green = 4'b1111;
             vga_blue  = 4'b1111;
           end
           else begin
             vga_red   = 4'b0000;
             vga_green = 4'b0000;
             vga_blue  = 4'b0000;
           end
         end
         else if ((col > 15) && (col < 24)) begin // TEST MODE
           if (char_testmode[7-char_col]) begin
             vga_red   = 4'b1111;
             vga_green = 4'b1111;
             vga_blue  = 4'b1111;
           end
           else begin
             vga_red   = 4'b0000;
             vga_green = 4'b0000;
             vga_blue  = 4'b0000;
           end
         end
         else if ((col > 23) && (col < 32)) begin // color box indicating filter
           vga_red   = {4{rgbfilter[2]}};
           vga_green = {4{rgbfilter[1]}};
           vga_blue  = {4{rgbfilter[0]}};
         end
      end
      else begin
         vga_red   = 4'b0000;
         vga_green = 4'b0000;
         vga_blue  = 4'b0000;
      end
    end
  end

endmodule
//////////////////////////////////////////

//------------------------------------------------------------------------------
//   Felipe Machado Sanchez
//   Area de Tecnologia Electronica
//   Universidad Rey Juan Carlos
//   https://github.com/felipe-m
//
//   sccb_master.v
//   Module in charge of the SCCB communication with the OmniVision OV7670
//   camera.
//   SCCB (Serial Camera Control Bus) is like the I2C
//   This module is the master.
//   For this first version, it will only write to the camera, therefore
//   it will be a 3-phase write transmission cycle
//   As explained in the Register Set section of the datasheet, the camera
//   slave address is x"42" (0x42, hexadecimal) for writting and and x"43" for
//   reading
//
//   Instead of generics, constants are defined in packages
//
//                 0 1 2 3
//       :________:     ___:     ___:
//  SCL  :        :\___/   :\___/   :
//       :        :        :        :
//       :__      :   _____:__ _____:
//  SDA  :  \_____:__/__d7_:__X__d6_:
//       :0 1 2 3 :0 1 2 3 :0 1 2 3
//                :        :
//                :.Tsccb..:

//          init                                  dont   Another phase
//        sequence 0 1 2 3                        care    OR end bit
//       :______  :   ___  :   ___  : :   ___  :   ___  :  ______
//  SCL  :      \_:__/   \_:__/   \_: :__/   \_:__/   \_:_/
//       :        :        :        : :        :        :
//       :__      : _______: _______: : _______: _______:    ____
//  SDA  :  \_____:/__d7___:X__d6___: :X__d0___:X___Z___:___/    
//       :0 1 2 3 :0 1 2 3 :0 1 2 3
//                :        :
//                :.Tsccb..:                     DNTC_ST:END_SEQ_ST
//       INIT_SEQ_ST
//
//     The period Tsccb is divided in 4 parts.
//     SCL changes at the end of 1st and 3rd quarters
//     SDA changes at the end of the peridod (end of last (4th) quarter)
//     When transmiting bits, SDA must not change when SCL is high
//     Max frequency of the sccb clock 400 KHz: Period 2.5 us
//     Half of the time will be high, the other half low: 1.25 us
//     However, the minimum clok low period for the sccb_clk is 1.3 us
//     making low and high the same time, would be 2.6 us (~384,6 KHz)
//     We will make a divider of the 1/4 the period, to be able to change
//     the signals at the quarter. That would be 650 ns.

//


module sccb_master
  #(parameter
    c_off                  = 1'b0, // push button off
    c_on                   = ~c_off, // push button on
    c_clk_period           = 10, // fpga clk peridod in ns
    // quarter of a period in ns
    c_sclk_period_div4     = 650, // see explanation above
    // frequency divider counter end value. Divided by 4 to have it divided
    // in 4 slots
    // we use div_ceil, to avoid having a smaller end count,
    // which would mean higher frequency
    c_sclk_div4_endcnt     = 65, // div_ceil(c_sclk_period_div4,c_clk_period);
    // number of bits necessary to represent c_sclk_endcont in binary
    c_nb_cnt_sclk_div4     =  7  // log2i(c_sclk_div4_endcnt-1) + 1;
   )
   (
    input         rst,       //reset, active high
    input         clk,       //fpga clock
    input         start_tx,  //start transmission
    input  [6:0]  id,        //id of the slave
    input  [7:0]  addr,      //address to be written
    input  [7:0]  data_wr,   //data to write to slave
    output        ready,     //ready to send
    output reg    finish_tx, //transmission finished(pulse
    output reg    sclk,      //sccb clock
    output reg    sdat_on,   //transmitting serial ('1')
    //input         sdat_in, //sccb serial data in
    output reg    sdat_out   //sccb serial data out
   );


  // saving in registers the slave ID, address or the register
  // and data to be written. 8x3 = 24 bits
  //signal id_rg    : std_logic_vector(7 downto 0); //id of the slave
  //signal addr_rg  : std_logic_vector(7 downto 0); //address to be written
  //signal data_rg  : std_logic_vector(7 downto 0); //data to write to slave
  reg [24-1:0] send_rg; //id, addr and data


  // frequency divider, but 4 time faster than the sccb period
  reg [c_nb_cnt_sclk_div4-1:0] cnt_sclk_div4;
  // indicates that the count reached the end: end of a quarter
  wire       sclk_div4_end;

  // count of the four quarters of the scc clock
  reg  [1:0] cnt_4sclk;
  wire       sclk_end; // end of a sccb_clk cycle

  // count the 3 phases of the sending:
  //   0: slave ID
  //   1: address of the register to be written
  //   2: data to be written
  reg  [1:0] cnt_phases;
  reg        new_phase;  // end of a phase, starting a new one
  wire       phases_end; // end of the 3 phases

  reg        ready_aux;  // not busy, ready to receive

  // sccb_states:
  parameter IDLE_ST      = 0, // waiting to send, not busy
            INIT_SEQ_ST  = 1, // sending the initial sequence
            SEND_BYTE_ST = 2, // sending the byte of any of the 3 phases
            DNTC_ST      = 3, // dont care bit, in i2c would be ack
            END_SEQ_ST   = 4; // sending the end sequence

  reg  [2:0]  pr_sccb_st; // present state
  reg  [2:0]  nx_sccb_st; // next state

  // enable the counter of bits to send data and shifting the registers
  // in any of the 3 phases: ID_ADDR_ST, REG_ADDR_ST, SEND_BYTE_ST
  reg        send_data;
  // counter 
  reg  [2:0] cnt_8bits; // 3 bits to count 0 to 7
  // end of the 8 bit count
  wire       cnt_8bits_end;

  // indication to save id, address and data to write
  reg        save_indata;
  //clear registers where the data to send is saved
  reg        clr_datarg;

  assign ready = (rst == c_off) ? ready_aux : 1'b0; // if reset, not ready

  always @ (posedge rst, posedge clk)
  begin
    if (rst)
      // the line is inactive at '1'
      send_rg   <= {24{1'b1}}; // '1' in all 24 bits
    else begin
      if (clr_datarg)
        send_rg  <= {24{1'b1}}; // all to '1'
      else if (save_indata)
        //'0' indicates we are writting in the slave. Reading not implemented
        // id has 7 bits
        send_rg   <= {id, 1'b0, addr, data_wr};
      else if (send_data) begin
        if (sclk_end)
          // rotate left, fillings with '1'
          send_rg <= {send_rg[23-1:0], 1'b1};
      end
    end
  end

  // counting a quarter of the sccb clk period
  always @ (posedge rst, posedge clk)
  begin
    if (rst)
      cnt_sclk_div4 <= 0;
    else begin
      if (ready_aux)
        cnt_sclk_div4 <= 0;
      else begin
        if (sclk_div4_end)
          cnt_sclk_div4 <= 0;
        else
          cnt_sclk_div4 <= cnt_sclk_div4 + 1;
      end
    end
  end

  assign sclk_div4_end = (cnt_sclk_div4 == c_sclk_div4_endcnt-1)? 1'b1 : 1'b0;

  // counting the 4 quarters of the sccb clk period
  always @ (posedge rst, posedge clk)
  begin
    if (rst)
      cnt_4sclk <= 0;
    else begin
      if (ready_aux) // if inactive, no count and start counting
        cnt_4sclk <= 0;
      else if (sclk_end)
        cnt_4sclk <= 0;
      else if (sclk_div4_end)
        cnt_4sclk <= cnt_4sclk + 1;
    end
  end

  assign sclk_end = (sclk_div4_end==1'b1 && cnt_4sclk == 4-1)? 1'b1 : 1'b0;

  // counting the 8 bits of each of the 3 phases
  // counting down to keep track of the bits, the first is the bit 7
  // the last the bit 0
  always @ (posedge rst, posedge clk)
  begin
    if (rst)
      cnt_8bits <= 3'b111;
    else begin
      // send_data active in any of the 3 phases (SEND_BYTE_ST)
      if (send_data==1'b0) // if inactive, no count and start counting
        cnt_8bits <= 3'b111;
      else if (cnt_8bits_end)
        cnt_8bits <= 3'b111;
      else if (sclk_end)
        cnt_8bits <= cnt_8bits - 1;
    end
  end

  assign cnt_8bits_end = (sclk_end==1'b1 && cnt_8bits == 0)? 1'b1 : 1'b0;

  // counting the 3 phases of a SCCB write
  always @ (posedge rst, posedge clk)
  begin
    if (rst)
      cnt_phases <= 2'd0;
    else begin
      if (ready_aux)
        cnt_phases <= 2'd0;
      else if (phases_end)
        cnt_phases <= 2'd0;
      else if (new_phase)
        cnt_phases <= cnt_phases + 1;
    end
  end

  // 3 phases for writting
  assign phases_end = (cnt_phases == 3-1 && new_phase ==1'b1) ? 1'b1 : 1'b0;

  // FSM sequential process
  always @ (posedge rst, posedge clk)
  begin
    if (rst)
      pr_sccb_st <= IDLE_ST;
    else
      pr_sccb_st <= nx_sccb_st;
  end

  // FSM combinatorial process
  always @ (pr_sccb_st or start_tx or cnt_4sclk or sclk_end or send_rg or
            cnt_8bits  or  cnt_phases or cnt_8bits_end)
  begin
    // default values
    ready_aux   = 1'b0;  // only ready in IDLE
    sdat_on     = 1'b0;
    sdat_out    = 1'b1;
    nx_sccb_st  = pr_sccb_st;
    save_indata = 1'b0;
    clr_datarg  = 1'b0;
    send_data   = 1'b0;
    new_phase   = 1'b0;
    finish_tx   = 1'b0;
	//<SC> 
	sclk		= 1'b1;
    case (pr_sccb_st)
      IDLE_ST: begin  // waiting to send, not busy
        ready_aux = 1'b1;  // ready to send
        sclk      = 1'b1;
        sdat_on   = 1'b0;  //Z
        sdat_out  = 1'b1;
        if (start_tx) begin
          nx_sccb_st   = INIT_SEQ_ST;
          save_indata  = 1'b1;  //id, address and data to write have to be saved
        end
      end
      INIT_SEQ_ST: begin   // sending the initial sequence
        sclk    = 1'b1;
        sdat_on = 1'b1;
        case (cnt_4sclk)
          2'b00 : begin
            sclk     = 1'b1;
            sdat_out = 1'b1;
          end
          2'b01, 2'b10 : begin
            sclk     = 1'b1;
            sdat_out = 1'b0;
          end
          default : begin //3
            sclk     = 1'b0;
            sdat_out = 1'b0;
          end
        endcase
        if (sclk_end)
          nx_sccb_st = SEND_BYTE_ST;
      end
      SEND_BYTE_ST: begin // sending the bytes of any of the 3 phases
        send_data = 1'b1;  // enable the 8 bit counter
        sdat_on   = 1'b1;
        case (cnt_4sclk)
          2'b00, 2'b11:
            sclk  = 1'b0;
          default: //1, 2
            sclk  = 1'b1;
        endcase
        sdat_out = send_rg[23];
        if (cnt_8bits_end)
          nx_sccb_st = DNTC_ST;
      end
      DNTC_ST: begin     // dont care bit, in i2c would be ack
        sdat_on   = 1'b0;  // it will be Z
        case (cnt_4sclk)
          2'b00, 2'b11:
            sclk = 1'b0;
          default: //1, 2
            sclk = 1'b1;
        endcase
        if (sclk_end) begin
          new_phase   = 1'b1;
          if (cnt_phases == 3-1)
            nx_sccb_st = END_SEQ_ST; // end of the transimission
          else
            nx_sccb_st = SEND_BYTE_ST; // new phase
        end
      end
      END_SEQ_ST: begin   // sending the end sequence
        clr_datarg = 1'b1; //clear registers where the data to send is saved
        sdat_on    = 1'b1;
        case (cnt_4sclk)
          2'b00: begin
            sclk     = 1'b0;
            sdat_out = 1'b0;
          end
          2'b01: begin
            sclk     = 1'b1;
            sdat_out = 1'b0;
          end
          default: begin // 2 or 3
            sclk     = 1'b1;
            sdat_out = 1'b1;
          end
        endcase
        if (sclk_end) begin
          nx_sccb_st = IDLE_ST;
          finish_tx  = 1'b1; // pulse to tell that transimission is done
        end
      end
    endcase
  end
    
endmodule
// file: pll.v
// 
// (c) Copyright 2008 - 2011 Xilinx, Inc. All rights reserved.
// 
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
// 
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
// 
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
// 
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
// 
//----------------------------------------------------------------------------
// User entered comments
//----------------------------------------------------------------------------
// None
//
//----------------------------------------------------------------------------
// "Output    Output      Phase     Duty      Pk-to-Pk        Phase"
// "Clock    Freq (MHz) (degrees) Cycle (%) Jitter (ps)  Error (ps)"
//----------------------------------------------------------------------------
// CLK_OUT1____50.000______0.000______50.0______167.017____114.212
//
//----------------------------------------------------------------------------
// "Input Clock   Freq (MHz)    Input Jitter (UI)"
//----------------------------------------------------------------------------
// __primary_________100.000____________0.010

`timescale 1ps/1ps

(* CORE_GENERATION_INFO = "pll,clk_wiz_v3_6,{component_name=pll,use_phase_alignment=true,use_min_o_jitter=false,use_max_i_jitter=false,use_dyn_phase_shift=false,use_inclk_switchover=false,use_dyn_reconfig=false,feedback_source=FDBK_AUTO,primtype_sel=MMCM_ADV,num_out_clk=1,clkin1_period=10.0,clkin2_period=10.0,use_power_down=false,use_reset=true,use_locked=false,use_inclk_stopped=false,use_status=false,use_freeze=false,use_clk_valid=false,feedback_type=SINGLE,clock_mgr_type=MANUAL,manual_override=false}" *)
module pll
 (// Clock in ports
  input         clk100mhz,
  // Clock out ports
  output        clk50mhz,
  // Status and control signals
  input         RESET
 );

  // Input buffering
  //------------------------------------
  IBUFG clkin1_buf
   (.O (clkin1),
    .I (clk100mhz));


  // Clocking primitive
  //------------------------------------
  // Instantiation of the MMCM primitive
  //    * Unused inputs are tied off
  //    * Unused outputs are labeled unused
  wire [15:0] do_unused;
  wire        drdy_unused;
  wire        psdone_unused;
  wire        locked_unused;
  wire        clkfbout;
  wire        clkfbout_buf;
  wire        clkfboutb_unused;
  wire        clkout0b_unused;
  wire        clkout1_unused;
  wire        clkout1b_unused;
  wire        clkout2_unused;
  wire        clkout2b_unused;
  wire        clkout3_unused;
  wire        clkout3b_unused;
  wire        clkout4_unused;
  wire        clkout5_unused;
  wire        clkout6_unused;
  wire        clkfbstopped_unused;
  wire        clkinstopped_unused;

  PLLE2_ADV
  #(.BANDWIDTH            ("OPTIMIZED"),
    .COMPENSATION         ("ZHOLD"),
    .DIVCLK_DIVIDE        (1),
    .CLKFBOUT_MULT        (8),
    .CLKFBOUT_PHASE       (0.000),
    .CLKOUT0_DIVIDE       (16),
    .CLKOUT0_PHASE        (0.000),
    .CLKOUT0_DUTY_CYCLE   (0.500),
    .CLKIN1_PERIOD        (10.0),
    .REF_JITTER1          (0.010))
  plle2_adv_inst
    // Output clocks
   (.CLKFBOUT            (clkfbout),
    .CLKOUT0             (clkout0),
    .CLKOUT1             (clkout1_unused),
    .CLKOUT2             (clkout2_unused),
    .CLKOUT3             (clkout3_unused),
    .CLKOUT4             (clkout4_unused),
    .CLKOUT5             (clkout5_unused),
     // Input clock control
    .CLKFBIN             (clkfbout_buf),
    .CLKIN1              (clkin1),
    .CLKIN2              (1'b0),
     // Tied to always select the primary input clock
    .CLKINSEL            (1'b1),
    // Ports for dynamic reconfiguration
    .DADDR               (7'h0),
    .DCLK                (1'b0),
    .DEN                 (1'b0),
    .DI                  (16'h0),
    .DO                  (do_unused),
    .DRDY                (drdy_unused),
    .DWE                 (1'b0),
    // Other control and status signals
    .LOCKED              (locked_unused),
    .PWRDWN              (1'b0),
    .RST                 (RESET));

  // Output buffering
  //-----------------------------------
  BUFG clkf_buf
   (.O (clkfbout_buf),
    .I (clkfbout));

  BUFG clkout1_buf
   (.O   (clk50mhz),
    .I   (clkout0));




endmodule


//------------------------------------------------------------------------------
//   Felipe Machado Sanchez
//   Area de Tecnologia Electronica
//   Universidad Rey Juan Carlos
//   https://github.com/felipe-m
//
//   ov7670_top_ctrl.v
//   structural model, that controls the OV7670 camera, send the registers
//   and controls the camera
//------------------------------------------------------------------------------

module ov7670_top_ctrl
  (input        rst,              //reset, active high
   input        clk,              //FPGA clock
   input        resend,           //resend the sequence
   input        rgbmode,         //if '1': in RGB, else YUV
   input        testmode,        //if '1': in test mode
   output [5:0] cnt_reg_test,     //to test the count
   output       done,             //all transmission done
   output       sclk,             //sccb clock
   output       sdat_on,          //transmitting serial ('1')
   //output       sdat_in,        //sccb serial data in
   output       sdat_out,         //sccb serial data ou
   output       ov7670_rst_n,     //camera reset
   output       ov7670_clk,       //camera system clock
   output       ov7670_pwdn       //camera power down
  );


  wire         start_tx;
  wire         sccb_ready;
  wire [6:0]   id;
  wire [7:0]   addr;
  wire [7:0]   data_wr;

  sccb_master i_sccb
  (
    .rst      (rst),
    .clk      (clk),
    .start_tx (start_tx),
    .id       (id),
    .addr     (addr),
    .data_wr  (data_wr),
    .ready    (sccb_ready),
    //.finish_tx    
    .sclk     (sclk),
    .sdat_on  (sdat_on),
    //sdat_in
    .sdat_out (sdat_out)
  );


  ov7670_ctrl_reg i_regs
  (
    .rst          (rst),
    .clk          (clk),
    .rgbmode      (rgbmode),
    .testmode     (testmode),
    .resend       (resend),
    .sccb_ready   (sccb_ready),
    .cnt_reg_test (cnt_reg_test), //test
    .start_tx     (start_tx),
    .done         (done),
    .id           (id),
    .addr         (addr),
    .data_wr      (data_wr),
    .ov7670_rst_n (ov7670_rst_n),
    .ov7670_clk   (ov7670_clk),
    .ov7670_pwdn  (ov7670_pwdn)
  );

endmodule

/////////////////////////////////
//------------------------------------------------------------------------------
//   Felipe Machado Sanchez
//   Area de Tecnologia Electronica
//   Universidad Rey Juan Carlos
//   https://github.com/felipe-m
//
//   ov7670_ctrl_reg.vhd
//   Module in charge of telling the SCCB module what registers to write
//   in the camera camera and to control the camera inputs:
//     - ov7670_rst_n
//          0: camera reset
//          1: normal mode            
//     - pwdn: power down mode selection
//          0: normal mode
//          1: power down mode
//     - xclk: system clock input
//          freq   :  min: 10 MHz  -- typ: 24 MHz  -- Max: 48 MHz
//          Period : max: 100 ns   -- typ: 42 ns   -- Max: 21 ns
//   Register values taken from
//   http://hamsterworks.co.nz/mediawiki/index.php/Zedboard_OV7670
//   http://hamsterworks.co.nz/mediawiki/index.php/OV7670_camera
//------------------------------------------------------------------------------

module ov7670_ctrl_reg
  (
    input         rst,          //reset, active high
    input         clk,          //fpga clock
    input         rgbmode,      //if '1': in RGB mode
    input         testmode,     //if '1': in test mode
    input         resend,       //resend all the sequence
    input         sccb_ready,   //SCCB ready to transmit
    output [5:0]  cnt_reg_test,     //to test the count
    output        start_tx,     //start transmission
    output        done,         //all the registers written
    output [6:0]  id,           //id of the slave
    output [7:0]  addr,         //address to be written
    output [7:0]  data_wr,      //data to write to slave
    output        ov7670_rst_n, //camera reset
    output        ov7670_clk,   //camera system clock
    output        ov7670_pwdn   //camera power down
  );



  // frequency divider for camera clk (divide by 4) 
  //signal cnt_cam_clk : unsigned (1 downto 0);
  // frequency divider for camera clk (divide by 8) 
  reg  [2:0]   cnt_cam_clk;

  // 6 bits: less than 64 registers to be written, change if the number
  // of registers to be written change
  reg  [5:0]   cnt_reg;

  // auxiliary signal, connected to output port done
  wire         alltx_done;

  // auxiliary signal connected to output port ov7670_rst_n
  reg          cam_rst_n;

  // auxiliary signal, connected to start_tx
  reg          start_tx_aux;

  reg [24-1:0] cnt300ms;
  wire         end300ms;
  reg          ena_cnt300ms;
  parameter    c_end300ms = 15000000;
  //parameter    c_end300ms = 30;



  //id of the slave; 0x21.
  // if adding the write bit, would be 0x42 for writing and 0x43 for reading
  parameter c_id_write  = 7'b0100_001;
  wire  [7:0]   addr_aux; //address to be written
  //wire  [7:0]   data_aux; //data to write to slave
  // register from the register memory: address & data
  reg  [15:0]   reg_i;

  parameter RSTCAM_ST      = 0,  // Reset camera during 300ms
            WAIT_RSTCAM_ST = 1,  // Wait 300ms for the camera to be ready
            WAIT_ST        = 2,  // waiting to send, until not busy
            WRITE_REG_ST   = 3,  // sending the initial sequence
            DONE_ST        = 4;  // all the registers written

  // present state, next state
  reg  [2:0]  pr_ctrl_st, nx_ctrl_st;  // present state, next state

  // save the mode values to see if the have changed
  reg         rgbmode_old;
  reg         testmode_old;
  wire        mode_change;

  reg [15:0] reg_yuv422, reg_yuv422_test, reg_rgb444, reg_rgb444_test;

  assign cnt_reg_test = cnt_reg;

  // msb 8 bits are the address (15 downto 8)
  // lsb 8 bits are the register value to be written

  always @ (cnt_reg) begin
    // *IG means Implementation guide
    case (cnt_reg)
      6'h00:
        reg_rgb444_test <= 16'h1280;
               // 12: COM7 Common Control 7
               // [7]=1: Reset all registers to default values
      6'h01:
        reg_rgb444_test <= 16'h1280;
               // 12: COM7 Common Control 7
               // [7]=1: Reset all registers to default values
      6'h02:
        reg_rgb444_test <= 16'h1204;
               // 12: COM7 Common Control 7
               // [1]=0: disable color bar (dont know what it is
               //        because a 0 also shows the test 8bar
               // [2,0]="10": Output format RGB 
      6'h03:
        reg_rgb444_test <= 16'h0900; 
               // 09:COM2 Common Control 2. Default: 01 
               // [7:5] : Reserved
               // [4]   : Soft sleep mode
               // [3:2] : Reserved
               // [1:0] : output drive capability, to increase IOL/OH drive
               //   00: 1x
               //   01: 2x
               //   10: 3x
               //   11: 4x
      6'h04:
        reg_rgb444_test <= 16'h40F0;
               // 40: COM15 Full 0-255 output, RGB 444
               // [7:6]="11": Full output range
               // [5:4]="11": RGB 555 only if RGB444 is low
               //             so, this is to have RGB444
               // [3:0]=0: Reserved
      6'h05:
        reg_rgb444_test <= 16'h8C02;
               // 8C: RGB444
               // [7:2]=0: Reserved
               // [1]=1: Enable RGB444
               // [0]=0: word format: xR GB
               //    =1: word format: RG Bx
      6'h06:
        reg_rgb444_test <= 16'h1180;
               // 11: CLKRC Internal Clock
               // [7]=1: Reserved  **IG says 0, but 1 seems stable
               // [6]=0: Use pre-scale
               // [5:0]: Interal clock pre-scalar
               //    F(internal clk) = F(input clk)/([5:0]+1)
               // [5:0]= 0: No prescale (internal clk)

      6'h07:
        //reg_rgb444_test <= 16'h0F43; // 0F: COM6 Common Control 6
        reg_rgb444_test <= 16'h0F4B;
               // 0F: COM6 Common Control 6
               // [7]=0: Disable HREF at optical blank
               // [1]=1: Resets timming when format changes
               // others reserved
               // [3] = 1 (reserved) hamster

      6'h08:
        reg_rgb444_test <= 16'h1E37;
             // MVFP Mirror/flip enable. Default 00
             // [7:6]= 00 : reserved
             // [5]= 1 : Mirror image
             // [4]= 1 : Flip image
             // [3] : Reserved
             // [2] : Black Sun Enable
             // [1:0] : Reserved

      // color from hamster
      6'h09:
        reg_rgb444_test <= 16'h1438;
             // COM9 reserved: default 4A
             // [6:4] Automatic Gain Ceiling - maximum AGC value
             //   100 : 32x (default)
             //   011 : 16x (default)
             // [3:1] Reserved (default 101)
             //   100 : Hamster

     //x"4F40", --x"4fb3", -- MTX1  - colour conversion matrix
     //x"5034", --x"50b3", -- MTX2  - colour conversion matrix
     //x"510C", --x"5100", -- MTX3  - colour conversion matrix
     //x"5217", --x"523d", -- MTX4  - colour conversion matrix
     //x"5329", --x"53a7", -- MTX5  - colour conversion matrix
     //x"54E4", -- MTX6  - colour conversion matrix
     //x"581E", --x"589e", -- MTXS  - Matrix sign and auto contrast

      6'h0A:
        reg_rgb444_test <= 16'h4FB3; // MTX1  - colour conversion matrix
      6'h0B:
        reg_rgb444_test <= 16'h50B3; // MTX2  - colour conversion matrix
      6'h0C:
        reg_rgb444_test <= 16'h5100; // MTX3  - colour conversion matrix
      6'h0D:
        reg_rgb444_test <= 16'h523D; // MTX4  - colour conversion matrix
      6'h0E:
        reg_rgb444_test <= 16'h53A7; // MTX5  - colour conversion matrix
      6'h0F:
        reg_rgb444_test <= 16'h54E4; // MTX6  - colour conversion matrix
      6'h10:
        reg_rgb444_test <= 16'h589E; // MTXS  - Matrix sign and auto contrast

      6'h11:
        reg_rgb444_test <= 16'h3DC0; // COM13: default 88
              // [7]=1 : Gamma enable (defaul)
              // [6]=1 : UV Saturation Level - UV autoadjustment
              // [5:1]: Reserved
              // [0]: UV swap


    // Trial and error
      6'h12:
        reg_rgb444_test <= 16'hB084; // recommended TFG (reserved)
    // hamster
      6'h13:
        reg_rgb444_test <= 16'h0E61; // COM5 reserved: default 01
      6'h14:
        reg_rgb444_test <= 16'h1602; // reserved
      6'h15:
        reg_rgb444_test <= 16'h2102; // ADCCTR0 (reserved): default 02 
      6'h16:
        reg_rgb444_test <= 16'h2291; // ADCCTR1 (reserved): default 01 
      6'h17:
        reg_rgb444_test <= 16'h2907; // RSVD (reserved): default XX 
      6'h18:
        reg_rgb444_test <= 16'h330B; // CHLF Array Current Control (reserved):
                                     // default 08 
      6'h19:
        reg_rgb444_test <= 16'h350B; // RSVD (reserved): default XX
      6'h1A:
        reg_rgb444_test <= 16'h371D; // ADC (reserved): default 3F
      6'h1B:
        reg_rgb444_test <= 16'h3871; // ACOM (reserved): default 01.
                                     // ADC and Analog Common Mode Control
      6'h1C:
        reg_rgb444_test <= 16'h392A; // OFON (reserved): default 00.
                                     // ADC Offset Control 

      6'h1D:
        reg_rgb444_test <= 16'h3C78; // COM12 (default 69)
             // [7]= 0: No HREF when VSYNC is low
             // [6:0]: Reserved
      6'h1E:
        reg_rgb444_test <= 16'h4D40; // RSVD (reserved): default XX
      6'h1F:
        reg_rgb444_test <= 16'h4E20; // RSVD (reserved): default XX
      6'h20:
        reg_rgb444_test <= 16'h7410; // REG74 default 00
             // [4]=1 : Digital Gain control by REG74[1:0]
             // [1:0]=00: Bypass
      6'h21:
        reg_rgb444_test <= 16'h8D4F; // RSVD (reserved): default XX
      6'h22:
        reg_rgb444_test <= 16'h8E00; // RSVD (reserved): default XX
      6'h23:
        reg_rgb444_test <= 16'h8F00; // RSVD (reserved): default XX
      6'h24:
        reg_rgb444_test <= 16'h9000; // RSVD (reserved): default XX
      6'h25:
        reg_rgb444_test <= 16'h9100; // RSVD (reserved): default XX
      6'h26:
        reg_rgb444_test <= 16'h9600; // RSVD (reserved): default XX
      6'h27:
        reg_rgb444_test <= 16'h9A00; // RSVD (reserved): default XX
      6'h28:
        reg_rgb444_test <= 16'hB10C; // ABLC1: default 00.
             // Automatic Black Level Calibration
             // [3]=1 : Reserved (hamster=1)
             // [2]=1 : Enable ABLC
      6'h29:
        reg_rgb444_test <= 16'hB20E; // RSVD (reserved): default XX
      6'h2A:
        reg_rgb444_test <= 16'hB382; // THL_ST: ABLC Target: default 80
             // Lower limit of black leve +0x80
      6'h2B:
        reg_rgb444_test <= 16'hB80A; // RSVD (reserved): default XX


      // ---------

      6'h2C:
        reg_rgb444_test <= 16'h1520; // 15: COM10 Common Control 10
                             // [7]=0: Reserved
                             // [6]=0: Use HREF not HSYNC
                             // [5]=1: PCLK doesnt toggle during horizontl blank
                             // others default
      6'h2D:
        reg_rgb444_test <= 16'h1711; // HSTART HREF start high 8-bit.
              // The first pixels flicker
              // 1700; // HSTART HREF start high 8-bit.
              // For windowing. Dont want to do
      6'h2E:
        reg_rgb444_test <= 16'h1800; // HSTOP HREF end high 8-bit.
             // For windowing. Dont want to do
      6'h2F:
        reg_rgb444_test <= 16'h1900; // VSTRT VREF start high 8-bit.
             // For windowing. Dont want to do
      6'h30:
        reg_rgb444_test <= 16'h1A00; // VSTOP VREF end high 8-bit.
             // For windowing. Dont want to do
      6'h31:
        reg_rgb444_test <= 16'h3200; // HREF Control
             // [7:6] : HREF edge offset to data ouput
             // [5:3] : HREF end LSB (high 8MSB at HSTOP)
             // [2:0] : HREF start LSB (high 8MSB at HSTART


      // -- QQVGA
      6'h32:
        reg_rgb444_test <= 16'h0C04; // 0C: COM3 Common Control 3
                             // [3]=1: Enable scale (for QQVGA/2)
                             // [2]=0: Disable DCW
                             // others default
      6'h33:
        reg_rgb444_test <= 16'h3E1A; // 3E: COM14 Common Control 14
                             //    Scaling can be adjusted manually
                             // [7:5]: Reserved
                             // [4]=1: Scaling PCLK and DCW enabled
                             //        Controlled by [2:0] and SCALING_PCLK_DIV
                             // [3]=1: Manual scaling enabled for predefined
                             //        modes such QVGA
                             // [2:0] PCLK divided when COM14[4]=1
                             // [2:0]=010: Divided by 4-> QQVGA: 160x120
      6'h34:
        reg_rgb444_test <= 16'h703A; // 70: SCALING_XSC
                             // [7]: test_pattern[0], works with test_pattern[1]
                             //  00: No test output                            
                             //  01: Shifting "1"
                             //  10: 8-bar color bar
                             //  11: Fade to gray color bar
                             // [7]= 0 -> 8-bar color bar (test_pattern[1]=1)
                             // [6:0]: default horizontal scale factor
      6'h35:
        reg_rgb444_test <= 16'h71B5; // 71: SCALING_YSC
                             // [7]: test_pattern[1], works with test_pattern[0]
                             //  00: No test output                            
                             //  01: Shifting "1"
                             //  10: 8-bar color bar
                             //  11: Fade to gray color bar
                             // [7]= 1 -> 8-bar color bar (test_pattern[0]=0)
                             // [6:0]: default vertical scale factor
      6'h36:
        reg_rgb444_test <= 16'h7222; // 72: SCALING_DCWCTR DCW Control
                             // [7]=0: Vertical average calc truncation(default)
                             // [6]=0: Vertical truncation downsampling(default)
                             // [5:4]: Vertical down sampling rate
                             // [5:4]=10: Vertical down sampling by 4->QQVGA
                             // [3]=0: Horztal average calc truncation(default)
                             // [2]=0: Horztal truncation downsampling(default)
                             // [1:0]: Horztal down sampling rate
                             // [1:0]=10: Horztal down sampling by 4->QQVGA
      6'h37:
        reg_rgb444_test <= 16'h73F2; // 73: SCALING_PCLK_DIV
                             // [7:4]=F: Reserved, and manual says default is 0
                             //          but IG says F
                             // [3]=0: Enable clk divider for DSP scale control
                             // [2:0]=010: Divided by 4 -> QQVGA
      6'h38:
        reg_rgb444_test <= 16'hA202; // A2: SCALING_PCLK_DELAY Pixel Clock Delay
                             // [7]: Reserved
                             // [6:0]=02: Default scaling ouput delay
      //  end QQVGA
      6'h39:
        reg_rgb444_test <= 16'hFFFF;  // FINISH CONDITION, register FF doesnt exist
      default:
        reg_rgb444_test <= 16'hFFFF;  // FINISH CONDITION
    endcase
  end


  always @ (cnt_reg) begin
    // *IG means Implementation guide
    case (cnt_reg)
      6'h00:
        reg_rgb444 <= 16'h1280;
               // 12: COM7 Common Control 7
               // [7]=1: Reset all registers to default values
      6'h01:
        reg_rgb444 <= 16'h1280;
               // 12: COM7 Common Control 7
               // [7]=1: Reset all registers to default values
      6'h02:
        reg_rgb444 <= 16'h1204;
               // 12: COM7 Common Control 7
               // [1]=0: disable color bar (dont know what it is
               //        because a 0 also shows the test 8bar
               // [2,0]="10": Output format RGB 
      6'h03:
        reg_rgb444 <= 16'h0900; 
               // 09:COM2 Common Control 2. Default: 01 
               // [7:5] : Reserved
               // [4]   : Soft sleep mode
               // [3:2] : Reserved
               // [1:0] : output drive capability, to increase IOL/OH drive
               //   00: 1x : works best
               //   01: 2x
               //   10: 3x
               //   11: 4x
      6'h04:
        reg_rgb444 <= 16'h40F0;
               // 40: COM15 Full 0-255 output, RGB 444
               // [7:6]="11": Full output range
               // [5:4]="11": RGB 555 only if RGB444 is low
               //             so, this is to have RGB444
               // [3:0]=0: Reserved
      6'h05:
        reg_rgb444 <= 16'h8C02;
               // 8C: RGB444
               // [7:2]=0: Reserved
               // [1]=1: Enable RGB444
               // [0]=0: word format: xR GB
               //    =1: word format: RG Bx
      6'h06:
        reg_rgb444 <= 16'h1180;
               // 11: CLKRC Internal Clock
               // [7]=1: Reserved  **IG says 0, but 1 seems stable
               // [6]=0: Use pre-scale
               // [5:0]: Interal clock pre-scalar
               //    F(internal clk) = F(input clk)/([5:0]+1)
               // [5:0]= 0: No prescale (internal clk)

      6'h07:
        //reg_rgb444 <= 16'h0F43; // 0F: COM6 Common Control 6
        reg_rgb444 <= 16'h0F4B;
               // 0F: COM6 Common Control 6
               // [7]=0: Disable HREF at optical blank
               // [1]=1: Resets timming when format changes
               // others reserved
               // [3] = 1 (reserved) hamster

      6'h08:
        reg_rgb444 <= 16'h1E37;
             // MVFP Mirror/flip enable. Default 00
             // [7:6]= 00 : reserved
             // [5]= 1 : Mirror image
             // [4]= 1 : Flip image
             // [3] : Reserved
             // [2] : Black Sun Enable
             // [1:0] : Reserved

      // color from hamster
      6'h09:
        reg_rgb444 <= 16'h1438;
             // COM9 reserved: default 4A
             // [6:4] Automatic Gain Ceiling - maximum AGC value
             //   100 : 32x (default)
             //   011 : 16x (default)
             // [3:1] Reserved (default 101)
             //   100 : Hamster

     //x"4F40", --x"4fb3", -- MTX1  - colour conversion matrix
     //x"5034", --x"50b3", -- MTX2  - colour conversion matrix
     //x"510C", --x"5100", -- MTX3  - colour conversion matrix
     //x"5217", --x"523d", -- MTX4  - colour conversion matrix
     //x"5329", --x"53a7", -- MTX5  - colour conversion matrix
     //x"54E4", -- MTX6  - colour conversion matrix
     //x"581E", --x"589e", -- MTXS  - Matrix sign and auto contrast

      6'h0A:
        reg_rgb444 <= 16'h4FB3; // MTX1  - colour conversion matrix
      6'h0B:
        reg_rgb444 <= 16'h50B3; // MTX2  - colour conversion matrix
      6'h0C:
        reg_rgb444 <= 16'h5100; // MTX3  - colour conversion matrix
      6'h0D:
        reg_rgb444 <= 16'h523D; // MTX4  - colour conversion matrix
      6'h0E:
        reg_rgb444 <= 16'h53A7; // MTX5  - colour conversion matrix
      6'h0F:
        reg_rgb444 <= 16'h54E4; // MTX6  - colour conversion matrix
      6'h10:
        reg_rgb444 <= 16'h589E; // MTXS  - Matrix sign and auto contrast

      6'h11:
        reg_rgb444 <= 16'h3DC0; // COM13: default 88
              // [7]=1 : Gamma enable (defaul)
              // [6]=1 : UV Saturation Level - UV autoadjustment
              // [5:1]: Reserved
              // [0]: UV swap


    // Trial and error
      6'h12:
        reg_rgb444 <= 16'hB084; // recommended TFG (reserved)
    // hamster
      6'h13:
        reg_rgb444 <= 16'h0E61; // COM5 reserved: default 01
      6'h14:
        reg_rgb444 <= 16'h1602; // reserved
      6'h15:
        reg_rgb444 <= 16'h2102; // ADCCTR0 (reserved): default 02 
      6'h16:
        reg_rgb444 <= 16'h2291; // ADCCTR1 (reserved): default 01 
      6'h17:
        reg_rgb444 <= 16'h2907; // RSVD (reserved): default XX 
      6'h18:
        reg_rgb444 <= 16'h330B; // CHLF Array Current Control (reserved):
                                     // default 08 
      6'h19:
        reg_rgb444 <= 16'h350B; // RSVD (reserved): default XX
      6'h1A:
        reg_rgb444 <= 16'h371D; // ADC (reserved): default 3F
      6'h1B:
        reg_rgb444 <= 16'h3871; // ACOM (reserved): default 01.
                                     // ADC and Analog Common Mode Control
      6'h1C:
        reg_rgb444 <= 16'h392A; // OFON (reserved): default 00.
                                     // ADC Offset Control 

      6'h1D:
        reg_rgb444 <= 16'h3C78; // COM12 (default 69)
             // [7]= 0: No HREF when VSYNC is low
             // [6:0]: Reserved
      6'h1E:
        reg_rgb444 <= 16'h4D40; // RSVD (reserved): default XX
      6'h1F:
        reg_rgb444 <= 16'h4E20; // RSVD (reserved): default XX
      6'h20:
        reg_rgb444 <= 16'h7410; // REG74 default 00
             // [4]=1 : Digital Gain control by REG74[1:0]
             // [1:0]=00: Bypass
      6'h21:
        reg_rgb444 <= 16'h8D4F; // RSVD (reserved): default XX
      6'h22:
        reg_rgb444 <= 16'h8E00; // RSVD (reserved): default XX
      6'h23:
        reg_rgb444 <= 16'h8F00; // RSVD (reserved): default XX
      6'h24:
        reg_rgb444 <= 16'h9000; // RSVD (reserved): default XX
      6'h25:
        reg_rgb444 <= 16'h9100; // RSVD (reserved): default XX
      6'h26:
        reg_rgb444 <= 16'h9600; // RSVD (reserved): default XX
      6'h27:
        reg_rgb444 <= 16'h9A00; // RSVD (reserved): default XX
      6'h28:
        reg_rgb444 <= 16'hB10C; // ABLC1: default 00.
             // Automatic Black Level Calibration
             // [3]=1 : Reserved (hamster=1)
             // [2]=1 : Enable ABLC
      6'h29:
        reg_rgb444 <= 16'hB20E; // RSVD (reserved): default XX
      6'h2A:
        reg_rgb444 <= 16'hB382; // THL_ST: ABLC Target: default 80
             // Lower limit of black leve +0x80
      6'h2B:
        reg_rgb444 <= 16'hB80A; // RSVD (reserved): default XX


      // ---------

      6'h2C:
        reg_rgb444 <= 16'h1520; // 15: COM10 Common Control 10
                             // [7]=0: Reserved
                             // [6]=0: Use HREF not HSYNC
                             // [5]=1: PCLK doesnt toggle during horizontl blank
                             // others default
      6'h2D:
        reg_rgb444 <= 16'h1711; // HSTART HREF start high 8-bit.
              // The first pixels flicker
              // 1700; // HSTART HREF start high 8-bit.
              // For windowing. Dont want to do
      6'h2E:
        reg_rgb444 <= 16'h1800; // HSTOP HREF end high 8-bit.
             // For windowing. Dont want to do
      6'h2F:
        reg_rgb444 <= 16'h1900; // VSTRT VREF start high 8-bit.
             // For windowing. Dont want to do
      6'h30:
        reg_rgb444 <= 16'h1A00; // VSTOP VREF end high 8-bit.
             // For windowing. Dont want to do
      6'h31:
        reg_rgb444 <= 16'h3200; // HREF Control
             // [7:6] : HREF edge offset to data ouput
             // [5:3] : HREF end LSB (high 8MSB at HSTOP)
             // [2:0] : HREF start LSB (high 8MSB at HSTART


      // -- QVGA2
      6'h32:
        reg_rgb444 <= 16'h0C04; // 0C: COM3 Common Control 3
                             // [3]=1: Enable scale (for QVGA/2)
                             // [2]=0: Disable DCW
                             // others default
      6'h33:
        reg_rgb444 <= 16'h3E1A; // 3E: COM14 Common Control 14
                             //    Scaling can be adjusted manually
                             // [7:5]: Reserved
                             // [4]=1: Scaling PCLK and DCW enabled
                             //        Controlled by [2:0] and SCALING_PCLK_DIV
                             // [3]=1: Manual scaling enabled for predefined
                             //        modes such QVGA
                             // [2:0] PCLK divided when COM14[4]=1
                             // [2:0]=010: Divided by 4-> QQVGA: 160x120
      6'h34:
        reg_rgb444 <= 16'h703A; // 70: SCALING_XSC
                             // [7]: test_pattern[0], works with test_pattern[1]
                             //  00: No test output  <-
                             //  01: Shifting "1"
                             //  10: 8-bar color bar
                             //  11: Fade to gray color bar
                             // [7]= 0 -> 8-bar color bar (test_pattern[1]=1)
                             // [6:0]: default horizontal scale factor
      6'h35:
        reg_rgb444 <= 16'h7135; // 71: SCALING_YSC
                             // [7]: test_pattern[1], works with test_pattern[0]
                             //  00: No test output  <-
                             //  01: Shifting "1"
                             //  10: 8-bar color bar
                             //  11: Fade to gray color bar
                             // [7]= 1 -> 8-bar color bar (test_pattern[0]=0)
                             // [6:0]: default vertical scale factor
      6'h36:
        reg_rgb444 <= 16'h7222; // 72: SCALING_DCWCTR DCW Control
                             // [7]=0: Vertical average calc truncation(default)
                             // [6]=0: Vertical truncation downsampling(default)
                             // [5:4]: Vertical down sampling rate
                             // [5:4]=10: Vertical down sampling by 4->QQVGA
                             // [3]=0: Horztal average calc truncation(default)
                             // [2]=0: Horztal truncation downsampling(default)
                             // [1:0]: Horztal down sampling rate
                             // [1:0]=10: Horztal down sampling by 4->QQVGA
      6'h37:
        reg_rgb444 <= 16'h73F2; // 73: SCALING_PCLK_DIV
                             // [7:4]=F: Reserved, and manual says default is 0
                             //          but IG says F
                             // [3]=0: Enable clk divider for DSP scale control
                             // [2:0]=010: Divided by 4 -> QQVGA
      6'h38:
        reg_rgb444 <= 16'hA202; // A2: SCALING_PCLK_DELAY Pixel Clock Delay
                             // [7]: Reserved
                             // [6:0]=02: Default scaling ouput delay
      //  end QQVGA
      6'h39:
        reg_rgb444 <= 16'hFFFF;  // FINISH CONDITION, register FF doesnt exist
      default:
        reg_rgb444 <= 16'hFFFF;  // FINISH CONDITION
    endcase
  end





  always @ (cnt_reg) begin
    // *IG means Implementation guide
    case (cnt_reg)
      6'h00:
        reg_yuv422_test <= 16'h1280;
               // 12: COM7 Common Control 7
               // [7]=1: Reset all registers to default values
      6'h01:
        reg_yuv422_test <= 16'h1280;
               // 12: COM7 Common Control 7
               // [7]=1: Reset all registers to default values
      6'h02:
        reg_yuv422_test <= 16'h1200;
               // 12: COM7 Common Control 7
               // [2,0]= 00 : Output format YUV 
      6'h03:
        reg_yuv422_test <= 16'h0900; 
               // 09:COM2 Common Control 2. Default: 01 
               // [7:5] : Reserved
               // [4]   : Soft sleep mode
               // [3:2] : Reserved
               // [1:0] : output drive capability, to increase IOL/OH drive
               //   00: 1x : works best
               //   01: 2x
               //   10: 3x
               //   11: 4x
      6'h04:
        reg_yuv422_test <= 16'h40C0;
               // 40: COM15 Full 0-255 output, RGB 444
               // [7:6] = 11 : Full output range
               // [5:4] = x0 : Normal RGB output and YUV
               // [5:4] = 11: RGB 55 only if RGB444 is low
               // [3:0] = 0:  Reserved 
      6'h05:
        reg_yuv422_test <= 16'h8C00;
               // 8C: RGB444
               // [7:2]=0: Reserved
               // [1]=1: Enable RGB444
               // [0]=0: word format: xR GB
      6'h06:
        reg_yuv422_test <= 16'h1180;
               // 11: CLKRC Internal Clock
               // [7]=1: Reserved  **IG says 0, but 1 seems stable
               // [6]=0: Use pre-scale
               // [5:0]: Interal clock pre-scalar
               //    F(internal clk) = F(input clk)/([5:0]+1)
               // [5:0]= 0: No prescale (internal clk)

      6'h07:
        //reg_yuv422_test <= 16'h0F43; // 0F: COM6 Common Control 6
        reg_yuv422_test <= 16'h0F4B;  //** check 0F4B
               // 0F: COM6 Common Control 6
               // [7]=0: Disable HREF at optical blank
               // [1]=1: Resets timming when format changes
               // others reserved
               // [3] = 1 (reserved) hamster

      // check
      6'h08:
        reg_yuv422_test <= 16'h1E37;
             // MVFP Mirror/flip enable. Default 00
             // [7:6]= 00 : reserved
             // [5]= 1 : Mirror image
             // [4]= 1 : Flip image
             // [3] : Reserved
             // [2] : Black Sun Enable
             // [1:0] : Reserved

      // check

      // check
      6'h09:
        reg_yuv422_test <= 16'h3DC0; // COM13: default 88
              // [7]=1 : Gamma enable (defaul)
              // [6]=1 : UV Saturation Level - UV autoadjustment
              // [5:1]: Reserved
              // [0]: UV swap

      // ---------

      6'h0A:
        reg_yuv422_test <= 16'h1520; // 15: COM10 Common Control 10
                             // [7]=0: Reserved
                             // [6]=0: Use HREF not HSYNC
                             // [5]=1: PCLK doesnt toggle during horizontl blank
                             // others default
      6'h0B:
        reg_yuv422_test <= 16'h1711; // HSTART HREF start high 8-bit.
              // The first pixels flicker
              // 1700; // HSTART HREF start high 8-bit.
              // For windowing. Dont want to do
      6'h0C:
        reg_yuv422_test <= 16'h1800; // HSTOP HREF end high 8-bit.
             // For windowing. Dont want to do
      6'h0D:
        reg_yuv422_test <= 16'h1900; // VSTRT VREF start high 8-bit.
             // For windowing. Dont want to do
      6'h0E:
        reg_yuv422_test <= 16'h1A00; // VSTOP VREF end high 8-bit.
             // For windowing. Dont want to do
      6'h0F:
        reg_yuv422_test <= 16'h3200; // HREF Control
             // [7:6] : HREF edge offset to data ouput
             // [5:3] : HREF end LSB (high 8MSB at HSTOP)
             // [2:0] : HREF start LSB (high 8MSB at HSTART

      6'h10:
        reg_yuv422_test <= 16'h3A04; // TLSB: Line buffer test option
             // (default 0C)
             // [7:6] : reserved
             // [5]   : negative image enable
             // [5]=0 : Normal image 
             // [4]=0 : Use normal UV output
             // [3]   : Output sequence with COM13[1]
             //      TSLB[3], COM13[1]:
             //    00: Y U Y V
             //    01: Y U Y V
             //    10: U Y V Y
             //    11: V Y U Y
             // [2:1] : Reserved




      // -- QQVGA
      6'h11:
        reg_yuv422_test <= 16'h0C04; // 0C: COM3 Common Control 3
                             // [3]=1: Enable scale (for QQVGA)
                             // [2]=0: Disable DCW
                             // others default
      6'h12:
        reg_yuv422_test <= 16'h3E1A; // 3E: COM14 Common Control 14
                             //    Scaling can be adjusted manually
                             // [7:5]: Reserved
                             // [4]=1: Scaling PCLK and DCW enabled
                             //        Controlled by [2:0] and SCALING_PCLK_DIV
                             // [3]=1: Manual scaling enabled for predefined
                             //        modes such QVGA
                             // [2:0] PCLK divided when COM14[4]=1
                             // [2:0]=010: Divided by 4-> QQVGA: 160x120
      6'h13:
        reg_yuv422_test <= 16'h703A; // 70: SCALING_XSC
                             // [7]: test_pattern[0], works with test_pattern[1]
                             //  00: No test output                            
                             //  01: Shifting "1"
                             //  10: 8-bar color bar
                             //  11: Fade to gray color bar
                             // [7]= 0 -> 8-bar color bar (test_pattern[1]=1)
                             // [6:0]: default horizontal scale factor
      6'h14:
        reg_yuv422_test <= 16'h71B5; // 71: SCALING_YSC
                             // [7]: test_pattern[1], works with test_pattern[0]
                             //  00: No test output                            
                             //  01: Shifting "1"
                             //  10: 8-bar color bar
                             //  11: Fade to gray color bar
                             // [7]= 1 -> 8-bar color bar (test_pattern[0]=0)
                             // [6:0]: default vertical scale factor
      6'h15:
        reg_yuv422_test <= 16'h7222; // 72: SCALING_DCWCTR DCW Control
                             // [7]=0: Vertical average calc truncation(default)
                             // [6]=0: Vertical truncation downsampling(default)
                             // [5:4]: Vertical down sampling rate
                             // [5:4]=10: Vertical down sampling by 8->QQVGA
                             // [3]=0: Horztal average calc truncation(default)
                             // [2]=0: Horztal truncation downsampling(default)
                             // [1:0]: Horztal down sampling rate
                             // [1:0]=10: Horztal down sampling by 8->QQVGA
      6'h16:
        reg_yuv422_test <= 16'h73F2; // 73: SCALING_PCLK_DIV
                             // [7:4]=F: Reserved, and manual says default is 0
                             //          but IG says F
                             // [3]=0: Enable clk divider for DSP scale control
                             // [2:0]=010: Divided by 4 -> QQVGA
      6'h17:
        reg_yuv422_test <= 16'hA202; // A2: SCALING_PCLK_DELAY Pixel Clock Delay
                             // [7]: Reserved
                             // [6:0]=02: Default scaling ouput delay
      //  end QQVGA
      6'h18:
        reg_yuv422_test <= 16'hFFFF;  // FINISH CONDITION, register FF doesnt exist
      default:
        reg_yuv422_test <= 16'hFFFF;  // FINISH CONDITION
    endcase
  end





  always @ (cnt_reg) begin
    // *IG means Implementation guide
    case (cnt_reg)
      6'h00:
        reg_yuv422 <= 16'h1280;
               // 12: COM7 Common Control 7
               // [7]=1: Reset all registers to default values
      6'h01:
        reg_yuv422 <= 16'h1280;
               // 12: COM7 Common Control 7
               // [7]=1: Reset all registers to default values
      6'h02:
        reg_yuv422 <= 16'h1200;
               // 12: COM7 Common Control 7
               // [2,0]= 00 : Output format YUV 
      6'h03:
        reg_yuv422 <= 16'h0900; 
               // 09:COM2 Common Control 2. Default: 01 
               // [7:5] : Reserved
               // [4]   : Soft sleep mode
               // [3:2] : Reserved
               // [1:0] : output drive capability, to increase IOL/OH drive
               //   00: 1x
               //   01: 2x
               //   10: 3x
               //   11: 4x
      6'h04:
        reg_yuv422 <= 16'h40C0;
               // 40: COM15 Full 0-255 output, RGB 444
               // [7:6] = 11 : Full output range
               // [5:4] = x0 : Normal RGB output and YUV
               // [5:4] = 11: RGB 55 only if RGB444 is low
               // [3:0] = 0:  Reserved 
      6'h05:
        reg_yuv422 <= 16'h8C00;
               // 8C: RGB444
               // [7:2]=0: Reserved
               // [1]=1: Enable RGB444
               // [0]=0: word format: xR GB
      6'h06:
        reg_yuv422 <= 16'h1180;
               // 11: CLKRC Internal Clock
               // [7]=1: Reserved  **IG says 0, but 1 seems stable
               // [6]=0: Use pre-scale
               // [5:0]: Interal clock pre-scalar
               //    F(internal clk) = F(input clk)/([5:0]+1)
               // [5:0]= 0: No prescale (internal clk)

      6'h07:
        //reg_yuv422 <= 16'h0F43; // 0F: COM6 Common Control 6
        reg_yuv422 <= 16'h0F4B;  //** check 0F4B
               // 0F: COM6 Common Control 6
               // [7]=0: Disable HREF at optical blank
               // [1]=1: Resets timming when format changes
               // others reserved
               // [3] = 1 (reserved) hamster

      6'h08:
        reg_yuv422 <= 16'h1E37;
             // MVFP Mirror/flip enable. Default 00
             // [7:6]= 00 : reserved
             // [5]= 1 : Mirror image
             // [4]= 1 : Flip image
             // [3] : Reserved
             // [2] : Black Sun Enable
             // [1:0] : Reserved

      6'h09:
        reg_yuv422 <= 16'h3DC0; // COM13: default 88
              // [7]=1 : Gamma enable (defaul)
              // [6]=1 : UV Saturation Level - UV autoadjustment
              // [5:1]: Reserved
              // [0]: UV swap


      // ---------

      6'h0A:
        reg_yuv422 <= 16'h1520; // 15: COM10 Common Control 10
                             // [7]=0: Reserved
                             // [6]=0: Use HREF not HSYNC
                             // [5]=1: PCLK doesnt toggle during horizontl blank
                             // others default
      6'h0B:
        reg_yuv422 <= 16'h1711; // HSTART HREF start high 8-bit.
              // The first pixels flicker
              // 1700; // HSTART HREF start high 8-bit.
              // For windowing. Dont want to do
      6'h0C:
        reg_yuv422 <= 16'h1800; // HSTOP HREF end high 8-bit.
             // For windowing. Dont want to do
      6'h0D:
        reg_yuv422 <= 16'h1900; // VSTRT VREF start high 8-bit.
             // For windowing. Dont want to do
      6'h0E:
        reg_yuv422 <= 16'h1A00; // VSTOP VREF end high 8-bit.
             // For windowing. Dont want to do
      6'h0F:
        reg_yuv422 <= 16'h3200; // HREF Control
             // [7:6] : HREF edge offset to data ouput
             // [5:3] : HREF end LSB (high 8MSB at HSTOP)
             // [2:0] : HREF start LSB (high 8MSB at HSTART

      6'h10:
        reg_yuv422 <= 16'h3A04; // TLSB: Line buffer test option
             // (default 0C)
             // [7:6] : reserved
             // [5]   : negative image enable
             // [5]=0 : Normal image 
             // [4]=0 : Use normal UV output
             // [3]   : Output sequence with COM13[1]
             //      TSLB[3], COM13[1]:
             //    00: Y U Y V
             //    01: Y U Y V
             //    10: U Y V Y
             //    11: V Y U Y
             // [2:1] : Reserved




      // -- QQVGA
      6'h11:
        reg_yuv422 <= 16'h0C04; // 0C: COM3 Common Control 3
                             // [3]=1: Enable scale (for QQVGA)
                             // [2]=0: Disable DCW
                             // others default
      6'h12:
        reg_yuv422 <= 16'h3E1A; // 3E: COM14 Common Control 14
                             //    Scaling can be adjusted manually
                             // [7:5]: Reserved
                             // [4]=1: Scaling PCLK and DCW enabled
                             //        Controlled by [2:0] and SCALING_PCLK_DIV
                             // [3]=1: Manual scaling enabled for predefined
                             //        modes such QVGA
                             // [2:0] PCLK divided when COM14[4]=1
                             // [2:0]=010: Divided by 4-> QQVGA: 160x120
      6'h13:
        reg_yuv422 <= 16'h703A; // 70: SCALING_XSC
                             // [7]: test_pattern[0], works with test_pattern[1]
                             //  00: No test output <-
                             //  01: Shifting "1"
                             //  10: 8-bar color bar
                             //  11: Fade to gray color bar
                             // [7]= 0 -> 8-bar color bar (test_pattern[1]=1)
                             // [6:0]: default horizontal scale factor
      6'h14:
        reg_yuv422 <= 16'h7135; // 71: SCALING_YSC
                             // [7]: test_pattern[1], works with test_pattern[0]
                             //  00: No test output  <-
                             //  01: Shifting "1"
                             //  10: 8-bar color bar
                             //  11: Fade to gray color bar
                             // [7]= 1 -> 8-bar color bar (test_pattern[0]=0)
                             // [6:0]: default vertical scale factor
      6'h15:
        reg_yuv422 <= 16'h7222; // 72: SCALING_DCWCTR DCW Control
                             // [7]=0: Vertical average calc truncation(default)
                             // [6]=0: Vertical truncation downsampling(default)
                             // [5:4]: Vertical down sampling rate
                             // [5:4]=10: Vertical down sampling by 4->QQVGA
                             // [3]=0: Horztal average calc truncation(default)
                             // [2]=0: Horztal truncation downsampling(default)
                             // [1:0]: Horztal down sampling rate
                             // [1:0]=10: Horztal down sampling by 4->QQVGA
      6'h16:
        reg_yuv422 <= 16'h73F2; // 73: SCALING_PCLK_DIV
                             // [7:4]=F: Reserved, and manual says default is 0
                             //          but IG says F
                             // [3]=0: Enable clk divider for DSP scale control
                             // [2:0]=010: Divided by 4 -> QQVGA
      6'h17:
        reg_yuv422 <= 16'hA202; // A2: SCALING_PCLK_DELAY Pixel Clock Delay
                             // [7]: Reserved
                             // [6:0]=02: Default scaling ouput delay
      //  end QQVGA
      6'h18:
        reg_yuv422 <= 16'hFFFF;  // FINISH CONDITION, register FF doesnt exist
      default:
        reg_yuv422 <= 16'hFFFF;  // FINISH CONDITION
    endcase
  end



  // camera system clock:
  //     freq   :  min: 10 MHz  -- typ: 24 MHz  -- Max: 48 MHz
  //     Period : max: 100 ns   -- typ: 42 ns   -- Max: 21 ns
  // duty cycle between 45% and 55%
  // Since our clock is 20 ns (50 MHz), we have to divide frequency by:
  //  2: 25 MHz - 40 ns
  //  * 4: 12.5 MHz - 80 ns
  always @ (posedge rst, posedge clk)
  begin
    if (rst)
      cnt_cam_clk <= 0;
    else begin
      if (cnt_cam_clk == 3'b011)
        cnt_cam_clk <= 0;
      else
        cnt_cam_clk <= cnt_cam_clk + 1;
    end
  end

  // when cnt_cam_clk = 0 | 1 => '0', when 2 | 3 => '1'
  assign ov7670_clk = cnt_cam_clk[1]; // divide by 4

  // camera reset and power down
  assign ov7670_pwdn  = 1'b0;

  //------ controlling the registers to be sent ------------

  assign id        = c_id_write; // 0x21
  assign addr_aux  = reg_i[15:8];
  assign addr      = addr_aux;
  assign data_wr   = reg_i[7:0];


  assign ov7670_rst_n   = cam_rst_n;
  assign done      = alltx_done;
  assign start_tx  = start_tx_aux;

  // sequentially counts the registers to be sent to the SCCB
  always @ (posedge rst, posedge clk)
  begin
    if (rst)
      cnt_reg <= 0;
    else begin
      if (resend || mode_change)
        cnt_reg <= 0; // start again sending the sequence
      else if (~alltx_done) begin
        if (start_tx_aux)
          cnt_reg <= cnt_reg + 1;
      end
    end
  end
        
  // instead of comparing addr_aux = 16'hFF, to simplify, since there is no
  // address in F ("1111"), it can be compared
  assign alltx_done = (addr_aux[7:4] == 4'b1111) ? 1'b1 : 1'b0; 

  always @ (posedge rst, posedge clk)
  begin
    if (rst) begin
      rgbmode_old <= 1'b1; //starts in RGB mode
      testmode_old <= 1'b0; //starts in normal mode
    end
    else begin
      rgbmode_old  <= rgbmode;
      testmode_old <= testmode;
    end
  end

  // ^: xor (different). So if any are different
  assign mode_change = (rgbmode ^ rgbmode_old) | (testmode ^ testmode_old);

  // without clk -> Distributed CLBS
  // reg_i <= registers(to_integer(unsigned(cnt_reg));
  // process with clk -> BRAM
  always @ (posedge rst, posedge clk)
  begin
    if (rst)
      reg_i <= 16'h1280; // reset
    else begin
      if (rgbmode) begin
        if (testmode)
          reg_i <= reg_rgb444_test;
        else
          reg_i <= reg_rgb444;
      end
      else begin
        if (testmode)
          reg_i <= reg_yuv422_test;
        else
          reg_i <= reg_yuv422;
      end
    end
  end


  // FSM sequential process
  always @ (posedge rst, posedge clk)
  begin
    if (rst)
      pr_ctrl_st <= RSTCAM_ST;
    else
      pr_ctrl_st <= nx_ctrl_st;
  end

  // FSM combinatorial process
  always @ (pr_ctrl_st or alltx_done or sccb_ready or end300ms)
  begin
    // default values
    nx_ctrl_st <= pr_ctrl_st;
    start_tx_aux <= 1'b0;
    cam_rst_n <= 1'b1; //camera reset inactive
    ena_cnt300ms <= 1'b0;
    case  (pr_ctrl_st)
      RSTCAM_ST: begin // Reset camera during 300ms
        cam_rst_n <= 1'b0; //activate reset
        ena_cnt300ms <= 1'b1;
        if (end300ms) begin
          nx_ctrl_st <= WAIT_RSTCAM_ST;
        end
      end
      WAIT_RSTCAM_ST: begin // wait 300ms for the camera to be ready to receive
        ena_cnt300ms <= 1'b1;
        if (end300ms) begin
          nx_ctrl_st <= WAIT_ST;
        end
      end
      WAIT_ST: begin // waiting for the SCCB to be available
        if (alltx_done)
          nx_ctrl_st <= DONE_ST;
        else if (sccb_ready) begin
          nx_ctrl_st <= WRITE_REG_ST;
          start_tx_aux <= 1'b1;
        end
      end
      WRITE_REG_ST: begin // writting a new register (maybe not necessary)
        ena_cnt300ms <= 1'b1;
        if (end300ms) begin
          nx_ctrl_st <= WAIT_ST;
        end
      end
      DONE_ST: // writting a new register
        if (~alltx_done) // in case of resend = '1'
          nx_ctrl_st <= RSTCAM_ST;
    endcase
  end


  // counting 300 ms at 100MHz clk: 30 million. 25 bits
  always @ (posedge rst, posedge clk)
  begin
    if (rst)
      cnt300ms <= 25'd0;
    else begin
      if (ena_cnt300ms) begin
        if (end300ms) 
            cnt300ms <= 25'd0;
        else
            cnt300ms <= cnt300ms + 1;
      end
      else
        cnt300ms <= 25'd0;
    end
  end 

  assign end300ms =  (cnt300ms == c_end300ms) ? 1'b1 : 1'b0;




endmodule

///////////////////////////////////////////////////////////
//------------------------------------------------------------------------------
//   Felipe Machado Sanchez
//   Area de Tecnologia Electronica
//   Universidad Rey Juan Carlos
//   https://github.com/felipe-m
//
//   ov7670_capture.v
//   
// clk 50 MHz
//-----------------------------------------------------------------------------

module ov7670_capture
  #(parameter
    // VGA
    //c_img_cols    = 640, // 10 bits
    //c_img_rows    = 480, //  9 bits
    //c_img_pxls    = c_img_cols * c_img_rows,
    //c_nb_line_pxls = 10, // log2i(c_img_cols-1) + 1;
    // c_nb_img_pxls = log2i(c_img_pxls-1) + 1
    //c_nb_img_pxls =  19,  //640*480=307,200 -> 2^19=524,288
    // QQVGA
    c_img_cols    = 160, // 8 bits
    c_img_rows    = 120, //  7 bits
    //c_nb_line_pxls = 8, // log2i(c_img_cols-1) + 1;
    //c_nb_img_pxls =  15,  //160*120=19.200 -> 2^15
    // QQVGA/2
    //c_img_cols    = 80, // 7 bits
    //c_img_rows    = 60, // 6 bits
    c_img_pxls    = c_img_cols * c_img_rows,
    c_nb_line_pxls = $clog2(c_img_cols), // 8 log2i(c_img_cols-1) + 1;
    c_nb_img_pxls =  $clog2(c_img_pxls), // 15  160*120=19.200 -> 2^15


    c_nb_buf_red   =  4,  // n bits for red in the buffer (memory)
    c_nb_buf_green =  4,  // n bits for green in the buffer (memory)
    c_nb_buf_blue  =  4,  // n bits for blue in the buffer (memory)
    // word width of the memory (buffer)
    c_nb_buf       =   c_nb_buf_red + c_nb_buf_green + c_nb_buf_blue
  )
  (
   input              rst,    // FPGA reset
   input              clk,    // FPGA clock: 50MHz - 20ns
    // camera pclk (byte clock) (~40ns)  
    // 2 bytes is a pixel
    input             pclk,
    input             href,
    input             vsync,
    input             rgbmode,   // RGB444 or YUV422
    input             swap_r_b,  // swaps red with blue
    output     [11:0] dataout_test,
    output reg [3:0]  led_test,
    input      [7:0]  data,
    output     [c_nb_img_pxls-1:0] addr,
    output     [c_nb_buf-1:0]      dout,
    output            we
  );

  reg        pclk_rg1, pclk_rg2;  // registered pclk
  reg        href_rg1, href_rg2;  // registered href
  reg        vsync_rg1, vsync_rg2;// registered vsync
  reg [7:0]  data_rg1, data_rg2;  //registered data

  reg        pclk_rg3, href_rg3, vsync_rg3; //3rd
  reg [7:0]  data_rg3;     // registered data 3rd

  // it seems that vsync has some spurious 
  wire       vsync_3up;

  wire       pclk_fall;
  wire       pclk_rise_prev;
  wire       pclk_rise;
  reg        pclk_rise_post;

  reg        cnt_byte; // count to 2: 2 bytes per pixel
  reg [c_nb_img_pxls-1:0]  cnt_pxl;
  // number of pixels in the previous lines, not considering the actual line
  reg [c_nb_img_pxls-1:0]  cnt_pxl_base;
  reg [c_nb_line_pxls-1:0] cnt_line_pxl;
  reg [c_nb_line_pxls-1:0] cnt_line_totpxls;

   // there should be 4 clks in a pclk (byte), but just in case, make 
   // another bit to avoid overflow and go back in 0 before time
  reg [4:0]    cnt_clk;
  reg [4:0]    cnt_pclk_max;
  reg [4:0]    cnt_pclk_max_freeze;

  parameter    c_cnt_05seg_end = 50_000_000;

  reg  [7:0]   gray;
  reg  [c_nb_buf_red-1:0]   red;
  reg  [c_nb_buf_red-1:0]   green;
  reg  [c_nb_buf_red-1:0]   blue;
   
  // to test the number of
  always @ (posedge rst, posedge clk)
  begin
    if (rst) begin
      cnt_clk <= 0;
      cnt_pclk_max <= 0;
      cnt_pclk_max_freeze <= 0;
      led_test[0] <= 1'b0;
    end
    else begin
      if (href_rg2) begin
        if (pclk_rise) begin
          cnt_clk <= 0;
          led_test[0] <= 1'b1;
          cnt_pclk_max <= cnt_clk;
          cnt_pclk_max_freeze <= cnt_pclk_max;
        end
        else
          cnt_clk <= cnt_clk + 1;
      end
      else
        cnt_clk <= cnt_clk + 1;
    end
  end

  // register 3 times all the camera inputs to synchronize
  always @ (posedge rst, posedge clk)
  begin
    if (rst) begin
      pclk_rg1  <= 1'b0;
      pclk_rg2  <= 1'b0;
      href_rg1  <= 1'b0;
      href_rg2  <= 1'b0;
      vsync_rg1 <= 1'b0;
      vsync_rg2 <= 1'b0;
      data_rg1  <= 0;
      data_rg2  <= 0;
      // 3rd to detect falling edge
      pclk_rg3  <= 1'b0;
      href_rg3  <= 1'b0;
      vsync_rg3 <= 1'b0;
      data_rg3  <= 0;
      pclk_rise_post <= 1'b0;
    end
    else begin
      pclk_rg1  <= pclk;
      pclk_rg2  <= pclk_rg1;
      href_rg1  <= href;
      href_rg2  <= href_rg1;
      vsync_rg1 <= vsync;
      vsync_rg2 <= vsync_rg1;
      data_rg1  <= data;
      data_rg2  <= data_rg1;
      // 3rd
      pclk_rg3  <= pclk_rg2;
      href_rg3  <= href_rg2;
      vsync_rg3 <= vsync_rg2;
      data_rg3  <= data_rg2;
      pclk_rise_post <= pclk_rise;
    end
  end

  // since some times it is up up to 2 cycles, has to be '1' during
  // the 3 following cycles
  assign vsync_3up = vsync_rg3 && vsync_rg2 && vsync_rg1 && vsync;

  // FPGA clock is 10ns and pclk is 40ns
  //pclk_fall <= '1' when (pclk_rg2='0' and pclk_rg3='1') else '0';
  assign pclk_fall = ((pclk_rg2 == 1'b0) && pclk_rg3)? 1'b1 : 1'b0;
  assign pclk_rise_prev = (pclk_rg1 && (pclk_rg2 == 1'b0))? 1'b1 : 1'b0;
  assign pclk_rise = (pclk_rg2 && (pclk_rg3 == 1'b0))? 1'b1 : 1'b0;

  // each pixel has 2 bytes, each byte in each pclk
  // each pixel -> 2 pclk
  always @ (posedge rst, posedge clk)
  begin
    if (rst) begin
      cnt_pxl          <= 0;
      cnt_line_pxl     <= 0;
      cnt_pxl_base     <= 0;
      cnt_line_totpxls <= 0;
      cnt_byte         <= 1'b0;
    end
    else begin
      //if vsync_rg3 = '1' then // there are some glitches
      if (vsync_3up) begin // new screen
        cnt_pxl      <= 0;
        cnt_pxl_base <= 0;
        cnt_line_pxl <= 0;
        cnt_byte     <= 1'b0;
      end
      else if (href_rg3) begin // is zero at optical blank COM[6]
        if (pclk_rise) begin
          if (cnt_byte) begin
            cnt_pxl <= cnt_pxl + 1;
            cnt_line_pxl <= cnt_line_pxl + 1;
          end
          cnt_byte <= ~cnt_byte;
        end
        if (href_rg2 == 1'b0) begin // will be a falling edge
          cnt_line_totpxls <= cnt_line_pxl; // cnt_line_totpxls is to test
          // it is not reliable to count all the pixels of a line,
          // some lines have more other less
          cnt_pxl <= cnt_pxl_base + c_img_cols;
          cnt_pxl_base <= cnt_pxl_base + c_img_cols;
          cnt_line_pxl <= 0;
        end
      end
      else begin
        cnt_byte <= 1'b0;
        cnt_line_pxl <= 0;
      end
    end
  end

  //dataout_test <= "00" & std_logic_vector(cnt_line_totpxls); // 2 + 10 bits
  assign dataout_test = {7'b0000000, cnt_pclk_max_freeze}; // 7 + 5 bits

  always @ (posedge rst, posedge clk)
  begin
    if (rst) begin
      red   <= 0;
      green <= 0;
      blue  <= 0;
      gray  <= 0;
    end
    else begin
      if (href_rg3) begin  // visible
        //if (cnt_clk == 3'b001) begin // I think this is the safest
        if (pclk_rise == 1'b1) begin
          if (cnt_byte == 1'b0) begin
            if (rgbmode) begin
              if (swap_r_b == 1'b0)begin
                //red <= data_rg3[3:0]; //:Actual
					 
					 
					 red <= data_rg3[7:4];
					 //green<= {data_rg3[2:0],1'b0};
					 end
              else
                blue <= data_rg3[3:0]; //:Actual
					 
            end
            else  // YUV (gray first byte)
              gray  <= data_rg3;
          end
          else begin
            if (rgbmode) begin
              green <= data_rg3[7:4];// :Actual
				  //green <= data_rg3[7:5];
				  
              if (swap_r_b == 1'b0)
                blue <= data_rg3[3:0]; //Actual
					 
              else
                red <= data_rg3[3:0];
            end
            //else
               // do nothing, not getting U or V
          end
        end
      end
    end
  end

  //dout <= (red & green & blue) when unsigned(sw13_rgbmode) < 3 else gray;
  assign dout = (rgbmode) ? {red, green, blue} : {4'b000, gray};
  //dout <= std_logic_vector(cnt_pxl(7 downto 0));
  assign addr = cnt_pxl;

  assign we = (href_rg3 && cnt_byte && pclk_rise_post)? 1'b1 : 1'b0;

endmodule

//////////////////////////////////////////////////////
//------------------------------------------------------------------------------
//   Felipe Machado Sanchez
//   Area de Tecnologia Electronica
//   Universidad Rey Juan Carlos
//   https://github.com/felipe-m
//
//   frame_buffer.v
//   
//-----------------------------------------------------------------------------

module frame_buffer
  #(parameter
    // VGA
    //c_img_cols    = 640, // 10 bits
    //c_img_rows    = 480, //  9 bits
    // QQVGA
    c_img_cols    = 160, // 8 bits
    c_img_rows    = 120, //  7 bits
    c_img_pxls    = c_img_cols * c_img_rows,
     c_nb_img_pxls = $clog2(c_img_pxls), // 15 -> 160x120= 19200
    // VGA
    //c_nb_img_pxls =  19,  //640*480=307,200 -> 2^19=524,288
    // QQVGA
    //c_nb_img_pxls =  15,  //160*120=19.200 -> 2^15
    // QQVGA /2
    //c_img_cols    = 80, // 7 bits
    //c_img_rows    = 60, //  6 bits
    //c_img_pxls    = c_img_cols * c_img_rows,
    //c_nb_img_pxls =  13,  //80*60=4800 -> 2^13

    c_nb_buf_red   =  4,  // n bits for red in the buffer (memory)
    c_nb_buf_green =  4,  // n bits for green in the buffer (memory)
    c_nb_buf_blue  =  4,  // n bits for blue in the buffer (memory)
    // word width of the memory (buffer)
    c_nb_buf       =   c_nb_buf_red + c_nb_buf_green + c_nb_buf_blue
  )
  (
   input                          clk,
   input                          wea,
   input      [c_nb_img_pxls-1:0] addra,
   input      [c_nb_buf-1:0]             dina,
   input      [c_nb_img_pxls-1:0] addrb,
   output reg [c_nb_buf-1:0]             doutb
   );

  reg  [c_nb_buf-1:0] ram[c_img_pxls-1:0];

  always @ (posedge clk)
  begin
    if (wea)
        ram[addra] <= dina;
    doutb <= ram[addrb];
  end

endmodule

/////////////////////////////////////////////////////////////////
//------------------------------------------------------------------------------
//
//   color_proc.v
//   Takes an image from a memory, light leds depending on red pixel position on frame
//   
//

module color_proc
  # (parameter
      // VGA
      //c_img_cols    = 640, // 10 bits
      //c_img_rows    = 480, //  9 bits
      //c_img_pxls    = c_img_cols * c_img_rows,
      //c_nb_line_pxls = 10, // log2i(c_img_cols-1) + 1;
      // c_nb_img_pxls = log2i(c_img_pxls-1) + 1
      //c_nb_img_pxls =  19,  //640*480=307,200 -> 2^19=524,288
      // QQVGA
      c_img_cols    = 160, // 8 bits
      c_img_rows    = 120, //  7 bits
      c_img_pxls    = c_img_cols * c_img_rows,
      c_nb_img_pxls = $clog2(c_img_pxls), // 15 -> 160*120=19.200 -> 2^15
      // QQVGA /2
      //c_img_cols    = 80, // 7 bits
      //c_img_rows    = 60, //  6 bits
      //c_img_pxls    = c_img_cols * c_img_rows,
      //c_nb_img_pxls = $clog2(c_img_pxls), // 13,  //80*60=4800 -> 2^13

      // number of bits of the image colums and rows
      c_nb_cols     = $clog2(c_img_cols),
      c_nb_rows     = $clog2(c_img_rows),

      // inner frame size
      c_inframe_cols = 128, // 7 bits (0 to 127) taking out 32, 16 each side
      c_inframe_rows = 104, // 7 bits (0 to 107) taking out 16, 8 each side
      // total pixels in the inner frame
      c_inframe_pxls = c_inframe_cols * c_inframe_rows, // 128x104 = 13312
      // number of bits for the number of total pixels in the inner frame
      c_nb_inframe_pxls = $clog2(c_inframe_pxls), // = 14

      // histogram
      // number of bins (buckets)
      c_hist_bins = 8, // 7:0
      // number of bits needed for the histogram bins: 8 bins -> 3 bits
      c_nb_hist_bins = $clog2(c_hist_bins), // 3 bits
      // since we have 104 rows and 8 column in each bin
      // for each bin 832 (104 x 8) is the max number: 10 bits
      c_nb_hist_val = $clog2(c_inframe_rows * (c_inframe_cols/c_hist_bins)), // = 10,

      // centroid has 8 bits, it is decoded, so its not a number, to match the leds
      c_nb_centroid = 8,

      // proximity calculation, for now just 3 bits 0 to 7 (0: far, 7:close)
      c_nb_prox  = 3,

      // minimum number to consider an image detected and not being noise
      // change this value
      c_min_colorpixels = 128,  // having 159744 pixels, 128 seems reasonable

    c_nb_buf_red   =  4,  // n bits for red in the buffer (memory)
    c_nb_buf_green =  4,  // n bits for green in the buffer (memory)
    c_nb_buf_blue  =  4,  // n bits for blue in the buffer (memory)
    // word width of the memory (buffer)
    c_nb_buf       =   c_nb_buf_red + c_nb_buf_green + c_nb_buf_blue,
    // position of the most significant bits of each color
    c_msb_blue  = c_nb_buf_blue-1,
    c_msb_red   = c_nb_buf-1,
    c_msb_green = c_msb_blue + c_nb_buf_green
  )
  (
    input          rst,       //reset, active high
    input          clk,       //fpga clock
    input          proc_ctrl, //input to control the processing (select color)
    // Address and pixel of original image
    input  [c_nb_buf-1:0]      orig_pxl,  //pixel from original image
    output [c_nb_img_pxls-1:0] orig_addr, //pixel mem address original img
    // Address and pixel of processed image
    output reg                 proc_we,  //write enable, to write processed pxl
    output [c_nb_buf-1:0]  proc_pxl, // processed pixel to be written
    output [c_nb_img_pxls-1:0] proc_addr, // address of processed pixel
    output reg [c_nb_centroid-1:0] centroid,
    output reg new_centroid,
    output reg [c_nb_prox-1:0] proximity, //how close is the object 7:close, 0:far
    output reg [2:0] rgbfilter
  );

  reg [c_nb_img_pxls-1:0]  cnt_pxl;
  reg [c_nb_img_pxls-1:0]  cnt_pxl_proc;

  wire end_pxl_cnt;
  wire end_ln;
  wire inner_frame; //if we are in the inner frame col=[8,71], row=[6,53]

  wire   red_limit;
  wire   green_limit;
  wire   blue_limit;
  wire   yellow_limit;
  wire   cyan_limit;
  wire   magen_limit;
  wire   white_limit;
  reg    color_threshold; // if color threshold is active
  
  parameter  BLACK_PXL = {c_nb_img_pxls{1'b0}};
  
  integer ind; 

  // from 0 to 159 columns, 0 to 15, and 144 to 159 are taken out
  // so column  16  -> 0
  //    column  143 -> 128
  // In the inner frame In each column there are 104 rows (inner frame),
  // c_nb_hist_val: number of  bits for the value of the histogram bins
  // c_hist_bins: number of bins of the histogram
  reg [c_nb_hist_val-1:0] histogram [c_hist_bins-1:0]; 

  // total number of pixels that are above the threshold
  reg [c_nb_inframe_pxls-1:0] colorpxls;

  // total number of pixels that are above the threshold on the left side
  // bins 0 to 3
  reg [c_nb_inframe_pxls-2:0] colorpxls_left;
  reg [c_nb_inframe_pxls-2:0] colorpxls_rght;

  // total number of pixels that are above the threshold on the bins 0to2
  reg [c_nb_inframe_pxls-2:0] colorpxls_bin012;
  reg [c_nb_inframe_pxls-2:0] colorpxls_bin567; // bins 5to7

  // total number of pixels that are above the threshold on the bins 0,1
  reg [c_nb_inframe_pxls-2:0] colorpxls_bin01;
  reg [c_nb_inframe_pxls-2:0] colorpxls_bin67; // bins 6to7

  // total color pixels divided by 2
  wire [c_nb_inframe_pxls-2:0] colorpxls_half;

  // result of the division of the total number of threshold pixels
  // initially, divided by 16, could be 8
  wire [c_nb_inframe_pxls-2:0] colorpxls_div;

  //proximity, combinational, value not valid until reaching the end of the frame
  reg [c_nb_prox-1:0] proximity_cmb; //proximity, combinational, so 

  
  reg [c_nb_cols-1:0] col, col_rg;
  // col_inframe is a bit less, but just in case
  wire [c_nb_cols-1:0] col_inframe;

  // indicates in which bin we are
  wire [c_nb_hist_bins-1:0] hist_bin;

  // Row number
  reg [c_nb_rows-1:0] row_num;

  // temporal calculation of the centroid
  reg [c_nb_centroid-1:0] centroid_tmp;

  // indicates if there are more threshold pixels on the left half of the
  // inner frame
  wire left;

  // indicates the absolute difference (positive) between the pixels on the
  // right and left
  wire [c_nb_inframe_pxls-2:0] absdif_lft_rght;

  reg       proc_ctrl_rg1, proc_ctrl_rg2;
  wire      pulse_proc_ctrl;

  // memory address count. Pixel counter from 0 to (80x60)-1 = 4799
  always @ (posedge rst, posedge clk)
  begin
    if (rst) begin
      cnt_pxl <= 0;
      cnt_pxl_proc <= 0;
      proc_we <= 1'b0;    
    end
    else begin
      proc_we <= 1'b1;
      // data from memory received a clock cycle later
      // data stored in processed memory is delayed one clock cycle
      cnt_pxl_proc <= cnt_pxl;
      if (end_pxl_cnt ) begin
        cnt_pxl <= 0;
      end
      else
        cnt_pxl <= cnt_pxl + 1'b1;
    end
  end
  
  // end of the frame
  assign end_pxl_cnt = (cnt_pxl == c_img_pxls-1) ? 1'b1 : 1'b0;
  assign orig_addr = cnt_pxl;
  assign proc_addr = cnt_pxl_proc;

  // end of the line (column number 79)
  assign end_ln = (col == c_img_cols-1)? 1'b1 : 1'b0;
  
  //Row counter, from 0 to 59
  always @ (posedge clk, posedge rst) 
  begin
    if (rst) begin   
      row_num <=0;
    end 
    else if (end_pxl_cnt) begin
      row_num <= 0;
    end
    else if (end_ln) begin
      row_num <= row_num +1'b1;
    end 
  end

  // number of column counter. Counts columns, from 0 to 79
  always @ (posedge clk, posedge rst) 
  begin
    if (rst) begin   
      col <=0;
    end 
    else if (end_ln) begin
      col <= 0;
    end
    else begin
      col <= col +1'b1;
    end 
  end

  //delay col, (columns)
  always @ (posedge clk, posedge rst)
  begin
    if (rst) begin
      col_rg <= 0;
    end
    else begin
      col_rg <= col;
    end
  end 

  //if we are in the inner frame col=[8,71], row=[6,53]
  assign inner_frame = (col_rg >= 8 && col_rg <= 71 &&
                        row_num >= 6 && row_num <= 53) ? 1'b1 : 1'b0;


  // inner column, when we are out of the range it doesn't matter the value
  // because shouldnt be used
  assign col_inframe = col_rg - 7'd8;
  // divide col_inframe by 8, from 64 columns to 8 -> 3 bits
  assign hist_bin = col_inframe[c_nb_hist_bins+3-1:3];

  // color filter thresholds
  assign red_limit = (orig_pxl[c_msb_red] && !orig_pxl[c_msb_green] && !orig_pxl[c_msb_blue]) ?
                      1'b1 : 1'b0;
  assign green_limit = (!orig_pxl[c_msb_red] && orig_pxl[c_msb_green] && !orig_pxl[c_msb_blue]) ?
                      1'b1 : 1'b0;
  assign blue_limit = (!orig_pxl[c_msb_red] && !orig_pxl[c_msb_green] && orig_pxl[c_msb_blue]) ?
                      1'b1 : 1'b0;
  assign yellow_limit = (orig_pxl[c_msb_red] && orig_pxl[c_msb_green] && !orig_pxl[c_msb_blue]) ?
                      1'b1 : 1'b0;
  assign cyan_limit = (!orig_pxl[c_msb_red] && orig_pxl[c_msb_green] && orig_pxl[c_msb_blue]) ?
                      1'b1 : 1'b0;
  assign magen_limit = (orig_pxl[c_msb_red] && !orig_pxl[c_msb_green] && orig_pxl[c_msb_blue]) ?
                      1'b1 : 1'b0;
  assign white_limit = (orig_pxl[c_msb_red] && orig_pxl[c_msb_green] && orig_pxl[c_msb_blue]) ?
                      1'b1 : 1'b0;


  //reg [c_nb_hist_val-1:0] histograma [c_hist_bins-1:0];
  // saves how many red pixels are in each column. Reset in each frame
  always @ (posedge clk, posedge rst) 
  begin
    if (rst) begin  
      for(ind=0;ind<c_hist_bins;ind=ind+1) begin
        histogram[ind] <=  0; //c_nb_hist_val'd0; 
      end
      colorpxls         <= 0; // c_nb_inframe_pxls'd0;
      colorpxls_left    <= 0; // (c_nb_inframe_pxls-2)'d0
      colorpxls_rght    <= 0; // 4567
      colorpxls_bin012 <= 0;
      colorpxls_bin567 <= 0; 
      colorpxls_bin01  <= 0; 
      colorpxls_bin67  <= 0; 
    end 
    else begin 
      if (end_pxl_cnt) begin
        for(ind=0;ind<c_hist_bins;ind=ind+1) begin
          histogram[ind]  <= 0; //  c_nb_hist_val'd0; 
        end
        colorpxls         <= 0; // c_nb_inframe_pxls'd0;
        colorpxls_left    <= 0; // (c_nb_inframe_pxls-2)'d0
        colorpxls_rght    <= 0; // 4567
        colorpxls_bin012 <= 0;
        colorpxls_bin567 <= 0; 
        colorpxls_bin01  <= 0; 
        colorpxls_bin67  <= 0; 
      end
      else begin
        // taking inner frame from 8 to 71-> 64 columns.
        // Taking away 8 columns at each end
        // and 6 to 53-> 48 rows. Taking away 6 rows at each end
        if (inner_frame == 1'b1) begin
          if (color_threshold == 1'b1) begin 
            histogram[hist_bin] <= histogram[hist_bin] + 1'b1;
            colorpxls <= colorpxls + 1;
            // these increments could be done combinationally by adding histograms
            // bins. not sure what is more efficient, and if done combinationally
            // it may add too many delays
            case (hist_bin)
              //c_nb_hist_bins'd0: begin
              3'd0: begin
                colorpxls_left    <= colorpxls_left + 1'b1;    //0123
                colorpxls_bin012 <= colorpxls_bin012 + 1'b1; //012
                colorpxls_bin01  <= colorpxls_bin01 + 1'b1;  //01
              end
              3'd1: begin
                colorpxls_left    <= colorpxls_left + 1'b1;    //0123
                colorpxls_bin012 <= colorpxls_bin012 + 1'b1; //012
                colorpxls_bin01  <= colorpxls_bin01 + 1'b1;  //01
              end
              3'd2: begin
                colorpxls_left    <= colorpxls_left + 1'b1;    //0123
                colorpxls_bin012 <= colorpxls_bin012 + 1'b1; //012
              end
              3'd3: begin
                colorpxls_left    <= colorpxls_left + 1'b1;    //0123
              end
              3'd4: begin
                colorpxls_rght    <= colorpxls_rght + 1'b1;    //4567
              end
              3'd5: begin
                colorpxls_rght    <= colorpxls_rght + 1'b1;     //4567
                colorpxls_bin567 <= colorpxls_bin567 + 1'b1;  //567
              end
              3'd6: begin
                colorpxls_rght    <= colorpxls_rght + 1'b1;     //4567
                colorpxls_bin567 <= colorpxls_bin567 + 1'b1;  //567
                colorpxls_bin67  <= colorpxls_bin67 + 1'b1;   //67
              end
              3'd7: begin
                colorpxls_rght    <= colorpxls_rght + 1'b1;     //4567
                colorpxls_bin567 <= colorpxls_bin567 + 1'b1;  //567
                colorpxls_bin67  <= colorpxls_bin67 + 1'b1;   //67
              end
            endcase
          end
        end
      end
    end
  end


  assign left = (colorpxls_left > colorpxls_rght) ? 1'b1 : 1'b0;
  assign absdif_lft_rght = (left == 1'b1) ? (colorpxls_left - colorpxls_rght) :
                                            (colorpxls_rght - colorpxls_left);

  // divided by 2 -> 1 bit
  assign colorpxls_half = colorpxls[c_nb_inframe_pxls-1:1];

  // divided by 16 -> 4 bits
  assign colorpxls_div = {4'b0 , colorpxls[c_nb_inframe_pxls-1:4]};

  always @(*) 
  begin
    centroid_tmp = 0; // default assignment
    // first if the difference between the colored pixels on de left is less than
    // 16 percent (maybe it could be 8%)
    if (colorpxls <= c_min_colorpixels) // not enough color pixels detected
      centroid_tmp = 0;
    else if (absdif_lft_rght < colorpxls_div)  // consider in the middle
      centroid_tmp[4:3] = 2'b11; // 0001 1000
      //centroid_tmp = 8'b00011000;
    else if (left) begin // more threshold pixels on the left
      // start checking from the edges
      if (histogram[0] >= colorpxls_half) 
        centroid_tmp[0] = 1'b1; // 1000 0000
      else if (colorpxls_bin01 >= colorpxls_half) 
        centroid_tmp[1] = 1'b1; // 0100 0000
      else if (colorpxls_bin012 >= colorpxls_half) 
        centroid_tmp[2] = 1'b1; // 0010 0000
      else if (colorpxls_left > colorpxls_half) 
        centroid_tmp[3] = 1'b1; // 0001 0000
    end
    else begin // more pixels on the right side
      // start checking from the edges
      if (histogram[7] >= colorpxls_half) 
        centroid_tmp[7] = 1'b1; // 0000 0001
      else if (colorpxls_bin67 >= colorpxls_half) 
        centroid_tmp[6] = 1'b1; // 0000 0010
      else if (colorpxls_bin567 >= colorpxls_half) 
        centroid_tmp[5] = 1'b1; // 0000 0100
      else if (colorpxls_rght > colorpxls_half) 
        centroid_tmp[4] = 1'b1; // 0000 1000
    end
  end

  // proximity measurement (color pixel count
  // making the assumption that all pixels are together and that there is no 
  // noise. In the future we will consider this
  // only considering pixles in the inner frame

  // distance: how many pixels are detected
  // since in the inner frame there are 3072 pixels (64x48) -> 12 bits
  // (c_nb_inframe_pxls),
  // lets say that we are too close if we have 2048 or more, that is,
  //    bit 12 is one
  // Total : 3072
  // ---->= 2048            : 2/3 - bits: 11         ='1'    7 -> Max, very close
  // >= 1536 = 1024+512 : 1/2 - bits:   10:9       ='11'   7 -> Max, very close
  // >= 1024            : 1/3 - bits:   10         ='1'    6
  // >=  512            : 1/6 - bits:      9       ='1'    5
  // >=  256            : 1/12- bits:        8     ='1'    4
  // >=  128            : 1/24- bits:         7    ='1'    3
  // >=   64            : 1/48- bits:          6   ='1'    2
  // >=   32            : 1/96- bits:           5  ='1'    1
  // <    32                                               0 -> Min

  always @(*)
  begin
    if (colorpxls[c_nb_inframe_pxls-2] == 1'b1) begin // bit 10
      if (colorpxls[c_nb_inframe_pxls-3] == 1'b1) begin // bit 9
        proximity_cmb <= 3'd7;  // bits 10:9 too close, max proximity >=1536 : 1/2
      end
      else
        proximity_cmb <= 3'd6;  // bit 10 too close, max proximity >=1024 : 1/3
    end
    else if (colorpxls[c_nb_inframe_pxls-3] == 1'b1) begin // bit 9
      proximity_cmb <= 3'd5;  // 6: bit 9  >= 512 - 1/6
    end
    else if (colorpxls[c_nb_inframe_pxls-4] == 1'b1) begin // bit 8
      proximity_cmb <= 3'd4;  // 5: bit 8  >= 256 - 1/12
    end
    else if (colorpxls[c_nb_inframe_pxls-5] == 1'b1) begin // bit 7
      proximity_cmb <= 3'd3;  // 4: bit 7  >= 128 - 1/24
    end
    else if (colorpxls[c_nb_inframe_pxls-6] == 1'b1) begin // bit 6
      proximity_cmb <= 3'd2;  // 3: bit 6  >= 64 - 1/48
    end
    else if (colorpxls[c_nb_inframe_pxls-7] == 1'b1) begin // bit 5
      proximity_cmb <= 3'd1;  // bit 5  >= 32 - 1/96
    end
    else
      proximity_cmb <= 3'd0;  // < 32
  end

  // save the centroid and proximity when finishing the frame
  always @ (posedge clk, posedge rst) 
  begin
    if (rst) begin
      centroid <= 0; 
      new_centroid <= 1'b0;
      proximity <= 0;
    end
    else if (end_pxl_cnt) begin
      centroid <= centroid_tmp; 
      new_centroid <= 1'b1;
      proximity <= proximity_cmb;
    end
    else
      new_centroid <= 1'b0;
  end


  always @ (posedge rst, posedge clk)
  begin
    if (rst) begin
      proc_ctrl_rg1 <= 1'b0;
      proc_ctrl_rg2 <= 1'b0;
    end
    else begin
      proc_ctrl_rg1 <= proc_ctrl;
      proc_ctrl_rg2 <= proc_ctrl_rg1;
    end
  end

  // detect a pulse in proc_ctrl
  assign pulse_proc_ctrl = (proc_ctrl_rg1 & ~proc_ctrl_rg2);
  
  // changes the filter
  always @ (posedge rst, posedge clk)
  begin
    if (rst) begin
      rgbfilter <= 3'b000; // no filter
    end
    else begin
      if (pulse_proc_ctrl) begin
        case (rgbfilter)
          3'b000: // no filter, output same as input
            rgbfilter <= 3'b100; // red filter
          3'b100: // red filter
            rgbfilter <= 3'b010; // green filter
          3'b010: // green filter
            rgbfilter <= 3'b001; // blue filter
          3'b001: // blue filter
            rgbfilter <= 3'b110; // red and green filter
          3'b110: // red and green filter
            rgbfilter <= 3'b101; // red and blue filter
          3'b101: // red and blue filter
            rgbfilter <= 3'b011; // green and blue filter
          3'b011: // green and blue filter
            rgbfilter <= 3'b111; // red, green and blue filter
          3'b111: // red, green and blue filter
            rgbfilter <= 3'b000; // no filter
        endcase
      end
    end
  end

  assign proc_pxl = color_threshold ? orig_pxl : BLACK_PXL;
  
  always @ (*) // should include RGB mode
  begin
    // check on RED
    color_threshold = 1'b1;
    case (rgbfilter)
      3'b000: // no filter, output same as input
        color_threshold = 1'b1;
      3'b100: begin // red filter
        color_threshold = red_limit;
      end
      3'b010: begin // green filter
        color_threshold = green_limit;
      end
      3'b001: begin // filter blue
        color_threshold = blue_limit;
      end
      3'b110: begin // filter red and green
        color_threshold = yellow_limit;
      end
      3'b101: begin // filter red and blue
        color_threshold = magen_limit;
      end
      3'b011: begin // filter green and blue
        color_threshold = cyan_limit;
      end
      3'b111: begin // red, green and blue filter
        color_threshold = white_limit;
      end
    endcase
  end

endmodule
