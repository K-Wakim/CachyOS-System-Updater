#!/usr/bin/env bash

# Arch System Update Script (Bash conversion)
# By: Kamal Wakim
# last Updated: 04/11/2026 01:41:56

# Settings are stored in a config file so they persist across shells.
# Change them with: update_system --config

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/fish/functions/update_system.conf"
mkdir -p "$(dirname "$CONFIG_FILE")"

################## SETTINGS HELPERS ###################

# All setting names, in the order shown in the config menu
_us_keys() {
    printf '%s\n' \
        auto_remove_orphans auto_clean_cache \
        disable_remove_orphans disable_clean_cache disable_flatpak_updates disable_vencord_reinstall disable_snap_updates disable_AUR_updates \
        disable_logs aur_helper
}

# Default value for each setting
_us_default() {
    case "$1" in
        auto_remove_orphans|auto_clean_cache|disable_logs)
            echo true
            ;;
        aur_helper)
            echo auto
            ;;
        *)
            echo false
            ;;
    esac
}

# Short description shown in the config menu
_us_describe() {
    case "$1" in
        auto_remove_orphans)
            echo "Remove orphan packages without asking"
            ;;
        auto_clean_cache)
            echo "Clean package cache without asking"
            ;;
        disable_remove_orphans)
            echo "Skip orphan removal entirely"
            ;;
        disable_clean_cache)
            echo "Skip cache cleaning entirely"
            ;;
        disable_flatpak_updates)
            echo "Skip flatpak updates"
            ;;
        disable_vencord_reinstall)
            echo "Don't reinstall Vencord after a Discord update"
            ;;
        disable_snap_updates)
            echo "Skip snap updates"
            ;;
        disable_AUR_updates)
            echo "Skip AUR updates (official repos only)"
            ;;
        disable_logs)
            echo "Don't write a log file"
            ;;
        aur_helper)
            echo "AUR helper: auto / paru / yay"
            ;;
    esac
}

# Current value of a setting (stored value, or the default if never set)
_us_get() {
    local key="$1"
    local var="update_system_${key}"

    if [[ -n "${!var+x}" ]]; then
        printf '%s\n' "${!var}"
        return 0
    fi

    if [[ -f "$CONFIG_FILE" ]]; then
        local value
        value=$(awk -F= -v key="update_system_${key}" '$1 == key { print $2; exit }' "$CONFIG_FILE" 2>/dev/null)
        if [[ -n "$value" ]]; then
            printf '%s\n' "$value"
            return 0
        fi
    fi

    _us_default "$key"
}

# Is $1 a valid value for setting $2?
_us_valid() {
    if [[ "$1" == "aur_helper" ]]; then
        [[ "$2" == "auto" || "$2" == "paru" || "$2" == "yay" ]]
    else
        [[ "$2" == "true" || "$2" == "false" ]]
    fi
}

# Resolve the preferred AUR helper to one that is actually installed
# Prints paru, yay, or none
_us_aur_helper() {
    local pref="$1"

    if [[ "$pref" == "paru" || "$pref" == "yay" ]] && command -v "$pref" >/dev/null 2>&1; then
        echo "$pref"
        return 0
    fi

    for helper in paru yay; do
        if command -v "$helper" >/dev/null 2>&1; then
            echo "$helper"
            return 0
        fi
    done

    echo none
}

# List the AUR helpers that are actually installed (paru, yay)
_us_installed_helpers() {
    for helper in paru yay; do
        if command -v "$helper" >/dev/null 2>&1; then
            echo "$helper"
        fi
    done
}

# Store config value persistently
_us_set_value() {
    local key="$1"
    local value="$2"
    local tmp
    tmp=$(mktemp)

    if [[ -f "$CONFIG_FILE" ]]; then
        grep -vE "^update_system_${key}=" "$CONFIG_FILE" > "$tmp" 2>/dev/null || true
    fi

    printf '%s=%s\n' "update_system_${key}" "$value" >> "$tmp"
    mv "$tmp" "$CONFIG_FILE"
    export "update_system_${key}=${value}"
}

# Delete config value persistently
_us_unset_value() {
    local key="$1"
    local tmp
    tmp=$(mktemp)

    if [[ -f "$CONFIG_FILE" ]]; then
        grep -vE "^update_system_${key}=" "$CONFIG_FILE" > "$tmp" 2>/dev/null || true
        mv "$tmp" "$CONFIG_FILE"
    fi

    unset "update_system_${key}"
}

