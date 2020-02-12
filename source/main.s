/*
CPSC 359
Assignment 3- SNES Driver

This program initializes the latch, clock, and data lines of the SNES controller for output and input, respectively.
It then continuously prompts a user to press any button and displays which button was pressed to the screen.
The program terminates after the START button is pressed.

Created By: Sajid Choudhry

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

setLines:

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





	/*Print Introduction message*/

printIntro:

	ldr		r0, =promptIntroMessage		 //address pointer to beginning of introText in memory
  	mov		r1, #44						 //Number of characters in introText to be written to screen
  	bl 		WriteStringUART				 //call subroutine to write to screen





	/*Prompt user to enter a button. Set default button tracker value and clear bit array*/

requestButtonPress:

	//Request Button Press
	ldr		r0, =promptPressButton
	bl		PrintMessage










	/*Prepare to read clock pulses*/

loopLatch:

	//set values for loopLatch
  mov	r7,		#12		//Button tracker default. #12 defines no button press.
  mov r10,	#0		//contains complete values from data latch after clock finishes pulses



	//set latch line to 1 and clock to 1, wait 12 microseconds, and then set the latch line to 0.
    mov	r1,	#1
	bl	WriteLatch

    mov	r1,	#1
    bl	WriteClock

	mov r1,	#12
	bl	WaitDelay

	mov	r1,	#0
	bl	WriteLatch





	/*Pulse clock 16 times,
	Store data latch return values into register,
	Track button presses
	*/

	//loop counter and current button-index tracker
	mov	r8,	#0

loopClockData:

	//wait 6 microseconds, set clock line to 0, wait 6 microseconds
	mov r1,	#6
	bl	WaitDelay

	mov	r1,	#0
	bl	WriteClock

	mov r1,	#6
	bl	WaitDelay



	/*Read data latch value after clock pulse and store in register*/

	mov r2, r8				//current index to store new value in
	mov r0, r10 			//copy current bit array to r0
	bl	ReadSNES			//read and store incoming bit
	mov r10,  r0  			//copy updated bit array to r10

	//update button tracker, r7, with index of pressed button, if pressed
  bl RetrieveBitPIN
	cmp		r0,	#0
	moveq	r7, r8



	//set clock line to 1
	mov	r1,	#1
	bl	WriteClock


	//loop 16 times
	add	r8,	#1				//increment loop counter/current button index
	cmp	r8, #16
	bne		loopClockData





	/* Prevents multiple prints for a single button press */

preventRepeat:

    //set values for delay
    mov r1, #1
    lsl r1, #17

    //compare previous registered button press to current registered press
    //store value in r7 into r6 if they are not equal
    cmp r7, r6
    movne r6, r7

    //delay approx 0.25 seconds between registered button presses if registered press was equal
    bleq WaitDelay
    beq loopLatch






	/*Print button press and loop to ask for next one, or loop until button is pressed*/

handleData:

	//print according to value in button-tracker, r7
	mov	r3,	r7
	bl	TranslateCode

	//If no button is pressed, branch back and wait for a button press
    cmp r3, #11
    bgt	loopLatch

	//Reloop to reprompt user after a button has been successfully selected
	b		requestButtonPress





	/*Terminates the program*/
haltLoop$:
	b		haltLoop$





