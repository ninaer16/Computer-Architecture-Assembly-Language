# Title of Project: Drowsiness Detection and Yawning Monitoring
# Group Members:
# 1 UNGKU QISTINA BINTI UNGKU MOHD FARIS 2215442
# 2 RABIATUL ADAWIYAH BINTI MOHD ALWI 2217808
# 3 NUR AMIROTUL IZZAH BINTI MOHAMAD FAIZAL 2216966
# 4 NADHIRAH BINTI MUHAMMED NAJMUDDIN 2212502
# Section: 1

# Description: 
# This program is designed for drowsiness detection and yawning monitoring. 
# It processes eye state and mouth state data from input files, and head pitch data entered by the user, 
# to calculate PERCLOS, yawn frequency, and average pitch values.
# Alerts are triggered when these metrics exceed predefined thresholds, ensuring real-time identification of potential safety risks.

.data
filename1:    		.asciiz "eye_states2.txt"      		# Input file name
filename2:    		.asciiz "mouth_states2.txt"      	# Input file name
eye_data:    		.space 400                     		# Space for reading eye states (assume max 400 lines)
mouth_data:    		.space 400                     		# Space for reading eye states (assume max 400 lines)
eye_max_time:    	.word 60                       		# Max time interval to process (1 minute)
mouth_max_time:    	.word 30                       		# Max time interval to process (1 minute)
eye_threshold:  	.float 0.24                    		# Threshold for drowsiness detection
mouth_threshold:   	.float 0.16                    		# Threshold for yawning detection
pitch_threshold:    	.float 30.0                  		# Threshold for average pitch
pitch_values:       	.space 100                   		# Reserve space for pitch values (max 25 floats)
pitch_count:        	.word 0                      		# Initialize pitch count to 0
perclos_msg: 		.asciiz "PERCLOS value is: "   		# Message for PERCLOS value
yawn_msg:    		.asciiz "Yawning detected! Hazard lights will be switched on.\n"
yawn_msg_val:		.asciiz "Yawn Frequency Value is:"   			# Message for yawn frequency value
alert_msg:          	.asciiz "Drowsiness detected! Alert triggered\n"
average_msg:        	.asciiz "Average Pitch Angle is: "
no_alert_msg:       	.asciiz "No drowsiness detected. Monitoring continues...\n"
prompt_count_msg:   	.asciiz "Insert the number of pitch: "
prompt_value_msg:   	.asciiz "Insert the value of pitch: "
newline: 		.asciiz "\n"

# .text section
.text

process_mouth_states:
    # Initialize registers
    li   $t1, 0                           # open_mouth_count = 0
    li   $t2, 0                           # total_count = 0
    li   $t8, 0                           # yawn_duration = 0
    li   $t9, 0                           # max_yawn_duration = 0
    la   $t3, mouth_data                  # Pointer to mouth data buffer
    lw   $t4, mouth_max_time              # Load max_time for processing cycle

    # Step 1: Open the file
    li   $v0, 13                          # Syscall for file open
    la   $a0, filename2                   # Load address of file name
    li   $a1, 0                           # Read-only mode
    syscall
    move $t5, $v0                         # Save file descriptor

    # Step 2: Read file into memory
    li   $v0, 14                          # Syscall for file read
    move $a0, $t5                         # File descriptor
    la   $a1, mouth_data                  # Buffer for file data
    li   $a2, 400                         # Max bytes to read
    syscall
    move $t6, $v0                         # Save number of bytes read

count_loop:
    # Check if we reached max_time or processed all bytes
    beq  $t2, $t4, compute_yawn_freq      # Stop when 60 entries processed
    beq  $t6, $t2, compute_yawn_freq      # Stop when all bytes read

    lb   $t7, 0($t3)                      # Load byte from memory
    addi $t3, $t3, 1                      # Move pointer to next byte

    # Check for '0' (mouth closed)
    bne  $t7, 48, check_one               # If not '0', check for '1'
    addi $t2, $t2, 1                      # Increment total_count
    move $t8, $zero                       # Reset yawn_duration when mouth is closed
    j    count_loop                       # Continue loop

check_one:
    # Check for '1' (mouth open)
    bne  $t7, 49, count_loop              # Ignore invalid characters
    addi $t1, $t1, 1                      # Increment open_mouth_count
    addi $t2, $t2, 1                      # Increment total_count
    addi $t8, $t8, 1                      # Increment yawn_duration

    # Track max yawn duration
    bgt  $t8, $t9, update_max_duration    # Update max duration if needed
    j    count_loop                       # Continue loop

