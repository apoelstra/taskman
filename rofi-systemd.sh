#!/nix/store/xy4jjgw87sbgwylm5kn047d9gkbhsr9x-bash-5.2p37/bin/bash

# Enable strict error handling
set -euo pipefail

# Configuration constants
readonly TERM="${ROFI_SYSTEMD_TERM:-urxvt -e}"
readonly DEFAULT_ACTION="${ROFI_SYSTEMD_DEFAULT_ACTION:-list_actions}"

# Rofi keybindings
readonly KB_ENABLE="Alt+e"
readonly KB_DISABLE="Alt+d"
readonly KB_STOP="Alt+k"
readonly KB_RESTART="Alt+r"
readonly KB_TAIL="Alt+t"
readonly KB_LIST_ACTIONS="Alt+l"

# Available actions
readonly ALL_ACTIONS="enable
disable
stop
restart
tail
list_actions"

# Rofi exit codes mapping
readonly ROFI_EXIT_CANCEL=1
readonly ROFI_EXIT_CUSTOM_1=10
readonly ROFI_EXIT_CUSTOM_2=11
readonly ROFI_EXIT_CUSTOM_3=12
readonly ROFI_EXIT_CUSTOM_4=13
readonly ROFI_EXIT_CUSTOM_5=14
readonly ROFI_EXIT_CUSTOM_6=15

# Call systemd D-Bus interface
call_systemd_dbus() {
	busctl call org.freedesktop.systemd1 /org/freedesktop/systemd1 \
		org.freedesktop.systemd1.Manager "$@" --json=short
}

# Get unit files from systemd
get_unit_files() {
	local scope="$1"
	call_systemd_dbus ListUnitFiles "$scope" | jq -r '.data[][] | (.[0] + " " + .[1])'
}

# Get running units from systemd
get_running_units() {
	local scope="$1"
	call_systemd_dbus ListUnits "$scope" | jq -r '.data[][] | (.[0] + " " + .[3])'
}

# Get all units for a given scope (user/system)
get_units() {
	local unit_type="$1"

	if [[ -z "$unit_type" ]]; then
		echo "Error: unit_type is required" >&2
		return 1
	fi

	# Note: unit files is no longer used here because it does not seem to be necessary
	get_running_units "--$unit_type" | sort -u -k1,1 | \
		awk -v unit_type="$unit_type" '{print $0 " " unit_type}'
}


# Map rofi exit code to action
map_rofi_exit_to_action() {
	local rofi_exit="$1"

	case "$rofi_exit" in
		"$ROFI_EXIT_CANCEL")
			echo "exit"
			;;
		"$ROFI_EXIT_CUSTOM_1")
			echo "enable"
			;;
		"$ROFI_EXIT_CUSTOM_2")
			echo "disable"
			;;
		"$ROFI_EXIT_CUSTOM_3")
			echo "stop"
			;;
		"$ROFI_EXIT_CUSTOM_4")
			echo "restart"
			;;
		"$ROFI_EXIT_CUSTOM_5")
			echo "tail"
			;;
		"$ROFI_EXIT_CUSTOM_6")
			echo "list_actions"
			;;
		*)
			echo "$DEFAULT_ACTION"
			;;
	esac
}

# Parse service selection and determine scope
parse_service_selection() {
	local selection="$1"
	local normalized_selection

	normalized_selection="$(echo "$selection" | sed -n 's/ \+/ /gp')"
	service_name="$(echo "$normalized_selection" | awk '{print $1}' | tr -d ' ')"
	local scope="$(echo "$normalized_selection" | awk '{print $3}')"

	case "$scope" in
		user*)
			user_arg="--user"
			command="systemctl $user_arg"
			;;
		system*)
			user_arg=""
			command="sudo systemctl"
			;;
		*)
			user_arg=""
			command="systemctl"
			;;
	esac
}

# Show rofi menu and handle user selection
select_service_and_act() {
	local result
	local rofi_exit
	local action

	result=$(rofi -dmenu -i -p "systemd unit: " \
		-kb-custom-1 "$KB_ENABLE" \
		-kb-custom-2 "$KB_DISABLE" \
		-kb-custom-3 "$KB_STOP" \
		-kb-custom-4 "$KB_RESTART" \
		-kb-custom-5 "$KB_TAIL" \
		-kb-custom-6 "$KB_LIST_ACTIONS")

	rofi_exit="$?"
	action="$(map_rofi_exit_to_action "$rofi_exit")"

	if [[ "$action" == "exit" ]]; then
		exit 1
	fi

	if [[ -z "$result" ]]; then
		echo "Error: No service selected" >&2
		exit 1
	fi

	parse_service_selection "$result"

	if [[ -z "$service_name" ]]; then
		echo "Error: Could not parse service name" >&2
		exit 1
	fi

	execute_action "$action"
}

# Build command string based on action
build_command() {
	local action="$1"

	case "$action" in
		"tail")
			echo "journalctl $user_arg -u '$service_name' -f"
			;;
		"list_actions")
			local selected_action
			selected_action=$(echo "$ALL_ACTIONS" | rofi -dmenu -i -p "Select action: ")
			if [[ -n "$selected_action" ]]; then
				build_command "$selected_action"
			else
				echo "Error: No action selected" >&2
				return 1
			fi
			;;
		*)
			echo "$command $action '$service_name'"
			;;
	esac
}

# Execute the selected action
execute_action() {
	local action="$1"
	local to_run

	to_run="$(build_command "$action")"

	if [[ -z "$to_run" ]]; then
		echo "Error: Could not build command" >&2
		return 1
	fi

	# Run in terminal if not connected to a terminal and using journalctl
	if [[ ! -t 1 ]] && [[ "$to_run" == *"journalctl"* ]]; then
		to_run="$TERM $to_run"
	fi

	echo "Running: $to_run"
	eval "$to_run"
}

# Main execution
main() {
	# Combine user and system units, format with columns, and show selection menu
	{
		get_units user
		get_units system
	} | column -tc 1 | select_service_and_act
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