//-----------------------------------------------------
InitGPIO:
//Initializes a GPIO line
//receives: r0- GPIO line (decimal), r1- function code (b001 or b000)
//returns: nothing
//
//-----------------------------------------------------
	push  {r4,r5}

	ldr	r3,	=0x3F200000	//Load the base GPIO register



	//Determine the appropriate register address and PIN index number to work with
	cmp	r0,	#9
	addgt	r3,	#4		//GPIO address = 0x3F200004
	subgt	r0,	#10		//store PIN's appropriate index into r0

	//set r0 to appropriate bits to store values in
	mov r5, #0
	mov r5, #3
	mul r0, r5   		//r0= 3*bitIndex

	//clear incoming PINs appropriate bits
	ldr	r2,	[r3]		//loads the value of R3(register under consideration) into r2 for manipulation
	mov	r4,	#7			//r4= b0111
	lsl r4,	r0			//shift r4 to appropraite bit position
	bic	r2,	r4			//clear the appropriate bits in r2

	str	r2,	[r3]		//store cleared bits back into appropriate GPIO register



	//branch out of function if the function code was 0
	cmp r1,	#0b000
	bxeq	lr



	//store function code 001 into appropriate bits for the PIN 9 or PIN 11
	lsl	r1,	r0			//moves 001 into appropriate index for setting the PIN under considetation
	orr	r2,	r1			//sets the appropriate values in r2
	str	r2, [r3]		//store set bits back into appropriate GPIO register



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

	teq	r1,	#0
	streq r3, [r2, #40]		//set GPCLR0 PIN#9 to 1 if r1=0
	strne r3, [r2, #28]		//set GPSET0 PIN#9 to 1. if r1=1

	bx	lr




//-----------------------------------------------------
WriteClock:
//Writes a 0 or 1 to the clock Line
//receives: r1- value to write, either a 1 or a 0
//returns: nothing
//
//-----------------------------------------------------
	ldr	r2,	=0x3F200000		//address of base GPIO register

	mov r3, #1				//set least significant bit of r3 to 1
	lsl	r3,	#11				//align r3 to change the appropriate bit corresponding to PIN 11

	teq	r1,	#0
	streq r3, [r2, #40]!    //set GPCLR0 PIN#11 to 1 if r1=0
	strne r3, [r2, #28]!    //set GPSET0 PIN#11 to 1. if r1=1

	bx	lr




//-----------------------------------------------------
WaitDelay:
//sets a delay based on parameters so that the latch, clock, and data lines remain in-sync
//receives: r1- delay time(decimal)
//returns: nothing
//
//-----------------------------------------------------
	ldr	r2,	=0x3F003004		//address of system timer interface CLO timer counter
	ldr	r3,	[r2]			//read CLO
	add r3, r1  			//add delay time

delayLoop:

	ldr r0, [r2]
	cmp	r3,	r0				//stop when r3= CLO
	bhi		delayLoop


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


	//mask all except pin 10, for reading purposes
	mov r3, #1
	lsl	r3,	#10
	and r1,	r3


	//Return single bit value in GPLEV0 bit 10 and store in r0
	teq	r1,	#0
	moveq r0, #0
	movne r0, #1

	bx	lr




//-----------------------------------------------------
RetrieveBitPIN:
//Retrieves value stored in PIN 10 of GPLEV0
//receives: nothing
//returns: r0- value in r1 (0 or 1)
//
//-----------------------------------------------------
	//mask all except PIN 10 for reading purposes
	mov  r3, #1
	lsl  r3, #10
	and  r1, r3

	mov r0, r1

	bx	lr




//-----------------------------------------------------
ReadSNES:
//Reads inputs from SNES controller and updates a register with the values from each button
//receives: r0- old bit array, r2- shifted index to determine where new bit is stored
//returns: r0-updated bit array, r1- button press value (0-press or 1-not)
//
//-----------------------------------------------------
	push	{r4, r5, lr}

	//copy r2 and r0 to save their manipulated values
	mov r5, r2
	mov r4, r0

	//receive button press value stored in r0
	bl		ReadData


	//shift readData incoming bit, r0, to index of current button and then store that bit into appropriate position of r4
	lsl r0, r5
	orr	r4, r0

	//copy updated bit array into r0 to return
	mov r0, r4


	pop		{r4, r5, pc}





//-----------------------------------------------------
TranslateCode:
//Prints a button that was pressed or exits the program if START was pressed
//receives: r3- code value from 0 to 12 representing a button press or lack thereof
//returns: nothing
//
//-----------------------------------------------------

	push		{lr}


  //If no button is pressed branch out of subroutine
  cmp r3, #11
  popgt {pc}




  //first button data latch reads and first button print in data section of code
  ldr  r0, =promptPressB

  //loop counter
  mov r4, #0

  /*increment r0 to point to next print statement,
  based on the r3 value passed in */

multLoop:
  cmp r3, r4
  addne r0, #30     //adding #30 points to address of next print statement
  addne r4, #1
  bne multLoop

  //print the appropriate button to screen
  bl PrintMessage



  //Terminate the program if START is pressed
  cmp r3, #3
  beq haltLoop$

	//return from subroutine after statement has printed
	pop		{pc}




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
	pop  {pc}









.section .data

	promptIntroMessage:
		.asciz "\n\rCreated by: Sajid Choudhry and Ahmad Ali\n\r"	//Total one byte, 44 characters

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
