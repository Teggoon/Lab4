// CSE140L  Spring 2020   
// Lab4_tb
// full testbench for programmable message encryption
// the 6 possible maximal-length feedback tap patterns from which to choose
/*  
  assign LFSR_ptrn[0] = 6'h21;
  assign LFSR_ptrn[1] = 6'h2D;
  assign LFSR_ptrn[2] = 6'h30;
  assign LFSR_ptrn[3] = 6'h33;
  assign LFSR_ptrn[4] = 6'h36;
  assign LFSR_ptrn[5] = 6'h39;
  */
module Lab4_tb                 ;
  logic      clk = 0           ;		 // advances simulation step-by-step
  logic      init = 1          ;         // init (reset, start) command to DUT
  wire       done              ;         // done flag returned by DUT
  logic[7:0] message[50]       ,		 // original message, in binary
             msg_padded[62]    ,		 // original message, plus pre- and post-padding
             msg_crypto[62]    ,		 // encrypted message to test against DUT
             msg_crypto_DUT[62],         // encrypted message according to the DUT
			 pre_length        ;         // encrypted space bytes before first character in message
  logic[5:0] lfsr_ptrn         ,         // one of 6 maximal length 6-tap shift reg. ptrns
			 lfsr_state        ;         // initial state of encrypting LFSR         
  logic[5:0] LFSR              ;		 // linear feedback shift register, makes PN code
  logic[7:0] ind  = 0          ;		 // index counter -- increments on each clock cycle

// ***** select your original message string to be encrypted *****
// note in practice your design should be able to handle ANY ASCII string
//   whose characters are chosen from ASCII vales of 0x40 through 0x7F
// our original American Standard Code for Information Interchange message follows
  string     str  = "Mr_Watson_come_here_I_want_to_see_you";

  int str_len                  ;		 // length of string (character count)
  assign str_len = str.len     ;
//  initial #10ns $display("string length = %0d  %0d",str_len,str.len);
// displayed encrypted string will go here:
  string     str_enc[64]       ; 

// this assumes the top level module of your design is called top_level
// change my test bench to match your own top level module name
  top_level dut(.*)            ;         // your top level design goes here 

// ***** choose one of the 6 feedback TAP patterns *****
  int i = 2;                             // choose the LFSR_ptrn; legal values = 0 to 5; 

  logic[5:0] LFSR_ptrn[8];               // testbench will automatically apply whichever is chosen
  assign LFSR_ptrn[0] = 6'h21;           //  and check for correct results from your DUT
  assign LFSR_ptrn[1] = 6'h2D;
  assign LFSR_ptrn[2] = 6'h30;
  assign LFSR_ptrn[3] = 6'h33;
  assign LFSR_ptrn[4] = 6'h36;
  assign LFSR_ptrn[5] = 6'h39;

  initial begin
// ***** select your desired preamble length *****  
	pre_length  = 9            ;         // set preamble length
    if(i>5) begin 
      i   = 5            ;               // restricts to legal
      $display("illegal pattern select chosen, force to select pattern 5");        
    end
	lfsr_ptrn   = LFSR_ptrn[i] ;         // selects one of 6 permitted

// ***** choose any nonzero 6-bit starting state for the LFSR ******
	lfsr_state  = 6'h01        ;         // any nonzero value will do; something simple facilitates debug
	if(!lfsr_state) lfsr_state = 6'h20;  // prevents nonzero lfsr_state by substituting 6'b10_0000
    LFSR        = lfsr_state   ;         // initalize test bench's LFSR

    $display("%s",str)         ;         // print original message in transcript window
    for(int j=0; j<62; j++) 			 // pre-fill message_padded with ASCII _ characters
      msg_padded[j] = 8'h5F;         	 //    as placeholders: see next line  
    for(int l=0; l<str_len; l++)  		 // overwrite up to 60 of these spaces w/ message itself
	  msg_padded[pre_length+l] = str[l]; // leaves pre_length ASCII _ in front of the message itself
    for(int n=0; n<61; n++)
	  dut.dm1.core[n] = 8'h5F;           // prefill data mem w/ _
    for(int m=0; m<str_len; m++)  
	  dut.dm1.core[m] = str[m];	         // copy original string into device's data memory[0:49]
    if(pre_length<7) pre_length = 7;     // ensures at least 7 preamble bytes (needed for decryption)
    dut.dm1.core[61] = pre_length;       // number of bytes preceding message 
	dut.dm1.core[62] = lfsr_ptrn;		 // LFSR feedback tap positions (8 possible ptrns)
	dut.dm1.core[63] = lfsr_state;		 // LFSR starting state (nonzero)
//  optional diagnostic print statement:
//    $display("%d  %h  %h  %h  %s",i,message[i],msg_padded[i],msg_crypto[i],str[i]);
    #20ns init = 0             ;
    #60ns; 	  
    for(int ij=0; ij<61; ij++) begin
      msg_crypto[ij]        = msg_padded[ij] ^ {2'b0,LFSR}; // encrypt 6 LSBs
//  $displayb(msg_padded[i],,,LFSR,,,msg_crypto[i]);
      LFSR                 = (LFSR<<1)+(^(LFSR&lfsr_ptrn));//{LFSR[4:0],feedback};		   // roll the rolling code
      str_enc[ij]           = string'(msg_crypto[ij]);
    end
                               // wait for 6 clock cycles of nominal 10ns each
    wait(done);                          // wait for DUT's done flag to go high
	// print testbench version of encrypted message next to DUT's version -- should match
/*    if(i<15)
      $display("%d  %h  %h  %h  %s  %s",
        i,message[i],msg_padded[i],msg_crypto[i],str[i-16],str_enc[i]);
    else
      $display("%d  %h  %h  %h  ",
        i,message[i],msg_padded[i],msg_crypto[i]);//,str[i],str_enc[i]);
*/ 
    for(int n=0; n<62; n++)	begin
      $write("%d bench msg: %s %h %h %s dut msg: %h",n, msg_padded[n],msg_padded[n],msg_crypto[n],msg_crypto[n],dut.dm1.core[n+64]);   
      if(msg_crypto[n]==dut.dm1.core[n+64]) $display("    very nice!");
	  else $display("      oops!");
	end
    $display("original message  = %s",string'(msg_padded));
    $write  ("encrypted message = ");
    for(int kk=0; kk<64; kk++)
      $write("%s",string'(msg_crypto[kk]));//msg_crypto);
    $display();  
    $stop;
  end

always begin							 // continuous loop
  #5ns clk = 1;							 // clock tick
  #5ns clk = 0;							 // clock tock
// print count, message, padded message, encrypted message, ASCII of message and encrypted
end										 // continue

endmodule