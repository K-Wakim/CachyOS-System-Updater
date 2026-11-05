#!/usr/bin/env fish

# Arch System Update Script
# By: Kamal Wakim
# last Updated: 04/11/2026 01:41:56

# Settings are stored as fish universal variables (update_system_<name>), so they
# persist across terminals and reboots. Change them with:  update_system --config
# Anything you haven't set falls back to the defaults in _us_default below.

################## SETTINGS HELPERS ###################

# All setting names, in the order shown in the config menu
function _us_keys
    printf '%s\n' \
        auto_remove_orphans auto_clean_cache \
        disable_remove_orphans disable_clean_cache disable_flatpak_updates disable_vencord_reinstall disable_snap_updates disable_AUR_updates \
        disable_logs aur_helper
end

# Default value for each setting
function _us_default
    switch $argv[1]
        case auto_remove_orphans auto_clean_cache disable_logs
            echo true
        case aur_helper
            echo auto # auto = use paru if installed, otherwise yay. Or set to paru / yay
        case '*'
            echo false
    end
end

# Short description shown in the config menu
function _us_describe
    switch $argv[1]
        case auto_remove_orphans
            echo "Remove orphan packages without asking"
        case auto_clean_cache
            echo "Clean package cache without asking"
        case disable_remove_orphans
            echo "Skip orphan removal entirely"
        case disable_clean_cache
            echo "Skip cache cleaning entirely"
        case disable_flatpak_updates
            echo "Skip flatpak updates"
        case disable_vencord_reinstall
            echo "Don't reinstall Vencord after a Discord update"
        case disable_snap_updates
            echo "Skip snap updates"
        case disable_AUR_updates
            echo "Skip AUR updates (official repos only)"
        case disable_logs
            echo "Don't write a log file"
        case aur_helper
            echo "AUR helper: auto / paru / yay"
    end
end

# Current value of a setting (stored value, or the default if never set)
function _us_get
    set -l var update_system_$argv[1]
    if set -q $var
        echo $$var
    else
        _us_default $argv[1]
    end
end

# Is $argv[2] a valid value for setting $argv[1]?
function _us_valid
    if test "$argv[1]" = aur_helper
        contains -- $argv[2] auto paru yay
    else
        contains -- $argv[2] true false
    end
end

# Resolve the preferred AUR helper to one that is actually installed
# Prints paru, yay, or none
function _us_aur_helper
    set -l pref $argv[1]
    if contains -- $pref paru yay; and command -q $pref
        echo $pref
        return
    end
    for helper in paru yay
        if command -q $helper
            echo $helper
            return
        end
    end
    echo none
end

# List the AUR helpers that are actually installed (paru, yay)
function _us_installed_helpers
    for helper in paru yay
        if command -q $helper
            echo $helper
        end
    end
end

# Print the settings table
function _us_show
    set -l keys (_us_keys)
    echo "================================"
    echo "update_system settings"
    echo "================================"
    for i in (seq (count $keys))
        set -l key $keys[$i]
        set -l value (_us_get $key)
        set -l desc (_us_describe $key)

        # Nothing to choose between if fewer than 2 helpers are installed
        if test "$key" = aur_helper; and test (count (_us_installed_helpers)) -lt 2
            set -l found (_us_installed_helpers)
            if test -n "$found"
                set value $found
                set desc "Locked: only $found is installed"
            else
                set value none
                set desc "Locked: no AUR helper installed"
            end
        end

        printf '  %d) %-24s %-6s %s\n' $i $key $value $desc
    end
    echo ""
end

################## CONFIG FUNCTION ###################

# Print usage information for the config function
function _us_usage
    echo "Usage:"
    echo "  config_update                  interactive menu (or: update_system --config)"
    echo "  config_update show             print current settings"
    echo "  config_update set KEY VALUE    set one setting"
    echo "  config_update reset            restore all defaults"
    echo "  config_update dellog           delete logs"
    echo "  config_update help             show this help"
    echo ""
    echo "Settings:"
    for key in (_us_keys)
        printf '  %-24s %s\n' $key (_us_describe $key)
    end
    echo ""
    echo "Values:"
    echo "  All settings except aur_helper:  true | false"
    echo "  aur_helper:                      auto | paru | yay"
    echo "                                   (locked unless both paru and yay are installed)"
    echo ""
    echo "Note: for the disable_* settings, 'true' means the feature is turned off."
end

