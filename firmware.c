////////
// 
//	firmware.c
//
//	Project 5 Solution
//	
//	Hardware multiplexed 7-segment display 
//  on the breadboard using this C program on a 
//  PICOSOC RISC-V processor instantiated on the FPGA.
//
//  The second count is provided as a 16 bit binary number
//  in 4 hex digits.  Note that 4 decimal digits can be
//  sent to the display by sending 4 BCD digits instead of hex.
//
//  reg_gpio = ...      //GPIO output to display circuit
//  var = reg_gpio ...  // input from display circuit GPIO to program
//
//	Chuck Pateros, Alec Henning, Nick Janney, Calvin Michaels, Cristian St. Clair
//	University of San Diego
//	2022-11-06
//
////////

#include <stdint.h>
#include <stdbool.h>
#include <sys/wait.h> // wait
#include <stdio.h> // memset
#include <string.h> // memset



// a pointer to this is a null pointer, but the compiler does not
// know that because "sram" is a linker symbol from sections.lds.
extern uint32_t sram;

#define reg_spictrl (*(volatile uint32_t*)0x02000000)
#define reg_uart_clkdiv (*(volatile uint32_t*)0x02000004)
#define reg_uart_data (*(volatile uint32_t*)0x02000008)
#define reg_gpio (*(volatile uint32_t*)0x03000000)

extern uint32_t _sidata, _sdata, _edata, _sbss, _ebss,_heap_start;

uint32_t set_irq_mask(uint32_t mask); asm (
    ".global set_irq_mask\n"
    "set_irq_mask:\n"
    ".word 0x0605650b\n"
    "ret\n"
);

// Here is a function if you don't have "/" and "%"
// uint32_t convert(uint32_t num)
// {
//     unsigned char min_ten = 0;
//     unsigned char min_one = 0;
//     unsigned char sec_ten = 0;
//     unsigned char sec_one = 0;
//     while(num >= 600)
//     {
//         min_ten = min_ten + 1;
//         num = num - 600;
//     }
//     while(num >= 60)
//     {
//         min_one = min_one + 1;
//         num = num - 60;
//     }
//     while(num >= 10)
//     {
//         sec_ten = sec_ten + 1;
//         num = num - 10;
//     }
//     sec_one = num;
//     return (min_ten << 12) | (min_one << 8) | (sec_ten << 4) | sec_one;
// }


void spin_wait_ms(int wait_ms){
    int cycles_to_wait = 35 * wait_ms;
    while (cycles_to_wait >= 0)
      cycles_to_wait -= 1;
  }


void main() {
    set_irq_mask(0xff);

    // zero out .bss section
    for (uint32_t *dest = &_sbss; dest < &_ebss;) {
        *dest++ = 0;
    }

    // switch to dual IO mode
    reg_spictrl = (reg_spictrl & ~0x007F0000) | 0x00400000;

    uint32_t led_timer = 0;
    uint32_t second_timer = 0;
    uint32_t lap_second_timer = 0;
    uint32_t ms_timer = 0;
    uint32_t display_digit = 0;
    uint32_t comm = 0b1110;
    uint32_t segments = 0b1111111;
    uint32_t hex_to_display = 0x0;
    uint32_t second_toggle = 0;
    uint32_t new_second_toggle = 0;
    uint32_t timerDisplay = 0;
    uint32_t lapTimeDisplay = 0;
    uint32_t minutes = 0;
    uint32_t min_ones = 0;
    uint32_t sec_tens = 0;
    uint32_t sec_ones = 0;
    uint32_t lapTimes[9];
    uint32_t lapNum = 0;
    bool dec = 1;
    
    bool incrementing = false;
    while (1) {

      // read values from hardware
      //      assign read_data = ((second_toggle & 32'b1)); // from top.v
      // Hardware mapping for the GPIO input signals to 'C' program
    // wire [31:0] gpio_in = ((second_toggle &1'b1) << 0)|((STOP & 1'b1)<<1);

      new_second_toggle = reg_gpio & 0x1;


      while(new_second_toggle == second_toggle){
          new_second_toggle = reg_gpio & 0x1;
      }
      second_toggle = new_second_toggle;
      
      // Read UP_DOWN

      if(reg_gpio&0b10) // Reads if the Clock is Stopped or Not
      {
          second_timer++;
          lap_second_timer++;
          incrementing = true;
      }
      else
      {
          incrementing = false; // Stop the Stopwatch if Input 
      }

      if(second_timer > 599 & !incrementing)
          second_timer = 599;
      else if(second_timer > 599 & incrementing)
          second_timer = 0;


      if (!(reg_gpio&0b100)) // RESET BUTTON
      {
        second_timer = 0; // active high
        lap_second_timer = 0;
          // Clear the array here
        // memset(lapTimes, 0, sizeof(lapTimes));
        for (int i=0; i<sizeof(lapTimes)/sizeof(lapTimes[0]); i++)
          lapTimes[i] = 0;
        lapNum = 0;
      }

      if (!(reg_gpio&0b1000)) // LAP BUTTON
      {
        if (lapNum < 10) { // do not go out of range of the array
          lapTimes[lapNum] = lap_second_timer;
          lapNum++;
          lap_second_timer = 0; // reset to zero after placing in array
        }
      }

      // add if statement here for toggling to display lap times need to add wire to pcf
      if (!(reg_gpio&0b10000)) // LAP DISPLAY Wire
      {
         second_timer = 0; // active high
      }

      // Following code works when "/" and "%" implemented

      sec_tens = (second_timer % 60) / 10;
      sec_ones = (second_timer % 60) % 10;

      minutes = ((second_timer / 60) % 60);
      min_ones = minutes % 10;

      timerDisplay = (lapNum << 12) | (min_ones << 8) | (sec_tens << 4) | (sec_ones << 0);
      // if statement here for switching between timer display and lap time display
      
      if(!(reg_gpio&0b10000)){ // Lap Display Wire 
        
        incrementing = false; // When in Lap Display Mode, Stop Tracking the Time

        for (int i=0; i<sizeof(lapTimes)/sizeof(lapTimes[0]); i++){
            sec_tens = (lapTimes[i] % 60) / 10;
            sec_ones = (lapTimes[i] % 60) % 10;

            min_ones = ((lapTimes[i] / 60) % 60) % 10;

            lapTimeDisplay = ((i+1) << 12) | (min_ones << 8) | (sec_tens << 4) | (sec_ones << 0);
            // i + 1 is the Lap Number
            reg_gpio = (lapTimeDisplay & 0xFFFF);
            
            spin_wait_ms(2000); // Determines how long each lap is displayed on the screen 
        }
      }
      else
      {
        incrementing = true; // When not in Lap Display Mode, Resume the Clock Counting
        reg_gpio = (timerDisplay & 0xFFFF);
      }

    // End of "/" and "%" code
    
    // Code to use convert function if "/" and "%" not implemented
    //   uint32_t con = convert(second_timer);
    //   reg_gpio = con; // debug LEDs in 4 LSBs
       
  } // end of while(1)
} // end of main program
