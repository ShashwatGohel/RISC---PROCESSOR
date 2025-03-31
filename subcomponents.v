`timescale 1ns / 1ps
// This line sets the timing for the simulation (1 nanosecond steps), don’t worry about it too much.

module SRAM (
    input clk,             // The clock, like a heartbeat that makes things happen at the right time.
    input Reset,           // A button to reset everything back to start.
    input [7:0] Address,   // A number (0-255) that says where to look in memory (like a house address).
    input SRAMRead,        // A signal that says "I want to read from memory."
    input SRAMWrite,       // A signal that says "I want to write to memory."
    input [7:0] Datain,    // The data (8 bits, like a small number) we want to put into memory.
    output reg [7:0] Dataout // The data (8 bits) we get out of memory.
);
    reg [7:0] datamem [0:255];  // This is our memory box: 256 slots, each holding an 8-bit number.

    always @(posedge clk or posedge Reset) begin  // This block runs every time the clock ticks or reset is pressed.
        if (Reset) begin          // If reset is on...
            Dataout <= 8'b0;      // Set the output to zero (8 bits of 0s).
        end else begin            // If reset is off...
            if (SRAMWrite)        // If we’re told to write...
                datamem[Address] <= Datain;  // Put the input data into the memory slot at the given address.
            if (SRAMRead)         // If we’re told to read...
                Dataout <= datamem[Address]; // Grab the data from that memory slot and send it out.
        end
    end
endmodule  // This ends the SRAM memory box.

module Stack (
    input clk,             // The clock, our timing heartbeat again.
    input Reset,           // The reset button to start over.
    input StackRead,       // A signal saying "take something off the stack."
    input StackWrite,      // A signal saying "put something on the stack."
    input [7:0] Datain,    // The 8-bit data we want to add to the stack.
    output reg [7:0] Dataout // The 8-bit data we get from the stack.
);
    reg [7:0] stack_pointer;    // A number (0-255) that tracks the top of our stack (like a bookmark).
    wire [7:0] sram_dataout;    // A wire to carry data coming out of the SRAM memory.
    wire [7:0] mux_data_out;    // A wire to carry data picked by our switch (MUX).

    SRAM stack_sram (           // This is our memory box (SRAM) used for the stack.
        .clk(clk),              // Connect the clock to the SRAM.
        .Reset(Reset),          // Connect the reset to the SRAM.
        .Address(stack_pointer), // Tell SRAM to use the stack pointer as the address.
        .SRAMRead(StackRead),   // Tell SRAM when to read based on StackRead.
        .SRAMWrite(StackWrite), // Tell SRAM when to write based on StackWrite.
        .Datain(mux_data_out),  // Send the switch’s output to SRAM as input data.
        .Dataout(sram_dataout)  // Get the data out of SRAM into this wire.
    );

    MUX4to1_8bit mux_data (     // This is a switch (MUX) that picks between 4 options.
        .sel({StackWrite, StackRead}), // Use StackWrite and StackRead to decide (like a 2-bit code: 00, 01, 10, 11).
        .in0(8'b0),             // Option 0: just zero (8 bits of 0s).
        .in1(sram_dataout),     // Option 1: data from SRAM (when reading).
        .in2(Datain),           // Option 2: new data to write (when pushing).
        .in3(8'b0),             // Option 3: zero again (not really used).
        .out(mux_data_out)      // The chosen data goes here.
    );

    always @(posedge clk or posedge Reset) begin  // This runs on every clock tick or reset.
        if (Reset) begin          // If reset is pressed...
            stack_pointer <= 8'hFF; // Set the stack pointer to 255 (top of the stack).
            Dataout <= 8'b0;      // Set the output to zero.
        end else begin            // If no reset...
            if (StackWrite && stack_pointer != 8'h00) begin  // If we’re writing and stack isn’t full (0)...
                stack_pointer <= stack_pointer - 1; // Move the pointer down (like adding a book to the stack).
                Dataout <= Datain;      // Show the new data we’re adding.
            end
            if (StackRead && stack_pointer != 8'hFF) begin   // If we’re reading and stack isn’t empty (255)...
                stack_pointer <= stack_pointer + 1; // Move the pointer up (like taking a book off).
                Dataout <= sram_dataout; // Show the data we got from SRAM.
            end
        end
    end
endmodule  // This ends the stack.

module ALU (
    input clk,             // The clock, our timing heartbeat.
    input Reset,           // The reset button.
    input Imm7,            // A switch saying if Operand2 is a tiny number (1 bit) or full size (8 bits).
    input [7:0] Operand1,  // First number (8 bits) to work with.
    input [7:0] Operand2,  // Second number (8 bits) to work with.
    input [4:0] Opcode,    // A 5-bit code telling us what math to do (like 00000 for add).
    input ALUSave,         // A signal to save the result.
    input ZflagSave,       // A signal to save the "zero" flag.
    input CflagSave,       // A signal to save the "carry" flag.
    output reg Zflag,      // A flag that says "result is zero" (1 if true, 0 if not).
    output reg Cflag,      // A flag that says "there’s a carry" (like an extra bit from adding).
    output reg [7:0] ALUout // The result of our math (8 bits).
);
    reg [8:0] temp_result;  // A 9-bit spot to hold the result temporarily (extra bit for carry).

    always @(posedge clk or posedge Reset) begin  // Runs on every clock tick or reset.
        if (Reset) begin          // If reset is on...
            ALUout <= 8'b0;       // Set the result to zero.
            Zflag <= 1'b0;        // Set the zero flag to "not zero."
            Cflag <= 1'b0;        // Set the carry flag to "no carry."
        end else if (ALUSave) begin  // If we’re told to save a result...
            case (Opcode)         // Look at the Opcode to decide what to do.
                5'b00000: begin   // If Opcode is 00000 (add)...
                    temp_result = Operand1 + (Imm7 ? {7'b0, Operand2[0]} : Operand2); // Add Operand1 and Operand2 (small if Imm7 is on).
                    ALUout <= temp_result[7:0]; // Save the bottom 8 bits as the result.
                end
                5'b00001: begin   // If Opcode is 00001 (subtract)...
                    temp_result = Operand1 - (Imm7 ? {7'b0, Operand2[0]} : Operand2); // Subtract Operand2 from Operand1.
                    ALUout <= temp_result[7:0]; // Save the bottom 8 bits.
                end
                5'b00010: begin   // If Opcode is 00010 (AND)...
                    ALUout <= Operand1 & (Imm7 ? {7'b0, Operand2[0]} : Operand2); // Do a bitwise AND (like matching 1s).
                    temp_result = {1'b0, ALUout}; // Store result with a 0 on top (no carry here).
                end
                5'b00011: begin   // If Opcode is 00011 (OR)...
                    ALUout <= Operand1 | (Imm7 ? {7'b0, Operand2[0]} : Operand2); // Do a bitwise OR (combine 1s).
                    temp_result = {1'b0, ALUout}; // Store with a 0 on top.
                end
                5'b00100: begin   // If Opcode is 00100 (XOR)...
                    ALUout <= Operand1 ^ (Imm7 ? {7'b0, Operand2[0]} : Operand2); // Do a bitwise XOR (1 if different).
                    temp_result = {1'b0, ALUout}; // Store with a 0 on top.
                end
                default: begin    // If Opcode is anything else...
                    ALUout <= 8'b0;       // Set result to zero.
                    temp_result = 9'b0;   // Clear the temp spot too.
                end
            endcase
            if (ZflagSave)        // If we’re told to save the zero flag...
                Zflag <= (temp_result[7:0] == 8'b0); // Set to 1 if result is zero, 0 if not.
            if (CflagSave)        // If we’re told to save the carry flag...
                Cflag <= temp_result[8]; // Set to 1 if there’s an extra bit (carry), 0 if not.
        end
    end
endmodule  // This ends the ALU.

module MUX4to1_8bit (
    input [1:0] sel,       // A 2-bit code to pick one of 4 inputs (like a remote control).
    input [7:0] in0,       // First option: an 8-bit number.
    input [7:0] in1,       // Second option: another 8-bit number.
    input [7:0] in2,       // Third option: another 8-bit number.
    input [7:0] in3,       // Fourth option: another 8-bit number.
    output reg [7:0] out   // The chosen 8-bit number goes here.
);
    always @(*) begin      // This runs instantly whenever inputs change.
        case (sel)         // Look at the selection code...
            2'b00: out = in0;    // If sel is 00, pick in0.
            2'b01: out = in1;    // If sel is 01, pick in1.
            2'b10: out = in2;    // If sel is 10, pick in2.
            2'b11: out = in3;    // If sel is 11, pick in3.
            default: out = in0;  // If sel is weird, just pick in0.
        endcase
    end
endmodule  // This ends the switch (MUX).