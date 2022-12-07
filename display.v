//////////////////////////////////////////////
///
/// Display Interface
///
///
///	Chuck Pateros
///	University of San Diego
///	2022-11-06
///
//////////////////////////////////////////////

module display( 
    input clk, 
    input [15:0] four_hex_in,
    //
    //  Register output for second_toggle
    //
    output reg second_toggle,


    output [6:0] SEG, 
    output [3:0] COMM,
    output XTRA);

    // Initialize common anode signals
    // ACTIVE HIGH
    reg [3:0] comm;
    assign COMM = ~comm; // tie to output, invert polarity

    reg xtra;
    assign XTRA = xtra;

    // Declare segment signals
    // ACTIVE LOW
    reg [6:0] seg;
    assign SEG = ~seg; // tie to output, invert polarity


    /// second timer signals
    localparam [23:0] timer_init = 24'd11999999;
    reg [23:0] second_timer_state;
    reg second_toggle; // will update in second_timer SM

    /// preload second timer state machine
    initial begin
        second_timer_state = timer_init;
        second_toggle = 1;
    end /// end timer state initial begin

    /// second_timer
    /// second timer state machine
    /// generates a signal that toggles every second
    always @(posedge clk) begin
        if (second_timer_state == 0) begin
            second_timer_state = timer_init;
            //
            // toggle second_toggle here
            second_toggle = ~second_toggle;

           
        end /// end if
        else begin
            second_timer_state <= second_timer_state - 1;
        end /// end else
    end /// second timer state machine

    /// Display refresh signals
    /// 2 bit signal to track displayed digit
    reg [1:0] dd = 2'b11; // dd range 0-3
    /// current hex digit
    reg [3:0] hex_to_display;

    /// refresh timer signals
    localparam [23:0] refresh_init = 24'h000f00;
    reg [23:0] refresh_timer_state;
    reg refresh_tick;

    // preload refresh state machine
    initial begin
        refresh_timer_state = refresh_init;
        refresh_tick = 1;
    end // end refresh timer initial begin


    /// refresh timer state machine
    /// generates a tick roughly every ms
    always @(posedge clk) begin
          if (refresh_timer_state == 0) begin
            refresh_timer_state = refresh_init;
            refresh_tick = 1;
          end /// end if
          else begin
            refresh_timer_state <= refresh_timer_state - 1;
            refresh_tick = 0;
          end /// end else
    end /// refresh timer state machine

    /// display digit state machine
    /// follows team pattern
    always @(posedge refresh_tick) begin
          case(dd)
              2'b00   : dd = 2'b11;
              2'b01   : dd = 2'b00;
              2'b10   : dd = 2'b01;
              2'b11   : dd = 2'b10;
              default : dd = 2'b00;
          endcase
    end /// display_digit state machine

///////////////////////////////////////////////////
/// Combinational circuits start here
///////////////////////////////////////////////////

    always @ ( * ) begin

    /// drives the 'one hot' common cathodes
    case(dd)
        2'b00   : comm = 4'b0111;
        2'b01   : comm = 4'b1011;
        2'b10   : comm = 4'b1101;
        2'b11   : comm = 4'b1110;
        default : comm = 4'b1110;
    endcase

    /// drives the COLHI signal to light the colon 25% of the time
    case(comm)
        4'b0111 : xtra = 1'b0;
        4'b1011 : xtra = 1'b0;
        4'b1101 : xtra = 1'b1;
        4'b1110 : xtra = 1'b0;
        default : xtra = 1'b1;
    endcase

    
    

    /// selects the hex digit for the currently displayed digit
          case(dd)
              2'b00   : hex_to_display = four_hex_in[15:12]; 
              2'b01   : hex_to_display = four_hex_in[11:8];
              2'b10   : hex_to_display = four_hex_in[7:4];
              2'b11   : hex_to_display = four_hex_in[3:0];
              default : hex_to_display = 4'b0000;
          endcase



          case(hex_to_display) // upside down
            4'b0000   : seg = 7'b0111111;
            4'b0001   : seg = 7'b0110000;
            4'b0010   : seg = 7'b1011011;
            4'b0011   : seg = 7'b1111001;
            4'b0100   : seg = 7'b1110100;
            4'b0101   : seg = 7'b1101101;
            4'b0110   : seg = 7'b1101111;
            4'b0111   : seg = 7'b0111000;
            4'b1000   : seg = 7'b1111111;
            4'b1001   : seg = 7'b1111100;
            4'b1010   : seg = 7'b1111110;
            4'b1011   : seg = 7'b1100111;
            4'b1100   : seg = 7'b0001111;
            4'b1101   : seg = 7'b1110011;
            4'b1110   : seg = 7'b1001111;
            4'b1111   : seg = 7'b1001110;
            default   : seg = 7'b0000000;
          endcase

      end /// - ends the combinational circuits
endmodule 