# Print the settings table
_us_show() {
    local keys=()
    mapfile -t keys < <(_us_keys)

    echo "================================"
    echo "update_system settings"
    echo "================================"

    local i key value desc found
    for i in "${!keys[@]}"; do
        key="${keys[$i]}"
        value="$(_us_get "$key")"
        desc="$(_us_describe "$key")"

        if [[ "$key" == "aur_helper" ]] && [[ $( _us_installed_helpers | wc -l ) -lt 2 ]]; then
            found="$(_us_installed_helpers)"
            if [[ -n "$found" ]]; then
                value="$found"
                desc="Locked: only $found is installed"
            else
                value="none"
                desc="Locked: no AUR helper installed"
            fi
        fi

        printf '  %d) %-24s %-6s %s\n' $((i + 1)) "$key" "$value" "$desc"
    done

    echo ""
}

################## CONFIG FUNCTION ###################

# Print usage information for the config function
_us_usage() {
    echo "Usage:"
    echo "  config_update                  interactive menu (or: update_system --config)"
    echo "  config_update show             print current settings"
    echo "  config_update set KEY VALUE    set one setting"
    echo "  config_update reset            restore all defaults"
    echo "  config_update dellog           delete logs"
    echo "  config_update help             show this help"
    echo ""
    echo "Settings:"
    while IFS= read -r key; do
        printf '  %-24s %s\n' "$key" "$(_us_describe "$key")"
    done < <(_us_keys)
    echo ""
    echo "Values:"
    echo "  All settings except aur_helper:  true | false"
    echo "  aur_helper:                      auto | paru | yay"
    echo "                                   (locked unless both paru and yay are installed)"
    echo ""
    echo "Note: for the disable_* settings, 'true' means the feature is turned off."
}

# Usage:
#   update_system --config                 interactive menu
#   update_system --config show            print current settings
#   update_system --config set KEY VALUE   set one setting
#   update_system --config reset           restore all defaults
#   update_system --config help            show usage
_update_system_config() {
    local keys=()
    mapfile -t keys < <(_us_keys)

    case "$1" in
        help|-h|--help)
            _us_usage
            return 0
            ;;
        show)
            _us_show
            return 0
            ;;
        dellog)
            local log_dir="$HOME/.config/update_system.log"
            if [[ -d "$log_dir" ]]; then
                find "$log_dir" -type f -name '*.log' -print
                echo ""
                read -p "Delete log file? (y/N): " choice
                if [[ -z "$choice" || "$choice" =~ ^[Yy]$ ]]; then
                    rm -rf "$log_dir"
                    echo "Logs deleted"
                else
                    echo "Cancelled deleting logs"
                fi
            fi
            return 0
            ;;
        set)
            if [[ $# -lt 3 ]]; then
                echo "Usage: config_update set KEY VALUE"
                return 1
            fi
            local key="$2"
            local value="$3"
            if ! printf '%s\n' "${keys[@]}" | grep -Fxq "$key"; then
                echo "Unknown setting: '$key'. Valid settings: ${keys[*]}"
                return 1
            fi
            if [[ "$key" == "aur_helper" ]] && [[ $( _us_installed_helpers | wc -l ) -lt 2 ]]; then
                echo "aur_helper is locked: fewer than 2 AUR helpers are installed."
                return 1
            fi
            if ! _us_valid "$key" "$value"; then
                echo "Invalid value '$value' for $key."
                return 1
            fi
            _us_set_value "$key" "$value"
            echo "$key = $value"
            return 0
            ;;
        reset)
            for key in "${keys[@]}"; do
                _us_unset_value "$key"
            done
            echo "All settings reset to defaults."
            return 0
            ;;
        "")
            while true; do
                _us_show
                read -p "Number to change (Enter to finish, 'h' for help): " choice
                if [[ -z "$choice" ]]; then
                    break
                fi
                if [[ "$choice" == "h" ]]; then
                    echo ""
                    _us_usage
                    echo ""
                    continue
                fi

                if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 )) && (( choice <= ${#keys[@]} )); then
                    local key="${keys[$((choice - 1))]}"

                    if [[ "$key" == "aur_helper" ]] && [[ $( _us_installed_helpers | wc -l ) -lt 2 ]]; then
                        echo "Nothing to choose: fewer than 2 AUR helpers are installed."
                        echo ""
                        continue
                    fi

                    local current value new
                    current="$(_us_get "$key")"
                    new=""

                    if [[ "$key" == "aur_helper" ]]; then
                        case "$current" in
                            auto)
                                new="paru"
                                ;;
                            paru)
                                new="yay"
                                ;;
                            *)
                                new="auto"
                                ;;
                        esac
                    else
                        if [[ "$current" == "true" ]]; then
                            new="false"
                        else
                            new="true"
                        fi
                    fi

                    _us_set_value "$key" "$new"
                else
                    echo "Invalid choice."
                    echo ""
                fi
            done
            echo "Settings saved."
            ;;
        *)
            echo "Unknown option: '$1'"
            echo ""
            _us_usage
            return 1
            ;;
    esac
}

config_update() {
    _update_system_config "$@"
}

################## WRAPPER ###################

# Print usage information for update_system itself
_us_update_usage() {
    echo "update_system - Arch system update script"
    echo ""
    echo "Usage:"
    echo "  update_system                    run the update"
    echo "  update_system --config [...]     change settings (see: config_update help)"
    echo "  update_system -h, -help, --help  show this help"
    echo ""
    echo "What it does, in order:"
    echo "  1. Updates system packages (and AUR packages if paru or yay is installed)"
    echo "  2. Updates flatpaks (and reinstalls Vencord if Discord was updated)"
    echo "  3. Updates snaps"
    echo "  4. Removes orphaned packages"
    echo "  5. Cleans the package cache"
    echo "  6. Asks whether to shut down, reboot, or stay running"
    echo "  (Flatpak and snap steps are skipped automatically if they aren't installed.)"
    echo ""
    echo "Each step can be automated or disabled with: config_update"
    echo "To see the current settings: config_update show"
}

# Wrapper function to make things easier to log/manage
update_system() {
    local arg="${1:-}"

    case "$arg" in
        --config)
            shift
            _update_system_config "$@"
            return $?
            ;;
        help|-h|--help)
            _us_update_usage
            return 0
            ;;
        "")
            ;;
        *)
            echo "Unknown option: '$arg'"
            echo ""
            _us_update_usage
            return 1
            ;;
    esac

    # The variables are exactly what they are named, meaning it will do as it is named if set to true
    # Change them with:  update_system --config

    ################## AUTOMATION VARIABLES ###################

    # Automatically removing orphan packages every time
    local auto_remove_orphans
    auto_remove_orphans="$(_us_get auto_remove_orphans)"

    # Automatically clearing cache every time
    local auto_clean_cache
    auto_clean_cache="$(_us_get auto_clean_cache)"

    ################### DISABLING VARIABLES ###################

    # Disable orphan removal
    local disable_remove_orphans
    disable_remove_orphans="$(_us_get disable_remove_orphans)"

    # Disable cache cleaning
    local disable_clean_cache
    disable_clean_cache="$(_us_get disable_clean_cache)"

    # Disable flatpak updates
    local disable_flatpak_updates
    disable_flatpak_updates="$(_us_get disable_flatpak_updates)"

    # Disable reinstalling Vencord after Discord is updated
    local disable_vencord_reinstall
    disable_vencord_reinstall="$(_us_get disable_vencord_reinstall)"

    # Disable snap updates
    local disable_snap_updates
    disable_snap_updates="$(_us_get disable_snap_updates)"

    # Disable AUR package updates
    local disable_AUR_updates
    disable_AUR_updates="$(_us_get disable_AUR_updates)"

    # Disable logging
    local disable_logs
    disable_logs="$(_us_get disable_logs)"

    ###################### AUR HELPER #########################

    # paru or yay: your preference if installed, otherwise whichever one is found
    local aur_helper
    aur_helper="$(_us_aur_helper "$(_us_get aur_helper)")"

    ###########################################################

    if [[ "$disable_logs" == false ]]; then
        local log_dir="$HOME/.config/update_system.log"
        mkdir -p "$log_dir"
        local log_file="$log_dir/$(date +%Y-%m-%d_%H-%M-%S).log"

        _update_system "$auto_remove_orphans" "$auto_clean_cache" "$disable_remove_orphans" "$disable_clean_cache" "$disable_flatpak_updates" "$disable_AUR_updates" "$aur_helper" "$disable_vencord_reinstall" "$disable_snap_updates" 2>&1 | tee -a "$log_file"
    else
        _update_system "$auto_remove_orphans" "$auto_clean_cache" "$disable_remove_orphans" "$disable_clean_cache" "$disable_flatpak_updates" "$disable_AUR_updates" "$aur_helper" "$disable_vencord_reinstall" "$disable_snap_updates"
    fi
}

################## MAIN FUNCTION ###################

