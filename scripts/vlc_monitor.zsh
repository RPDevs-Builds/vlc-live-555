#!/bin/zsh

# VLC-Live-555 Build Fleet Monitor (Pivot Layout)
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

format_job() {
    local info=$1
    [[ -z "$info" || "$info" == "|" || "$info" == "·|·" ]] && echo "·" && return
    local s=$(echo $info | cut -d'|' -f1)
    local c=$(echo $info | cut -d'|' -f2)
    if [[ "$s" == "completed" ]]; then
        [[ "$c" == "success" ]] && echo "${GREEN}●${NC}" || echo "${RED}●${NC}"
    elif [[ "$s" == "in_progress" ]]; then
        echo "${BLUE}◑${NC}"
    elif [[ "$s" == "queued" ]]; then
        echo "${YELLOW}◌${NC}"
    else
        echo "·"
    fi
}

get_job_status() {
    local jobs_json="$1"
    local job_name="$2"
    if [[ -z "$jobs_json" || "$jobs_json" == "null" ]]; then
        echo "·|·"
        return
    fi
    local job_info=$(echo "$jobs_json" | jq -r --arg n "$job_name" '.jobs[] | select(.name == $n) | "\(.status)|\(.conclusion)"' 2>/dev/null)
    [[ -z "$job_info" ]] && echo "·|·" || echo "$job_info"
}

get_active_step() {
    local jobs_json="$1"
    if [[ -z "$jobs_json" || "$jobs_json" == "null" ]]; then
        echo "N/A"
        return
    fi
    local step=$(echo "$jobs_json" | jq -r '.jobs[] | select(.name != "setup-matrix" and .name != "Sync Upstream & Tag Lifecycle") | .steps[] | select(.status != "completed") | .name' 2>/dev/null | head -n 1)
    [[ -z "$step" || "$step" == "null" ]] && step=$(echo "$jobs_json" | jq -r '.jobs[] | select(.name != "setup-matrix" and .name != "Sync Upstream & Tag Lifecycle") | .steps[-1].name' 2>/dev/null | head -n 1)
    [[ -z "$step" || "$step" == "null" ]] && step="Ready"
    echo "$step"
}

fetch_and_display() {
    # Fetch VLC Data
    local vlc_run=$(gh run list --repo RPDevs-Builds/vlc-live-555 --workflow=vlc-matrix-builder.yml --limit 1 --json databaseId 2>/dev/null)
    local vlc_id=$(echo $vlc_run | jq -r '.[0].databaseId' 2>/dev/null)
    local vlc_jobs=""
    local vlc_step="N/A"
    if [[ "$vlc_id" != "null" && -n "$vlc_id" ]]; then
        vlc_jobs=$(gh run view --repo RPDevs-Builds/vlc-live-555 $vlc_id --json jobs 2>/dev/null)
        vlc_step=$(get_active_step "$vlc_jobs")
    fi

    # Fetch Live555 Data
    local l555_run=$(gh run list --repo RPDevs-Builds/vlc-live-555 --workflow=universal-matrix-builder.yml --limit 1 --json databaseId 2>/dev/null)
    local l555_id=$(echo $l555_run | jq -r '.[0].databaseId' 2>/dev/null)
    local l555_jobs=""
    local l555_step="N/A"
    if [[ "$l555_id" != "null" && -n "$l555_id" ]]; then
        l555_jobs=$(gh run view --repo RPDevs-Builds/vlc-live-555 $l555_id --json jobs 2>/dev/null)
        l555_step=$(get_active_step "$l555_jobs")
    fi

    # OS Arrays: "Name|Live555 Job Name|VLC Dev Job Name|VLC Stable Job Name"
    local os_list=(
        "Linux x64|Compile (linux-64bit)|Build VLC (linux-x64 - dev)|Build VLC (linux-x64 - stable)"
        "ARM Linux|Compile (armlinux)|Build VLC (armlinux - dev)|Build VLC (armlinux - stable)"
        "Raspberry Pi|Compile (raspberrypi)|Build VLC (raspberrypi - dev)|Build VLC (raspberrypi - stable)"
        "Windows x64|Compile (mingw)|Build VLC (win64 - dev)|Build VLC (win64 - stable)"
        "macOS x64|Compile (macosx-bigsur)|Build VLC (macos-x64 - dev)|Build VLC (macos-x64 - stable)"
    )

    for entry in "${os_list[@]}"; do
        IFS='|' read -r os l_name vd_name vs_name <<< "$entry"
        
        local l_stat=$(get_job_status "$l555_jobs" "$l_name")
        local vd_stat=$(get_job_status "$vlc_jobs" "$vd_name")
        local vs_stat=$(get_job_status "$vlc_jobs" "$vs_name")

        local f_l=$(format_job "$l_stat")
        local f_vd=$(format_job "$vd_stat")
        local f_vs=$(format_job "$vs_stat")

        print -P "${(r:14:)os} |    $f_l    |      $f_vs     |    $f_vd   "
    done
    
    echo ""
    print -P "${BOLD}Active Steps:${NC}"
    print -P "Live555: ${CYAN}${l555_step:0:45}${NC}"
    print -P "VLC:     ${CYAN}${vlc_step:0:45}${NC}"
}

while true; do
    clear
    print -P "${BOLD}======================================================${NC}"
    print -P "🚢 ${BOLD}VLC & LIVE555 MATRIX MONITOR${NC} - $(date +'%H:%M:%S')"
    print -P "${BOLD}======================================================${NC}"
    
    local H_OS="OS TARGET     "
    local H_L5="Live555"
    local H_VS="VLC (Stable)"
    local H_VD="VLC (Dev)"
    
    print -P "${BOLD}${H_OS} | ${H_L5} | ${H_VS} | ${H_VD}${NC}"
    print -P "------------------------------------------------------"
    
    fetch_and_display

    print -P "${BOLD}------------------------------------------------------${NC}"
    print -P "Key: ${GREEN}● Success${NC} | ${RED}● Failed${NC} | ${BLUE}◑ Active${NC} | ${YELLOW}◌ Queued${NC} | · N/A"
    echo -n "Refreshing in ${refresh_interval}s. Press [ENTER] to refresh now."
    
    read -t $refresh_interval
done