# Usage:
#   update_system --config                 interactive menu
#   update_system --config show            print current settings
#   update_system --config set KEY VALUE   set one setting
#   update_system --config reset           restore all defaults
#   update_system --config help            show usage
function _update_system_config
    set -l keys (_us_keys)

    switch "$argv[1]"
        case help -h --help
            _us_usage
            return 0

        case show
            _us_show
            return 0

        case dellog
            set -l log_dir ~/.config/update_system.log
            if test -d "$log_dir"
                find "$log_dir" -type f -name '*.log' -print
                echo ""
                read -P "Delete log file? (y/N): " choice
                if test -z "$choice"; or string match -qi "y" "$choice"
                    rm -rf "$log_dir"
                    echo "Logs deleted"
                else
                    echo "Cancelled deleting logs"
                end
            end
            return 0

        case set
            set -l key $argv[2]
            set -l value $argv[3]
            if not contains -- $key $keys
                echo "Unknown setting: '$key'. Valid settings: $keys"
                return 1
            end
            if test "$key" = aur_helper; and test (count (_us_installed_helpers)) -lt 2
                echo "aur_helper is locked: fewer than 2 AUR helpers are installed."
                return 1
            end
            if not _us_valid $key $value
                echo "Invalid value '$value' for $key."
                return 1
            end
            set -U update_system_$key $value
            echo "$key = $value"
            return 0

        case reset
            for key in $keys
                set -eU update_system_$key
            end
            echo "All settings reset to defaults."
            return 0

        case ''
            # Interactive menu: pick a number to toggle (aur_helper cycles through its options)
            while true
                _us_show
                read -P "Number to change (Enter to finish, 'h' for help): " choice
                if test -z "$choice"
                    break
                end
                if test "$choice" = h
                    echo ""
                    _us_usage
                    echo ""
                    continue
                end

                if string match -qr '^[0-9]+$' -- $choice; and test $choice -ge 1; and test $choice -le (count $keys)
                    set -l key $keys[$choice]

                    if test "$key" = aur_helper; and test (count (_us_installed_helpers)) -lt 2
                        echo "Nothing to choose: fewer than 2 AUR helpers are installed."
                        echo ""
                        continue
                    end

                    set -l current (_us_get $key)
                    set -l new

                    if test "$key" = aur_helper
                        switch $current
                            case auto
                                set new paru
                            case paru
                                set new yay
                            case '*'
                                set new auto
                        end
                    else
                        if test "$current" = true
                            set new false
                        else
                            set new true
                        end
                    end

                    set -U update_system_$key $new
                else
                    echo "Invalid choice."
                    echo ""
                end
            end
            echo "Settings saved."

        case '*'
            echo "Unknown option: '$argv[1]'"
            echo ""
            _us_usage
            return 1
    end
end

################## WRAPPER ###################

# Print usage information for update_system itself
function _us_update_usage
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
end

# Wrapper function to make things easier to log/manage
function update_system

    switch "$argv[1]"
        case --config
            _update_system_config $argv[2..-1]
            return $status
        case help -h -help --help
            _us_update_usage
            return 0
        case ''
            # No arguments: run the update below
        case '*'
            echo "Unknown option: '$argv[1]'"
            echo ""
            _us_update_usage
            return 1
    end

    # The variables are exactly what they are named, meaning it will do as it is named if set to true
    # Change them with:  update_system --config

    ################## AUTOMATION VARIABLES ###################

    # Automatically removing orphan packages every time
    set -l auto_remove_orphans (_us_get auto_remove_orphans)

    # Automatically clearing cache every time
    set -l auto_clean_cache (_us_get auto_clean_cache)

    ################### DISABLING VARIABLES ###################

    # Disable orphan removal
    set -l disable_remove_orphans (_us_get disable_remove_orphans)

    # Disable cache cleaning
    set -l disable_clean_cache (_us_get disable_clean_cache)

    # Disable flatpak updates
    set -l disable_flatpak_updates (_us_get disable_flatpak_updates)

    # Disable reinstalling Vencord after Discord is updated
    set -l disable_vencord_reinstall (_us_get disable_vencord_reinstall)

    # Disable snap updates
    set -l disable_snap_updates (_us_get disable_snap_updates)

    # Disable AUR package updates
    set -l disable_AUR_updates (_us_get disable_AUR_updates)

    # Disable logging
    set -l disable_logs (_us_get disable_logs)

    ###################### AUR HELPER #########################

    # paru or yay: your preference if installed, otherwise whichever one is found
    set -l aur_helper (_us_aur_helper (_us_get aur_helper))

    ###########################################################

    if test "$disable_logs" = false
        set log_dir ~/.config/update_system.log
        mkdir -p $log_dir
        set log_file $log_dir/(date +%Y-%m-%d_%H-%M-%S).log

        _update_system $auto_remove_orphans $auto_clean_cache $disable_remove_orphans $disable_clean_cache $disable_flatpak_updates $disable_AUR_updates $aur_helper $disable_vencord_reinstall $disable_snap_updates 2>&1 | tee -a $log_file
    else
        _update_system $auto_remove_orphans $auto_clean_cache $disable_remove_orphans $disable_clean_cache $disable_flatpak_updates $disable_AUR_updates $aur_helper $disable_vencord_reinstall $disable_snap_updates
    end
end

