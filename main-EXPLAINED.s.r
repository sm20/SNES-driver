/*
CPSC 359
Assignment 3- SNES Driver

This program initializes the latch, clock, and data lines of the SNES controller for output and input, respectively. 
It then prompts a user to press a button and displays which button was pressed to the screen.
The program terminates after the START button is pressed.

Created By: Sajid Choudhry and Ali Ahmad
TA: Salim Afra

*/

.section    .init
.globl     _start

_start:
    b       main

.section .text

main:
    mov     sp, #0x8000

	bl		EnableJTAG
	bl		InitUART    // Initialize the UART






	/*Set the 3 GPIO Lines*/

	//set PIN 9(latch) to output(code 1)
	mov	r0,	#9				//GPIO line number
	mov	r1,	#0b001			//function code to set a line to an output
	bl	InitGPIO			//Initialize the line


	//set PIN 11(clock) to output(code 1)
	mov	r0,	#11
	mov	r1,	#0b001
	bl	InitGPIO


	//set PIN 10(data) to input(code 0)
	mov r0,	#10
	mov	r1,	#0b000			//function code to set a line to an input
	bl	InitGPIO





	//Print Introduction message

	ldr		r0, =promptIntroMessage		 //address pointer to beginning of introText in memory
  	mov		r1, #30						 //Number of characters in introText to be written to screen
  	bl 		WriteStringUART				 //call subroutine to write to screen



	/*Prompt user to enter a button and clears registers. Also, the program loops back here after a button is pressed.*/

requestButtonPress:


	ldr		r0, =promptPressButton		 //address pointer to beginning of introText in memory
	bl		PrintMessage				//print message




	//set values for loopLatch
	mov	r7,		#12		//Button tracker reset. r7 will change to a value from 0-11 if a button is pressed
	mov r10,	#0		//orr array, will store entire 16-bits in proper order




	/*Loop to run all latches in-sync so as to store SNES controller values in a register for later use*/

loopLatch:

	//set latch line to 1 and clock to 1, wait 12 microseconds, and then set the latch line to 0.
    mov	r1,	#1
	bl	WriteLatch


    mov	r1,	#1
    bl	WriteClock


	mov r1,	#12
	bl	WaitDelay
	mov	r1,	#0
	bl	WriteLatch



	//loop counter to perform 16 cycles of the clock line, 1 for each button existing on the SNES
	mov	r8,	#0		//loop counter

	/*Sets loop counter for 16 iterations. After the latch line is set to 0, the clock line waits for 6 microseconds. Then the clock line is set to 0. Then there is a delay of 6 microseconds. At this point, the data line
	reads to check the state of the first button (0-pressed, 1-not pressed). Then the clock line is set to 0 and the process loops until 16 cycles complete, 1 for each button.
	*/

loopClockData:

	//wait 6 microseconds, set clock line to 0, wait 6 microseconds
	mov r1,	#6
	bl	WaitDelay
	mov	r1,	#0
	bl	WriteClock
	mov r1,	#6
	bl	WaitDelay



	//check to see if the button under consideration was pressed. bit 1- not pressed. bit 0- pressed.
	mov r2, r8	//current index to store new value in
	mov r0, r10 //move bit array into r0
	bl	ReadSNES
	mov r10,  r0  //return bit array to r10

	//if the single bit was a 0(button pressed) then store current button index(r8) into r7 
	//R7 remains at 12(initialized value) if no button is pressed(never a zero)
	cmp		r1,	#0
	moveq	r7, r8	


	//set clock line to 1
	mov	r1,	#1
	bl	WriteClock



	add	r8,	#1			//increment inner loop (pulsing clock)
	cmp	r8, #16			//keep running loop 16 times for 16 clock cycles to read state of all buttons


	bne		loopClockData	//loop to top if counter reaches 16, otherwise fall through to code below

    /*Prevent repeat print- problem lines*/
    //ldr r2, =DelayTime
    //ldr r1, [r2]
    //bl WaitDelay
    cmp r7, r6
    beq loopLatch
    movne r6, r7




	/*Use the index (stored in r7) of the value returned as 0(button pressed) by the data latch to print the button pressed to the screen */
	mov	r3,	r7
	bl	TranslateCode

	//If no button is pressed, branch back and wait for a button press
    cmp r3, #11
    bgt	loopLatch

	//Reloop to top and Reprompt the user to enter a button after a button has been pressed
	b		requestButtonPress		//jump back to button prompt after a button has been successfully selected.





	//Terminates the program
haltLoop$:
	b		haltLoop$


