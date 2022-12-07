////////
// 
//	top.v
//
//	Project 4 FA22
//	
//  PICOSOC RISC-V processor instantiated to support a
//	HARDWARE multiplexed 7-segment display 
//  on the breadboard using C program firmware.c
//
//	Chuck Pateros, Alec Henning, Nick Janney, Calvin Michaels, Cristian St. Clair
//	University of San Diego
//	2022-11-06
//
////////

`ifdef PICOSOC_V
`error "top.v must be read before picosoc.v!"
`endif

`define PICOSOC_MEM ice40up5k_spram

module top (
    input clk,


    // hardware UART
    output UART_TX,
    input UART_RX,


    // onboard SPI flash interface
    output flash_csb,
    output flash_clk,
    inout  flash_io0,
    inout  flash_io1,
    inout  flash_io2,
    inout  flash_io3,

    //////////////////////////////////
    // User defined inputs and outputs
    //////////////////////////////////

    input STOP,
    input ZERO,
    input LAP,
    input LAPDISPLAY,

    output DEC,
    output COLHI,
    output COLLO,

    // Do not edit or remove
    output [3:0] COMM, // 4 common cathodes
    output [6:0] SEG, // seven segments 6-g, 0-a
    output [3:0] DBG // 4 debug leds on breadboard
    
);
    ///////////////////////////////////
    // Power-on Reset
    ///////////////////////////////////
    reg [5:0] reset_cnt = 0;
    wire resetn = &reset_cnt;

    always @(posedge clk) begin
        reset_cnt <= reset_cnt + !resetn;
    end


    ///////////////////////////////////
    // SPI Flash Interface
    ///////////////////////////////////
    wire flash_io0_oe, flash_io0_do, flash_io0_di;
    wire flash_io1_oe, flash_io1_do, flash_io1_di;
    wire flash_io2_oe, flash_io2_do, flash_io2_di;
    wire flash_io3_oe, flash_io3_do, flash_io3_di;

    SB_IO #(
        .PIN_TYPE(6'b 1010_01),
        .PULLUP(1'b 0)
    ) flash_io_buf [3:0] (
        .PACKAGE_PIN({flash_io3, flash_io2, flash_io1, flash_io0}),
        .OUTPUT_ENABLE({flash_io3_oe, flash_io2_oe, flash_io1_oe, flash_io0_oe}),
        .D_OUT_0({flash_io3_do, flash_io2_do, flash_io1_do, flash_io0_do}),
        .D_IN_0({flash_io3_di, flash_io2_di, flash_io1_di, flash_io0_di})
    );



    ///////////////////////////////////
    // Peripheral Bus
    ///////////////////////////////////
    wire        iomem_valid;
    reg         iomem_ready;
    wire [3:0]  iomem_wstrb;
    wire [31:0] iomem_addr;
    wire [31:0] iomem_wdata;
    reg  [31:0] iomem_rdata;

    wire [15:0] displayTest = 16'hD33D;

    display display (
        .clk(clk),
        //
        // The four_hex_in instantiation command ties the input of the 
        // display circuit to the GPIO output from the program    
        .four_hex_in(gpio_out[15:0]), 
        //
        // Instantiate the second toggle output from display
        //
        .second_toggle(second_toggle),
        .SEG(SEG),
        .COMM(COMM),
        .XTRA(COLHI) // Default: XTRA signal used for the 2 installed decimal points
        );


    reg [31:0] gpio_out;
// Hardware mapping for the GPIO input signals to 'C' program
    wire [31:0] gpio_in = ((second_toggle &1'b1) << 0)|((STOP & 1'b1)<<1) | ((ZERO & 1'b1)<<2) | ((LAP & 1'b1) << 3) | ((LAPDISPLAY & 1'b1) << 4);
    wire second_toggle;

// Tie low order GPIO outputs to debug LEDs 
    assign DBG = gpio_out[3:0];

// Default: colon is on all the time, dec is off all the time
    // assign COLHI = 1; // changed .XTRA(DEC) => .XTRA(COLHI)
    assign DEC = 0;  // changed DEC to 0 to turn on
    assign COLLO = 0;

    always @(posedge clk) begin
        if (!resetn) begin
            gpio_out <= 0; // modified to gpio_out by Pateros
        end else begin
            iomem_ready <= 0;

            ///////////////////////////
            // GPIO Peripheral
            ///////////////////////////
            //
            // Modified from PicoSoC to separate gpio_in 
            // and gpio_out
            if (iomem_valid && !iomem_ready && iomem_addr[31:24] == 8'h03) begin
                iomem_ready <= 1;
                iomem_rdata <= gpio_in;
                if (iomem_wstrb[0]) gpio_out[ 7: 0] <= iomem_wdata[ 7: 0];
                if (iomem_wstrb[1]) gpio_out[15: 8] <= iomem_wdata[15: 8];
                if (iomem_wstrb[2]) gpio_out[23:16] <= iomem_wdata[23:16];
                if (iomem_wstrb[3]) gpio_out[31:24] <= iomem_wdata[31:24];
            end


            ///////////////////////////
            // Template Peripheral
            ///////////////////////////
            if (iomem_valid && !iomem_ready && iomem_addr[31:24] == 8'h04) begin
                iomem_ready <= 1;
                iomem_rdata <= 32'h0;
            end
        end
    end

    picosoc #(
        .BARREL_SHIFTER(0), // reduces device utilization if disabled
		.ENABLE_MULDIV(1), //  use rv32im ISA if enabled, otherwise rv32i ##### Changed to 1 to enable muldiv
        .MEM_WORDS(2048)  // use 2KBytes of block RAM by default
    ) soc (
        .clk          (clk         ),
        .resetn       (resetn      ),

        .ser_tx       (UART_TX       ),
        .ser_rx       (UART_RX      ),

        .flash_csb    (flash_csb   ),
        .flash_clk    (flash_clk   ),

        .flash_io0_oe (flash_io0_oe),
        .flash_io1_oe (flash_io1_oe),
        .flash_io2_oe (flash_io2_oe),
        .flash_io3_oe (flash_io3_oe),

        .flash_io0_do (flash_io0_do),
        .flash_io1_do (flash_io1_do),
        .flash_io2_do (flash_io2_do),
        .flash_io3_do (flash_io3_do),

        .flash_io0_di (flash_io0_di),
        .flash_io1_di (flash_io1_di),
        .flash_io2_di (flash_io2_di),
        .flash_io3_di (flash_io3_di),

        .irq_5        (1'b0        ),
        .irq_6        (1'b0        ),
        .irq_7        (1'b0        ),

        .iomem_valid  (iomem_valid ),
        .iomem_ready  (iomem_ready ),
        .iomem_wstrb  (iomem_wstrb ),
        .iomem_addr   (iomem_addr  ),
        .iomem_wdata  (iomem_wdata ),
        .iomem_rdata  (iomem_rdata )
    );
endmodule
/*
 *  PicoSoC - A simple example SoC using PicoRV32
 *
 *  Copyright (C) 2017  Clifford Wolf <clifford@clifford.at>
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */
