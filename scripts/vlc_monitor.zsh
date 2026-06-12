#!/bin/zsh

# VLC-Live-555 Build Fleet Monitor (Ultra-Robust Zsh Version)
# Requirements: gh, jq

# Colors (Prompt expansions used with print -P)
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
    local conclusion=$(echo $run_data | jq -r '.[0].conclusion')
    local title=$(echo $run_data | jq -r '.[0].displayTitle' | cut -c 1-30)

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

    format_job() {
        local info=$1
        [[ -z "$info" || "$info" == "|" ]] && echo "·" && return
        local s=$(echo $info | cut -d'|' -f1)
        local c=$(echo $info | cut -d'|' -f2)
        if [[ "$s" == "completed" ]]; then
            [[ "$c" == "success" ]] && echo "${GREEN}●${NC}" || echo "${RED}●${NC}"
        elif [[ "$s" == "in_progress" ]]; then
            echo "${BLUE}◑${NC}"
        else
            echo "${YELLOW}◌${NC}"
        fi
    }

    local m_ld=$(format_job "$p_linux_dev")
    local m_ls=$(format_job "$p_linux_stable")
    local m_ad=$(format_job "$p_arm_dev")
    local m_as=$(format_job "$p_arm_stable")
    local m_wd=$(format_job "$p_win_dev")
    local m_ws=$(format_job "$p_win_stable")
    local m_md=$(format_job "$p_mac_dev")
    local m_ms=$(format_job "$p_mac_stable")
    local m_pd=$(format_job "$p_pi_dev")
    local m_ps=$(format_job "$p_pi_stable")

    # Step Logic
    local current_step=$(echo $jobs_data | jq -r '.jobs[] | select(.name != "setup-matrix") | .steps[] | select(.status != "completed") | .name' | head -n 1)
    [[ "$current_step" == "null" || -z "$current_step" ]] && current_step=$(echo $jobs_data | jq -r '.jobs[] | select(.name != "setup-matrix") | .steps[-1].name' | head -n 1)
    [[ "$current_step" == "null" ]] && current_step="Ready"

    # Stat Icon
    local icon="🔄"
    [[ "$r_status" == "completed" && "$conclusion" == "success" ]] && icon="✅"
    [[ "$r_status" == "completed" && "$conclusion" == "failure" ]] && icon="❌"
    [[ "$r_status" == "queued" ]] && icon="⏳"

    echo "VLC|$icon|$m_ld $m_ls|$m_ad $m_as|$m_wd $m_ws|$m_md $m_ms|$m_pd $m_ps|$current_step|$title"
}

while true; do
    clear
    print -P "${BOLD}======================================================================================================${NC}"
    print -P "🚢 ${BOLD}VLC-LIVE-555 BUILD FLEET MONITOR${NC} - $(date +'%H:%M:%S') | Matrix: D=Dev, S=Stable"
    print -P "${BOLD}======================================================================================================${NC}"
    
    local H_REPO="REPO  "
    local H_LIN="LINUX  "
    local H_ARM="ARM    "
    local H_WIN="WIN64  "
    local H_MAC="MACOS  "
    local H_RPI="RPI    "
    local H_STEP="Active Step         "
    
    print -P "${BOLD}${H_REPO} | Stat | ${H_LIN} | ${H_ARM} | ${H_WIN} | ${H_MAC} | ${H_RPI} | ${H_STEP} | Description${NC}"
    print -P "------------------------------------------------------------------------------------------------------"

    # Fetch status
    raw_data=$(fetch_status)
    IFS='|' read -r repo icon m_l m_a m_w m_m m_p step title <<< "$raw_data"

    print -P "${(r:6:)repo} |  $icon  | $m_l | $m_a | $m_w | $m_m | $m_p | ${(r:20:)step:0:20} | $title"

    print -P "${BOLD}------------------------------------------------------------------------------------------------------${NC}"

    print -P "Status Key: ${GREEN}● Success${NC} | ${RED}● Failure${NC} | ${BLUE}◑ In-Progress${NC} | ${YELLOW}◌ Queued${NC} | · N/A"
    echo "Auto-refresh in ${refresh_interval}s. Press [ENTER] to refresh now."
    
    read -t $refresh_interval
done