# The main function doing all the work
_update_system() {
    # Arguments (passed in by update_system):
    #   $1 auto_remove_orphans     $2 auto_clean_cache
    #   $3 disable_remove_orphans  $4 disable_clean_cache
    #   $5 disable_flatpak_updates $6 disable_AUR_updates
    #   $7 aur_helper (paru, yay, or none)
    #   $8 disable_vencord_reinstall
    #   $9 disable_snap_updates

    echo "================================"
    echo "Updating System + AUR Packages..."
    echo "================================"
    if [[ "$6" == "false" ]] && [[ "$7" != "none" ]]; then
        echo "Using AUR helper: $7"
        "$7" -Syu --noconfirm
    else
        if [[ "$6" == "false" ]]; then
            echo "No AUR helper (paru/yay) found - updating official repos only."
        fi
        sudo pacman -Syu --noconfirm
    fi
    if [[ $? -ne 0 ]]; then
        echo "Error: System package update failed!"
        return 1
    fi
    echo ""

    if [[ "$5" == "false" ]] && ! command -v flatpak >/dev/null 2>&1; then
        echo "Flatpak is not installed - skipping flatpak updates."
        echo ""
    elif [[ "$5" == "false" ]]; then
        echo "================================"
        echo "Updating Flatpak Packages..."
        echo "================================"
        local flatpak_log
        flatpak_log=$(mktemp)
        set +o pipefail
        sudo flatpak update -y 2>&1 | tee "$flatpak_log"
        local flatpak_status=${PIPESTATUS[0]}
        set -o pipefail
        local flatpak_output
        flatpak_output=$(cat "$flatpak_log")
        rm -f "$flatpak_log"

        if [[ $flatpak_status -ne 0 ]]; then
            echo "Warning: Flatpak update had issues, but continuing..."
        fi
        echo ""
        # If Discord was among the updated flatpaks, reinstall Vencord
        if [[ "$flatpak_output" == *"discord"* ]] && [[ "$8" == "false" ]]; then
            echo "Discord was updated — reinstalling Vencord"
            sh -c "$(curl -sS https://vencord.dev/install.sh)"
        fi
        echo ""
    fi

    # Handle snap updates
    if [[ "$9" == "false" ]] && ! command -v snap >/dev/null 2>&1; then
        echo "Snap is not installed - skipping snap updates."
        echo ""
    elif [[ "$9" == "false" ]]; then
        echo "================================"
        echo "Updating Snap Packages..."
        echo "================================"
        sudo snap refresh
        if [[ $? -ne 0 ]]; then
            echo "Warning: Snap update had issues, but continuing..."
        fi
        echo ""
    fi

    # Handle orphaned packages
    if [[ "$3" == "false" ]]; then
        echo "================================"
        echo "Orphaned Packages"
        echo "================================"

        local orphans=()
        mapfile -t orphans < <(pacman -Qdtq)

        if [[ ${#orphans[@]} -eq 0 ]]; then
            echo "No orphaned packages found."
        else
            echo "Found ${#orphans[@]} orphaned packages:"
            printf '  %s\n' "${orphans[@]}"

            local orphan_choice=""
            if [[ "$1" == "false" ]]; then
                read -p "Remove them? (y/N): " -n 1 orphan_choice
                echo ""
            fi

            if [[ "$orphan_choice" =~ ^[Yy]$ ]] || [[ "$1" == "true" ]]; then
                sudo pacman -Rns --noconfirm "${orphans[@]}"
            else
                echo "Skipping orphan removal."
            fi
        fi
        echo ""
    fi

    # Handle cache cleaning
    if [[ "$4" == "false" ]]; then
        echo "================================"
        echo "Cleaning Package Cache"
        echo "================================"

        local clean_choice=""
        if [[ "$2" == "false" ]]; then
            read -p "Do you want to clean the package cache? (y/N): " -n 1 clean_choice
            echo ""
        fi

        if [[ "$clean_choice" =~ ^[Yy]$ ]] || [[ "$2" == "true" ]]; then
            echo "Cleaning pacman cache..."
            sudo pacman -Scc --noconfirm
            if [[ $? -ne 0 ]]; then
                echo "Warning: pacman -Scc failed — falling back to manual cache removal..."
                sudo rm -rf /var/cache/pacman/pkg/*
            fi
            echo ""
            echo "Removing uninstalled package cache..."
            sudo paccache -ruk0
            echo "Cache cleaned!"
            echo ""
        else
            echo "Skipping cache cleanup."
            echo ""
        fi
    fi

    # Post-update action
    echo "================================"
    echo "Post-Update Action"
    echo "================================"
    echo "What would you like to do now?"
    echo "  1) Shutdown"
    echo "  2) Reboot"
    echo "  3) Nothing (stay running)"
    local action_choice
    read -p "Enter your choice (1/2/3): " -n 1 action_choice
    echo ""

    case "$action_choice" in
        1)
            echo "Shutting down system..."
            sudo shutdown now
            ;;
        2)
            echo "Rebooting system..."
            sudo reboot
            ;;
        *)
            echo "Update complete! System will stay running."
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    update_system "$@"
fi