update_max_duration:
    move $t9, $t8                         # Set max_yawn_duration = current yawn_duration
    j    count_loop                       # Continue loop

# Step 3: Compute Yawn Frequency
compute_yawn_freq:
    mtc1 $t1, $f4                         # Move open_mouth_count to $f4 (int to float)
    mtc1 $t2, $f6                         # Move total_count to $f6 (int to float)
    cvt.s.w $f4, $f4                      # Convert to float
    cvt.s.w $f6, $f6                      # Convert to float
    div.s $f8, $f4, $f6                   # Yawn Frequency = open_mouth_count / total_count

    div.s $f8, $f4, $f6                   # Compute Yawn Frequency = open_mouth_count / total_count

    # Print Yawn Frequency value
    la   $a0, newline                     # Load the address of the newline label
    jal  print_string
    la   $a0, yawn_msg_val                # Load message for yawn frequency
    jal  print_string
    li   $v0, 2                           # Syscall for printing a float
    mov.s $f12, $f8                       # Move Yawn Frequency value to $f12
    syscall

    # Step 4: Compare Yawn Frequency to threshold
    la   $a0, mouth_threshold             # Load threshold value
    lwc1 $f10, 0($a0)                     # Load threshold into $f10
    c.le.s $f10, $f8                      # Compare Yawn Frequency <= threshold
    bc1f no_alert                         # Skip alarm if condition is false

    # Step 5: Check max_yawn_duration >= 6 seconds
    li   $t0, 6                           # Load 6 seconds duration
    blt  $t9, $t0, process_eye_states    # If max_yawn_duration < 6, skip alarm

    # Print yawning detected message
    la   $a0, newline                     # Load the address of the newline label
    jal  print_string
    la   $a0, yawn_msg                    # Load yawning message
    jal  print_string

process_eye_states:
    # Initialize $t1, $t2, $t3, $t4
    li   $t1, 0                           # Initialize closed_count to 0
    li   $t2, 0                           # Initialize total_count to 0
    la   $t3, eye_data                    # Pointer of eye data buffer
    lw   $t4, eye_max_time                # Max time to process data for each cycle (1 cycle = 1 minute = 60 sec)

    # Step 1: Open the file
    li   $v0, 13                          # Load syscall to open file
    la   $a0, filename1                   # Load address of file name
    syscall
    move $t5, $v0                         # Save file descriptor in a register

    # Step 2: Read file into memory
    li   $v0, 14                          # Load the syscall to read file
    move $a0, $t5                         # Load file descriptor
    la   $a1, eye_data                    # Load address of buffer to store data
    li   $a2, 400                         # Max bytes to read
    syscall
    move $t6, $v0                         # Save the number of bytes read

count_loop_eye:
    # Check if we have reached the max time or read 60 entries
    beq  $t2, $t4, compute_perclos        # Stop the loop after processing 60 bytes
    beq  $t6, $t2, compute_perclos        # Exit loop if all bytes processed

    lb   $t7, 0($t3)                      # Load byte from memory
    addi $t3, $t3, 1                      # Increase the pointer by 1

    # Ignore non-'0' and non-'1' characters
    bne  $t7, 48, check_one_eye           # If data is not '0', then check for '1'
    addi $t1, $t1, 1                      # Increase closed_count by 1
    addi $t2, $t2, 1                      # Increase total_count by 1
    j    count_loop_eye                   # Continue loop

check_one_eye:
    bne  $t7, 49, count_loop_eye          # If not '1', skip the increment
    addi $t2, $t2, 1                      # Increment total_count
    j    count_loop_eye                   # Continue loop

# Step 3: Compute PERCLOS = closed_count / total_count
compute_perclos:
    # Ensure proper conversion to float
    mtc1 $t1, $f4                         # Move closed_count to $f4 (integer to float)
    mtc1 $t2, $f6                         # Move total_count to $f6 (integer to float)
    cvt.s.w $f4, $f4                      # Convert $f4 (closed_count) to float
    cvt.s.w $f6, $f6                      # Convert $f6 (total_count) to float
    div.s $f8, $f4, $f6                   # PERCLOS = closed_count / total_count

    # Step 4: Print PERCLOS value
    la   $a0, newline                     # Load the address of the newline label
    jal  print_string
    la   $a0, perclos_msg                 # Load address of PERCLOS message
    jal  print_string
    li   $v0, 2                           # Load print float syscall code
    mov.s $f12, $f8                       # Load PERCLOS value to print
    syscall

    # Step 5: Compare PERCLOS to threshold
    la   $a0, eye_threshold               # Load address of threshold
    lwc1 $f10, 0($a0)                     # Load threshold value into $f10
    c.le.s $f10, $f8                      # Compare PERCLOS with threshold value
    bc1f process_head_states             # If less than or equal to threshold value, skip alarm message

    # Step 6: Print "Drowsiness detected! Alert triggered"
    la   $a0, newline                     # Load the address of the newline label
    jal  print_string
    la   $a0, alert_msg                   # Load address of alarm message
    jal  print_string

