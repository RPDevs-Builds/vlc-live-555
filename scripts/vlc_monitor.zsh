#!/bin/zsh

# VLC-Live-555 Build Fleet Monitor (Ultra-Robust Zsh Version)
# Requirements: gh, jq

# Colors
GREEN='%F{green}'
RED='%F{red}'
YELLOW='%F{yellow}'
BLUE='%F{blue}'
CYAN='%F{cyan}'
NC='%f' 
BOLD='%B'
REG='%b'

refresh_interval=15

fetch_status() {
    local run_data=$(gh run list --repo RPDevs-Builds/vlc-live-555 --workflow=vlc-matrix-builder.yml --limit 1 --json databaseId,status,conclusion,displayTitle,createdAt,headBranch 2>/dev/null)
    
    if [[ -z "$run_data" || "$run_data" == "[]" ]]; then
        echo "VLC-Live-555|⚪|N/A|· · · ·|N/A|N/A"
        return
    fi

    local id=$(echo $run_data | jq -r '.[0].databaseId')
    local r_status=$(echo $run_data | jq -r '.[0].status')
    local r_conc=$(echo $run_data | jq -r '.[0].conclusion')
    local title=$(echo $run_data | jq -r '.[0].displayTitle' | cut -c 1-30)
    
    if [[ "$r_status" == "in_progress" || "$r_status" == "queued" ]]; then
        local jobs_data=$(gh run view --repo RPDevs-Builds/vlc-live-555 $id --json jobs 2>/dev/null)
        
        # Platform Matrix Logic
        local p_linux_dev=$(echo $jobs_data | jq -r '.jobs[] | select(.name == "Build VLC (linux-x64 - dev)") | "\(.status)|\(.conclusion)"')
        local p_linux_stable=$(echo $jobs_data | jq -r '.jobs[] | select(.name == "Build VLC (linux-x64 - stable)") | "\(.status)|\(.conclusion)"')
        local p_arm_dev=$(echo $jobs_data | jq -r '.jobs[] | select(.name == "Build VLC (armlinux - dev)") | "\(.status)|\(.conclusion)"')
        local p_arm_stable=$(echo $jobs_data | jq -r '.jobs[] | select(.name == "Build VLC (armlinux - stable)") | "\(.status)|\(.conclusion)"')
        local p_win_dev=$(echo $jobs_data | jq -r '.jobs[] | select(.name == "Build VLC (win64 - dev)") | "\(.status)|\(.conclusion)"')
        local p_win_stable=$(echo $jobs_data | jq -r '.jobs[] | select(.name == "Build VLC (win64 - stable)") | "\(.status)|\(.conclusion)"')
        local p_mac_dev=$(echo $jobs_data | jq -r '.jobs[] | select(.name == "Build VLC (macos-x64 - dev)") | "\(.status)|\(.conclusion)"')
        local p_mac_stable=$(echo $jobs_data | jq -r '.jobs[] | select(.name == "Build VLC (macos-x64 - stable)") | "\(.status)|\(.conclusion)"')
        local p_pi_dev=$(echo $jobs_data | jq -r '.jobs[] | select(.name == "Build VLC (raspberrypi - dev)") | "\(.status)|\(.conclusion)"')
        local p_pi_stable=$(echo $jobs_data | jq -r '.jobs[] | select(.name == "Build VLC (raspberrypi - stable)") | "\(.status)|\(.conclusion)"')

        local current_step=$(echo $jobs_data | jq -r '.jobs[] | select(.name != "setup-matrix") | .steps[] | select(.status != "completed") | .name' | head -n 1)
        [[ -z "$current_step" || "$current_step" == "null" ]] && current_step="Initializing..."
        
        echo "VLC-Live-555|🔄|$current_step|$p_linux_dev|$p_linux_stable|$p_arm_dev|$p_arm_stable|$p_win_dev|$p_win_stable|$p_mac_dev|$p_mac_stable|$p_pi_dev|$p_pi_stable|$title"
    else
        [[ "$r_conc" == "success" ]] && local i="✅" || local i="❌"
        echo "VLC-Live-555|$i|$title|completed|$r_conc|completed|$r_conc|completed|$r_conc|completed|$r_conc|completed|$r_conc|completed|$r_conc|completed|$r_conc|completed|$r_conc|completed|$r_conc|completed|$r_conc|$title"
    fi
}

format_job() {
    local s=$(echo $1 | cut -d'|' -f1)
    local c=$(echo $1 | cut -d'|' -f2)
    if [[ "$s" == "completed" ]]; then
        [[ "$c" == "success" ]] && echo "${GREEN}●${NC}" || echo "${RED}●${NC}"
    elif [[ "$s" == "in_progress" ]]; then
        echo "${BLUE}▶${NC}"
    elif [[ "$s" == "queued" ]]; then
        echo "${YELLOW}○${NC}"
    else
        echo "·"
    fi
}

while true; do
    clear
    echo "${BOLD}${CYAN}=== VLC-Live-555 Universal Build Fleet Monitor ===${NC}${REG}"
    echo "Time: $(date '+%Y-%m-%d %H:%M:%S') | Refresh: ${refresh_interval}s\n"
    
    printf "%-15s | %-4s | %-12s | %-12s | %-12s | %-12s | %-12s | %-25s\n" "REPO" "STAT" "LINUX" "ARM" "WIN64" "MACOS" "RPI" "ACTIVITY"
    echo "----------------|------|--------------|--------------|--------------|--------------|--------------|---------------------------"
    
    local raw_data=$(fetch_status)
    local repo=$(echo $raw_data | cut -d'|' -f1)
    local stat=$(echo $raw_data | cut -d'|' -f2)
    local act=$(echo $raw_data | cut -d'|' -f3 | cut -c 1-25)
    
    local ld=$(format_job "$(echo $raw_data | cut -d'|' -f4-5)")
    local ls=$(format_job "$(echo $raw_data | cut -d'|' -f6-7)")
    local ad=$(format_job "$(echo $raw_data | cut -d'|' -f8-9)")
    local as=$(format_job "$(echo $raw_data | cut -d'|' -f10-11)")
    local wd=$(format_job "$(echo $raw_data | cut -d'|' -f12-13)")
    local ws=$(format_job "$(echo $raw_data | cut -d'|' -f14-15)")
    local md=$(format_job "$(echo $raw_data | cut -d'|' -f16-17)")
    local ms=$(format_job "$(echo $raw_data | cut -d'|' -f18-19)")
    local pd=$(format_job "$(echo $raw_data | cut -d'|' -f20-21)")
    local ps=$(format_job "$(echo $raw_data | cut -d'|' -f22-23)")
    local title=$(echo $raw_data | cut -d'|' -f24)

    if [[ "$stat" == "✅" || "$stat" == "❌" ]]; then
        act=$title
    fi

    # Format tracks: D=Dev, S=Stable
    local lin_str="D:$ld S:$ls"
    local arm_str="D:$ad S:$as"
    local win_str="D:$wd S:$ws"
    local mac_str="D:$md S:$ms"
    local rpi_str="D:$pd S:$ps"

    printf "%-15s | %-4s | %b | %b | %b | %b | %b | %s\n" "$repo" "$stat" "$lin_str" "$arm_str" "$win_str" "$mac_str" "$rpi_str" "$act"

    echo "\n${BOLD}Legend:${NC} ${GREEN}●${NC}=Success  ${RED}●${NC}=Failed  ${BLUE}▶${NC}=Building  ${YELLOW}○${NC}=Queued  ·=No Job"
    sleep $refresh_interval
done
