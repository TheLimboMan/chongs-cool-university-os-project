#!/bin/bash
# BTS3453 - Operating System - Group Project
# Server Management Tool
# Group members: TG23032, TG23031, TG23029

# ==========================================
# COLOR CONFIGURATIONS (ANSI Escape Codes)
# ==========================================
C='\033[1;36m'   # Cyan
Y='\033[1;33m'   # Yellow
G='\033[1;32m'   # Green
M='\033[1;35m'   # Magenta
B='\033[1;34m'   # Blue
W='\033[1;37m'   # White
RE='\033[1;31m'  # Red
R='\033[0m'      # Reset

# ==========================================
# FUNCTION: clist (Cool File List)
# Purpose: Lists directory contents in a highly readable, color-coded custom table.
# Arguments: $1 - Target directory path
# ==========================================
clist() {
    # Print the table header with specific column widths and alignments
    printf "${C}%-11s ${Y}%-3s ${G}%-8s ${G}%-8s ${M}%-6s ${B}%-12s ${W}%s${R}\n" "PERMS" "LNK" "OWNER" "GROUP" "SIZE" "MOD_DATE" "NAME"
    
    # 1. ls -ahlr: Lists all files, human-readable sizes, reversed order.
    # 2. tail -n +2: Skips the first line (the "total x" line outputted by ls).
    # 3. awk: Parses each column, applies specific colors, and handles multi-word filenames.
    ls -ahlr --color=never "$1" | tail -n +2 | awk -v c="$C" -v y="$Y" -v g="$G" -v m="$M" -v b="$B" -v r="$R" '{
        # Format and color individual properties (Permissions, Links, Owner, Group, Size, Date)
        printf c "%-11s " y "%-4s " g "%-8s " g "%-8s " m "%-6s " b "%-12s " r, $1, $2, $3, $4, $5, $6" "$7" "$8;
        
        # Loop through columns 9 onwards to completely reconstruct filenames that contain spaces
        for(i=9;i<=NF;i++) printf "%s ", $i; print ""
    }' | more -d # Pipe to 'more' with down-navigation alerts for pagination
}

# ==========================================
# FUNCTION: plist (Cool Process & Memory List)
# Purpose: Displays current system memory consumption and top CPU-hogging processes.
# ==========================================
plist() {
    echo -e "${Y}================ MEMORY USAGE ================${R}"
    
    # Parse the 'free -h' command output to display custom-formatted memory metrics
    free -h | awk -v c="$C" -v r="$R" '
        NR==1 {
            # Row 1: Format and color the headers (total, used, free, shared, buff/cache, available)
            printf c "%-12s %-10s %-10s %-10s %-10s %-10s %-10s" r "\n", "", $1, $2, $3, $4, $5, $6
        } 
        NR>1 {
            # Row 2+: Print Mem and Swap values under their respective headers
            printf "%-12s %-10s %-10s %-10s %-10s %-10s %-10s\n", $1, $2, $3, $4, $5, $6, $7
        }'
    
    echo ""

    echo -e "${G}============= CPU PROCESSES =============${R}"
    # Print process summary header
    printf "${B}%-10s %-8s %-6s %-6s %-15s${R}\n" "USER" "PID" "%CPU" "%MEM" "COMMAND"
    
    # 1. ps -eo: Selects specific outputs (user, pid, cpu percentage, memory percentage, command)
    # 2. --sort=-pcpu: Sorts descending by CPU usage
    # 3. head -n 11: Grabs the top 10 processes (+1 header row)
    ps -eo user,pid,pcpu,pmem,comm --sort=-pcpu | head -n 11 | \
    awk '{printf "%-10s %-8s %-6s %-6s %-15s\n", $1, $2, $3, $4, $5}' | more -d
    
    echo -e "${G}==============================================${R}"
}

# ==========================================
# FUNCTION: sysfetch (System Details Overview)
# Purpose: Fetches core hardware specifications and OS statistics cleanly.
# ==========================================
sysfetch() {
    # Extract active environment details
    local user_host="${USER}@$(hostname)"
    local os=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d'"' -f2)
    local kernel=$(uname -sr)
    local uptime=$(uptime -p | sed 's/up //')
    local shell=$(basename "$SHELL")
    
    # Calculate RAM metrics by parsing /proc/meminfo (values in kB converted to MB)
    local mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    local mem_avail=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
    local mem_used=$(( (mem_total - mem_avail) / 1024 ))
    local mem_total_mb=$(( mem_total / 1024 ))

    # Strip out trailing spaces and marketing symbols ((R), (TM)) from the CPU model string
    local cpu=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^[ \t]*//;s/(R)//;s/(TM)//')

    # Print the system specifications out to the user interface
    echo -e "${C}${user_host}${R}"
    echo -e "${C}$(printf '%.s-' $(seq 1 ${#user_host}))${R}" # Creates a dynamic underline matching user_host length
    echo -e "${Y}OS:     ${R}${os}"
    echo -e "${Y}Kernel: ${R}${kernel}"
    echo -e "${Y}Uptime: ${R}${uptime}"
    echo -e "${Y}Shell:  ${R}${shell}"
    echo -e "${Y}CPU:    ${R}${cpu}"
    echo -e "${Y}Memory: ${R}${mem_used}MB / ${mem_total_mb}MB"
}