//-----------------------------------------------------
InitGPIO:
//Initializes a GPIO line
//receives: r0- GPIO line (decimal) to be initialized, r1- function code (output or input) to set line to
//returns: nothing
//
//-----------------------------------------------------
	push  {r4,r5}

	ldr	r3,	=0x3F200000	  //Load the base GPIO register


	//Determine the appropriate register address and PIN index number to work with
	cmp	r0,	#9
	addgt	r3,	#4		//If r0 contains a pin greater than 9, then moves to point to address of GPFSEL1 (PIN 10-19)
	subgt	r0,	#10		//If r0 contains a pin greater than 9, then retrieve least significant digit of PIN number as this is the index of the PIN that will be worked with
				//(ex. pin 10 is at index 0 of GPFSEL1 and pin 11 at index 1, and pin 9 is at GPFSEL0 index 9)

	mov r5, #0
	mov r5, #3
	mul r0, r5   //r0= 3*bitIndex, to get to appropriate bit to store information in


	ldr	r2,	[r3]		//loads the value of R3(register under consdieration) into r2 for manipulation

	mov	r4,	#7			///b0111, set r4's last 3 bits to 111 for clearing

	lsl r4,	r0			//shift r4 to appropraite bit position, as dictated by the PIN index(*3 to get to appropriate bit position)
	bic	r2,	r4			//clear the appropriate bits in r2, r2=000 for the 3 appropriate bit positions now

	str	r2,	[r3]		//store r2 into r3 so that bits are cleared to 000 for the 3 corresponding bits, for the PIN under consideration. (Only PIN10-Data needs to be set to 000 for input)

	//branch out of function if the function code was 0, as it has already been set to 0 above, otherwise continue to set for function code 0b001(output) for PIN09-latch and PIN 11 -clock
	cmp r1,	#0b000
	bxeq	lr

	//store 001 into appropriate bits for the PIN under consideration

	lsl	r1,	r0			//moves 001 into appropriate index for setting the PIN under considetation
	orr	r2,	r1			//sets the appropriate values in r2, r2=001 for the 3 appropriate bit positions
	str	r2, [r3]		//store 001 back into GPIO LINE's appropriate PIN (which will set PIN 09 and 11 to output in this case.)
	
	pop {r4,r5}

	bx	lr				//branch out of function
	  
	  