################## MAIN FUNCTION ###################

# The main function doing all the work
function _update_system
    # Arguments (passed in by update_system):
    #   $argv[1] auto_remove_orphans     $argv[2] auto_clean_cache
    #   $argv[3] disable_remove_orphans  $argv[4] disable_clean_cache
    #   $argv[5] disable_flatpak_updates $argv[6] disable_AUR_updates
    #   $argv[7] aur_helper (paru, yay, or none)
    #   $argv[8] disable_vencord_reinstall
    #   $argv[9] disable_snap_updates

    echo "================================"
    echo "Updating System + AUR Packages..."
    echo "================================"
    if test "$argv[6]" = "false"; and test "$argv[7]" != none
        echo "Using AUR helper: $argv[7]"
        $argv[7] -Syu --noconfirm # '--noconfirm' param set because if you are running this function you want to update anyways
    else
        if test "$argv[6]" = "false"
            echo "No AUR helper (paru/yay) found - updating official repos only."
        end
        sudo pacman -Syu --noconfirm # same reason as above
    end
    if test $status -ne 0
        echo "Error: System package update failed!"
        return 1
    end
    echo ""

    if test "$argv[5]" = "false"; and not command -q flatpak
        echo "Flatpak is not installed - skipping flatpak updates."
        echo ""
    else if test "$argv[5]" = "false"
        echo "================================"
        echo "Updating Flatpak Packages..."
        echo "================================"
        # Capture flatpak output while still showing it live, via tee to a temp file.
        set flatpak_log (mktemp)
        sudo flatpak update -y | tee $flatpak_log # Same reasoning for the '-y' as the '--noconfirm'
        set flatpak_status $pipestatus[1]
        set flatpak_output (cat $flatpak_log)
        rm -f $flatpak_log

        if test $flatpak_status -ne 0
            echo "Warning: Flatpak update had issues, but continuing..."
        end
        echo ""
        # If Discord was among the updated flatpaks, reinstall Vencord
        if string match -qi "*discord*" -- $flatpak_output; and test "$argv[8]" = "false"
            echo "Discord was updated — reinstalling Vencord"
            sh -c "$(curl -sS https://vencord.dev/install.sh)"
        end
        echo ""
    end

    # Handle snap updates
    if test "$argv[9]" = "false"; and not command -q snap
        echo "Snap is not installed - skipping snap updates."
        echo ""
    else if test "$argv[9]" = "false"
        echo "================================"
        echo "Updating Snap Packages..."
        echo "================================"
        sudo snap refresh
        if test $status -ne 0
            echo "Warning: Snap update had issues, but continuing..."
        end
        echo ""
    end

    # Handle orphaned packages
    if test "$argv[3]" = "false"
        echo "================================"
        echo "Orphaned Packages"
        echo "================================"
        set orphans (pacman -Qdtq)

        if test (count $orphans) -eq 0
            echo "No orphaned packages found."
        else
            echo "Found "(count $orphans)" orphaned packages:"
            printf '  %s\n' $orphans

            if test "$argv[1]" = "false"
                read -P "Remove them? (y/N): " -n 1 orphan_choice
                echo ""
            end

            if string match -qi "y" -- "$orphan_choice"; or test "$argv[1]" = "true"
                sudo pacman -Rns --noconfirm $orphans # Wanna guess why there is a '--noconfirm' here?
            else
                echo "Skipping orphan removal."
            end
        end
        echo ""
    end

    # Handle cache cleaning
    if test "$argv[4]" = "false"
        echo "================================"
        echo "Cleaning Package Cache"
        echo "================================"

        if test "$argv[2]" = "false"
            read -P "Do you want to clean the package cache? (y/N): " -n 1 clean_choice
            echo ""
        end

        if string match -qi "y" -- "$clean_choice"; or test "$argv[2]" = "true"
            echo "Cleaning pacman cache..."
            sudo pacman -Scc --noconfirm # Or here?
            if test $status -ne 0
                echo "Warning: pacman -Scc failed — falling back to manual cache removal..."
                sudo rm -rf /var/cache/pacman/pkg/*
            end
            echo ""
            echo "Removing uninstalled package cache..."
            sudo paccache -ruk0
            echo "Cache cleaned!"
            echo ""
        else
            echo "Skipping cache cleanup."
            echo ""
        end
    end

    # Post-update action
    echo "================================"
    echo "Post-Update Action"
    echo "================================"
    echo "What would you like to do now?"
    echo "  1) Shutdown"
    echo "  2) Reboot"
    echo "  3) Nothing (stay running)"
    read -P "Enter your choice (1/2/3): " -n 1 action_choice
    echo ""

    switch $action_choice
        case 1
            echo "Shutting down system..."
            sudo shutdown now
        case 2
            echo "Rebooting system..."
            sudo reboot
        case '*'
            echo "Update complete! System will stay running."
    end
end