# ==========================================
# FUNCTION: colorconfig (Network Config Visualizer)
# Purpose: Formats the clumsy output of `ifconfig` into a clean administrative table.
# ==========================================
colorconfig() {
    # Run ifconfig and process the streaming block chunks via awk
    ifconfig "$@" | awk \
    -v C="$C" -v Y="$Y" -v G="$G" -v M="$M" -v B="$B" -v W="$W" -v RE="$RE" -v R="$R" '
    
    BEGIN {
        # Initialize table columns on start
        printf "%-12s | %-6s | %-15s | %-15s | %-15s | %-17s\n", "INTERFACE", "STATE", "IP ADDRESS", "NETMASK", "BROADCAST", "MAC ADDRESS"
        printf "-------------+--------+-----------------+-----------------+-----------------+-------------------\n"
    }

    # Custom function to print an aggregated interface row out to the table
    function print_row() {
        if (iface != "") {
            # Turn text Green if UP, Red if DOWN
            stat_color = (status == "UP" ? G : RE)
            
            printf "%s%-12s%s | %s%-6s%s | %s%-15s%s | %s%-15s%s | %s%-15s%s | %s%-17s%s\n", \
                   Y, iface, R, \
                   stat_color, status, R, \
                   C, ip, R, \
                   G, mask, R, \
                   M, bcast, R, \
                   B, mac, R
        }
    }

    # Regex: Matches the start of an interface block (lines starting with alpha-numerics)
    /^[a-zA-Z0-9]/ {
        print_row() # Print the previous block configuration before starting the new one
        
        iface = $1; sub(/:$/, "", iface) # Extract network block name and strip trailing colons
        ip = "-"; mask = "-"; bcast = "-"; mac = "-"; status = "DOWN" # Reset properties defaults
    }

    # Check for interface UP status markers
    /UP/ { status = "UP" }
    /status: active/ { status = "UP" }

    # Extract dynamic IP networking fields inside the inet configuration line
    /inet / {
        for (i=1; i<=NF; i++) {
            if ($i == "inet") ip = $(i+1)
            if ($i == "netmask") mask = $(i+1)
            if ($i == "broadcast") bcast = $(i+1)
        }
    }

    # Capture MAC address strings across Linux platform variants (ether vs HWaddr formats)
    /ether / { mac = $2 }
    /HWaddr / { mac = $5 }

    END {
        print_row() # Ensure the final processed interface card block is outputted
    }'
}

# ==========================================
# MAIN INTERACTIVE PROGRAM LOOP
# ==========================================
clear

while true; do
    clear
    echo "Server Management Tool"
    echo ""
    echo "1. Cool File Tool"
    echo "2. Cool Process Tool"
    echo "3. Cool Hardware Info Tool"
    echo "4. Quit"
    echo ""
    read -p "Please Type a number to choose a tool: " input

    # ------------------------------------------
    # OPTION 1: Cool File Tool (Interactive Directory Explorer)
    # ------------------------------------------
    if [ "$input" == "1" ]; then
        clear
        cd /
        read -p "Please enter a directory, or leave blank to view [root]: " dir1

        # Check if user input points to an actual existing directory
        if [ -d "$dir1" ]; then
            clear
            clist "$dir1"
            cd "$dir1" || continue
        else
            clear
            cd "/"
            clist "/"
        fi

        # Nested loop allowing ongoing deep navigation through directories
        while true; do
            echo ""
            read -e -p "Go to (type :q to back out): " dir2

            if [ "$dir2" == ":q" ]; then
                break # Exit the nested directory loop, returns to the primary home menu
            elif [ -d "$dir2" ]; then
                clear
                clist "$dir2"
                cd "$dir2" || continue
            else
                clear
                clist "."
                echo ""
                echo "Hey that is not a dicrectory!"
            fi
        done

    # ------------------------------------------
    # OPTION 2: Cool Process Tool (Monitor Memory and Core Processes)
    # ------------------------------------------
    elif [ "$input" == "2" ]; then
        clear
        plist | more -d
        read -n1 -r -p "Press any key to continue..." key

    # ------------------------------------------
    # OPTION 3: Cool Hardware/Network Info Tool (Sub-Menu Selection)
    # ------------------------------------------
    elif [ "$input" == "3" ]; then
        clear
        while true; do
            clear
            echo "View Hardware OR Network Info?"
            echo ""
            echo "1. Hardware"
            echo "2. Network"
            echo "3. Back"
            echo ""
            read -p "Please Type a number to choose: " choice
            
            if [ "$choice" == "1" ]; then
                clear
                sysfetch | more -d
                read -n1 -r -p "Press any key to continue..." key
            elif [ "$choice" == "2" ]; then
                clear
                colorconfig | more -df
                read -n1 -r -p "Press any key to continue..." key
            elif [ "$choice" == "3" ]; then
                break # Break out of sub-menu loop and return to main landing interface
            else
                continue # Re-loops if option doesn't exist
            fi
        done

    # ------------------------------------------
    # OPTION 4: Quit Program
    # ------------------------------------------
    elif [ "$input" == "4" ]; then
        clear
        echo "Byebye"
        exit
    else
        # Catch-all: If user drops an invalid integer on primary screen, refresh menu layout safely
        clear
    fi

done