//-----------------------------------------------------
WriteLatch:
//Writes a 0 or 1 to the latch line
//receives: r1- value to write, either a 1 or a 0
//returns: nothing
//
//-----------------------------------------------------
	ldr	r2,	=0x3F200000		//address of base GPIO register

	mov r3, #1				//set least significant bit of r3 to 1
	lsl	r3,	#9				//align r3 to change the appropriate bit corresponding to PIN 9

	teq	r1,	#0				//if r1=0 jump to streq otherwise if r1=1 jump to strne
	streq r3, [r2, #40]		//set GPCLR0 to 1 if r1=0..maybe it doesn't show up in register value for checking...
	strne r3, [r2, #28]		//GPSET0. if r1=1

	bx	lr

//-----------------------------------------------------
WriteClock:
//Writes a 0 or 1 to the clock Line
//receives: r1- value to write, either a 1 or a 0
//returns: nothing
//
//-----------------------------------------------------
	ldr	r2,	=0x3F200000		//address of clock GPIO register (PIN#11)

	mov r3, #1
	lsl	r3,	#11	//set up to write to pin11-clock

	teq	r1,	#0
	streq r3, [r2, #40]!    //CLR
	strne r3, [r2, #28]!    //SET

	bx	lr


//-----------------------------------------------------
WaitDelay:
//sets a delay based on parameters so that the latch, clock, and data lines remain in-sync
//receives: r1- delay time
//returns: nothing
//
//-----------------------------------------------------
	//confusing timer, dont quite get it, in slides verbatim
	ldr	r2,	=0x3F003004		//address of system timer interface CLO timer counter
	ldr	r3,	[r2]		//old/original time
	add r3, r1  //this isntruction takes time (1 us per addition)
	
delayLoop:
	ldr r0, [r2]  //original, unchanging 	CLO value
	cmp	r3,	r0		//compare changing CLO value(r3) with original unchanging CLO value(r0). stop when r3 reaches the desired time value
	bhi		delayLoop	//loop until current time = desired time


	bx		lr



//-----------------------------------------------------
ReadData:
//Reads a bit from the GPIO data line
//receives: nothing
//returns: r0- code of a pressed button (0 or 1)
//
//-----------------------------------------------------
	ldr	r2,	=0x3F200034		//address of GPLEV0 register
	ldr	r1,	[r2]			//value in register into r1


	mov r3, #1	//put 1 into r3 to compare to be able to read
	lsl	r3,	#10	//set up to read (by comparing) from pin10-data, by aliging it (r3 now aligned with pin 10)
	and r1,	r3	//mask everything else, only pin 10 is being compared now, if r1 is also 1, then this AND op. results in 1, and then teq will give a 0, which makes the function return a 0

	teq	r1,	#0		//xor (same=0, ZF=1, moveq, different =1, ZF=1, movne)
	moveq r0, #0	//should I load into some memory instead, since mov will replace? if the value in GPLEV (r1)  was 1 then return a 0 (return that a button was pressed=0)
	movne r0, #1	//likewise, return a 0 if r1 was a 1 (return that a button was not pressed = 1)

	bx	lr


//-----------------------------------------------------
ReadSNES:
//Reads inputs from SNES controller, and return a code into a register that specifies which button was pressed
//receives: r0- bit array, r2- shifted index to determine where new bit is stored
//returns: r0-updated bit array, r1- whether the button was pressed (0-press or 1-not)
//
//-----------------------------------------------------

	push	{r4, r5, lr}		//save registers
	mov r5, r2					//r2 and r0 get changed in ReadData. so save them to other registers for use in THIS 							//subroutine
	mov r4, r0

	bl		ReadData		//get bit from GPLEV and store it in r0


	
	lsl r0, r5			//shift the incoming bit, by current index in loop
	orr	r4, r0			//store the bit which is in r0, which is retrieved from ReadData, into LSB of r4 (ex.r0=0001 and r4= 1010
						//so then r3 will =1011 (and later left shifted to allow a new bit))

	mov r0, r4			//mov entire bit array into r0 for returning and later storing into r10

	pop		{r4, r5, lr}	//pop r4 into r4, r5 into r5, and lr into lr
	bx	lr					//return from function



//-----------------------------------------------------
TranslateCode:
//Takes 16 bits representing a button press and determines what button was pressed by saving the index of the button into a register, r3
//receives: r3- code value from 0 to 16 representing a button press
//returns: nothing
//
//-----------------------------------------------------

	push		{lr}			//save lr and pop into pc at end

	//exit the program if START was pressed
	cmp	r3, #3
	ldreq	r0, =promptPressStart		 //address pointer to beginning of introText in memory
	bleq		PrintMessage				//print message
	beq		haltLoop$					//jump to end program

	//Print the appropriate button prompt for the respective button press

	cmp	r3,	#0
	ldreq	r0, =promptPressB		 //address pointer to beginning of introText in memory
	bleq		PrintMessage				//print message


	cmp	r3,	#1
	ldreq	r0, =promptPressY		 //address pointer to beginning of introText in memory
	bleq		PrintMessage				//print message


	cmp	r3,	#2
	ldreq	r0, =promptPressSelect		 //address pointer to beginning of introText in memory
	bleq		PrintMessage				//print message


	cmp	r3,	#4
	ldreq	r0, =promptPressUp		 //address pointer to beginning of introText in memory
	bleq		PrintMessage				//print message


	cmp	r3,	#5
	ldreq	r0, =promptPressDown		 //address pointer to beginning of introText in memory
	bleq		PrintMessage				//print message


	cmp	r3,	#6
	ldreq	r0, =promptPressLeft		 //address pointer to beginning of introText in memory
	bleq		PrintMessage				//print message


	cmp	r3,	#7
	ldreq	r0, =promptPressRight		 //address pointer to beginning of introText in memory
	bleq		PrintMessage				//print message


	cmp	r3,	#8
	ldreq	r0, =promptPressA		 //address pointer to beginning of introText in memory
	bleq		PrintMessage				//print message

	cmp	r3,	#9
	ldreq	r0, =promptPressX		 //address pointer to beginning of introText in memory
	bleq		PrintMessage				//print message


	cmp	r3,	#10
	ldreq	r0, =promptPressLTrigger		 //address pointer to beginning of introText in memory
	bleq		PrintMessage				//print message


	cmp	r3,	#11
	ldreq	r0, =promptPressRTrigger		 //address pointer to beginning of introText in memory
	bleq		PrintMessage				//print message


	//ELSE if no button pressed then loop back to top and wait for button press
	pop		{pc}		//pushes saved LR into PC, auto-jumps back out of subroutine



//-----------------------------------------------------
PrintMessage:
//Uses the apporpriate address in memory to print a prompt to the screen
//receives: r0, the address containing the text to be printed
//returns: nothing
//
//-----------------------------------------------------
	push {lr}
	mov	r1,	#29				//the length of the string to be printed
	bl 		WriteStringUART   //call subroutine to write to screen
	pop  {pc}			//push saved LR into PC. This auto-jumps back to what LR was pointing to 









.section .data

	promptIntroMessage:
		.asciz "\n\rCreated by: Sajid Choudhry\n\r"	//Total one byte, 30 characters

    promptPressButton:
  		.asciz	"\n\rPlease press a button....\n\r"	//29


  	promptPressB:
  		.asciz	"\n\rYou pressed B            \n\r"

  	promptPressY:
  		.asciz	"\n\rYou pressed Y            \n\r"

  	promptPressSelect:
  		.asciz	"\n\rYou pressed SELECT       \n\r"

  	promptPressStart:
  		.asciz	"\n\r***Program is Terminating\n\r"

  	promptPressUp:
  		.asciz	"\n\rYou pressed Joy-pad UP   \n\r"

  	promptPressDown:
  		.asciz	"\n\rYou pressed Joy-pad DOWN \n\r"

  	promptPressLeft:
  		.asciz	"\n\rYou pressed Joy-pad LEFT \n\r"

  	promptPressRight:
  		.asciz	"\n\rYou pressed Joy-pad RIGHT\n\r"

  	promptPressA:
  		.asciz	"\n\rYou pressed A            \n\r"

  	promptPressX:
  		.asciz	"\n\rYou pressed X            \n\r"

  	promptPressLTrigger:
  		.asciz	"\n\rYou pressed LEFT TRIGGER \n\r"

  	promptPressRTrigger:
  		.asciz	"\n\rYou pressed RIGHT TRIGGER\n\r"


    DelayTime:
      .int  1000000