process_head_states:
    la   $a0, newline                     # Load the address of the newline label
    jal  print_string

    # Step 1: Prompt user for the number of pitch values
    la   $a0, prompt_count_msg            # Load prompt message
    jal  print_string
    li   $v0, 5                           # Syscall for reading an integer
    syscall
    move $t1, $v0                         # Store pitch count in $t1
    sw   $t1, pitch_count                 # Save pitch count to memory

    # Step 2: Prompt user to enter pitch values
    la   $t0, pitch_values                # Load base address of pitch_values array
    li   $t3, 0                           # Initialize index counter

input_loop:
    beq  $t3, $t1, process_values         # Exit loop when all values are entered
    la   $a0, prompt_value_msg            # Load prompt message for value input
    jal  print_string
    li   $v0, 6                           # Syscall for reading a float
    syscall
    s.s  $f0, 0($t0)                      # Store input value in the array
    addi $t0, $t0, 4                      # Move to the next float in the array
    addi $t3, $t3, 1                      # Increment index counter
    j    input_loop                       # Continue loop

process_values:
    # Initialize pointers and counters
    la   $t0, pitch_values                # Load address of pitch_values
    lw   $t1, pitch_count                 # Load the count of pitch values
    li   $t2, 0                           # Counter for consecutive threshold violations
    li   $t3, 0                           # Index counter

    # Initialize floating-point accumulator to 0.0
    li   $t4, 0                           # Load 0 into a general-purpose register
    mtc1 $t4, $f1                         # Move 0 from $t4 to the floating-point register
    cvt.s.w $f1, $f1                      # Convert the integer 0 to a single-precision float

sum_loop:
    beq  $t3, $t1, calculate_avg          # Exit loop when all values are processed
    l.s  $f0, 0($t0)                      # Load current pitch value
    add.s $f1, $f1, $f0                   # Accumulate sum in $f1

    # Step 3: Check if pitch exceeds threshold
    l.s  $f2, pitch_threshold             # Load threshold
    c.le.s $f2, $f0                       # Check if pitch > threshold
    bc1f reset_count                      # If false, reset counter

    # Increment consecutive violation counter
    addi $t2, $t2, 1
    j    next_value

reset_count:
    li   $t2, 0                           # Reset counter if pitch <= threshold

next_value:
    addi $t0, $t0, 4                      # Move to the next pitch value
    addi $t3, $t3, 1                      # Increment index counter
    j    sum_loop                         # Repeat the loop

calculate_avg:
    # Step 4: Calculate average (sum / count)
    mtc1 $t1, $f3                         # Move pitch_count to floating-point register
    cvt.s.w $f3, $f3                      # Convert pitch_count to single-precision float
    div.s $f4, $f1, $f3                   # Compute average pitch in $f4

    # Step 5: Display average pitch message
    la   $a0, average_msg                 # Load address of average_msg
    jal  print_string

    # Step 6 :Display the average pitch value
    li   $v0, 2                           # Syscall for printing a float
    mov.s $f12, $f4                       # Move average pitch to $f12 for printing
    syscall

    la   $a0, newline                     # Load the address of the newline label
    jal  print_string

    # Step 7: Check if alert should be triggered
    blt  $t2, 3, no_alert                 # If consecutive violations < 3, no alert
    la   $a0, alert_msg                   # Load alert message
    jal  print_string
    j    exit

no_alert:
    la   $a0, no_alert_msg                # Display no alert message
    jal  print_string

exit:
    # Close the file
    li   $v0, 16                          # Syscall for file close
    move $a0, $t5                         # File descriptor
    syscall

    # Exit program
    li   $v0, 10                          # Syscall for exit
    syscall

print_string:
    li   $v0, 4                           # Syscall for printing a string
    syscall
    jr   $ra                              # Return to caller
