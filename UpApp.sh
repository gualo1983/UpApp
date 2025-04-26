#!/bin/bash

#
# This script is distributed under the GNU General Public License v3.0.
# For more details, please refer to the LICENSE file.
#
# UpApp Copyright (C) [2025] gualo1983 
#

Version=1.0.5

# Get the directory where the script is located
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Folder for resources and languages
RESOURCES_DIR="$SCRIPT_DIR/resources"
LANG_DIR="$RESOURCES_DIR/lang"
CONFIG_FILE="$RESOURCES_DIR/config.ini"
LOG_FILE="$RESOURCES_DIR/UpApp.log"
ICON_DIR="$RESOURCES_DIR/icon"
ICON_SUCCESS="$ICON_DIR/success.svg"
ICON_RUNNING="$ICON_DIR/running.svg"
ICON_ERROR="$ICON_DIR/error.svg"

# Variables for the current and default languages (default English)
CURRENT_LANG="it"
DEFAULT_LANG="en"
CURRENT_LANG_FILE=$LANG_DIR/${CURRENT_LANG}.ini
LANG_MISSING=$LANG_DIR/${DEFAULT_LANG}_missing.ini

# Variable to store the ID of the notify-send popup
NOTIFICATION_ID=""

# Variable to store any errors
error_found=0
error_message=""

# Function to write to the log with a timestamp
log_message() {
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  local message="$1"
  echo "[$timestamp] $message" >> "$LOG_FILE"
}

# Function to create a notification popup
create_popup() {
 local title="$1"
 local text="$2"
 local icon="$3"
 notify-send -r "$NOTIFICATION_ID" -a "UpApp" "$title" "$text" -i "$icon"
}

# Function to handle errors: logs the error and displays a popup
handler_error() {
  local error_source="$1"
  local error_msg="$2"
  local icon="$3"

  # Prepare the text to call the log handler
  log_message "$error_source $error_msg"

  # Send a popup to the user to inform them of the error
  create_popup "$error_source" "$error_msg" "$icon"
}

# Function to check if a directory exists and optionally creates it
check_dir() {
  local dir_path="$1"
  if [ ! -d "$dir_path" ]; then
    log_message "$(lang "check_dir" "not_exists" "$dir_path")"
    mkdir "$dir_path"
    if [ $? -ne 0 ]; then
      log_message "$(lang "check_dir" "unable_create" "$dir_path")"
      return 1 # Indica errore
    else
      log_message "$(lang "check_dir" "create_successfully" "$dir_path")"
      return 0 # Indica successo
    fi
  else
    log_message "$(lang "check_dir" "already_exists" "$dir_path")"
    return 0 # Indica successo
  fi
}

# Function to check if a file exists and optionally creates it
check_file() {
  local file_path="$1"
  local error_prefix="$2" # Prefix for error messages (e.g., "check_file")
  local create_if_missing="$3" # Optional: create the file if it doesn't exist (true/false)

  if [ ! -f "$file_path" ]; then
    log_message "$(lang "check_file" "not_exists" "$file_path")"
    if [ "$create_if_missing" = "true" ]; then
      log_message "$(lang "check_file" "creating")"
      touch "$file_path"
      if [ $? -ne 0 ]; then
        log_message "$(lang "check_file" "creation_failed" "$file_path")"
        return 1 # indicates error
      else
        log_message "$(lang "check_file" "creation_success" "$file_path")"
        return 0 # indicates success
      fi
    else
      log_message "$(lang "check_file" "not_found" "$file_path")"
      return 1 # indicates error
    fi
  else
   log_message "$(lang "check_file" "exists" "$file_path")"
    return 0 # Indica successo
  fi
}

# Function to read the value of a key in a given file
read_value() {
 local file="$1"
 local key="$2"
 
 # Force the reopening of the file for reading
 exec 3<>"$file" # Opens the file in read and write mode on file descriptor 3
 local value
 while IFS='=' read -r read_key value <&3; do
  if [ "$read_key" = "$key" ]; then
   echo "$value"
   exec 3<&- # Closes file descriptor 3
   return 0
  fi
 done
 exec 3<&- # Closes file descriptor 3 (if the loop ends without finding the key)
 echo "no value"
 return 1
}

# Function to write a key-value pair to a file
write_value() {
 local new_key="$2"
 local new_value="$3"
 local file="$1"
 exec 4<>"$file"
 # Check if the key already exists
 if grep -q "^${new_key}=" <&4; then
    log_message "$(lang "write_value" "exists" "$new_key")"
    exec 4<&-
   local old_value=$( read_value "$file" "$new_key" )
   if [ "$old_value" != "$new_value" ]; then
   	  modify_value "$file" "$new_key" "$new_value"
    	if [ $? -eq 0 ]; then
        log_message "$(lang "write_value" "key_updated")"
        cat "$file" > /dev/null
   	    return 0
	    else
        log_message "$(lang "write_value" "error_inserting_data")"
	      return 1
    	fi
    else
     log_message "$(lang "write_value" "no_changes")"
     return 0 # Indicates that the key already existed
    fi
  else
    echo "${new_key}=${new_value}" >> "$file"
    if [ $? -eq 0 ]; then
      log_message "$(lang "write_value" "added_successfully" "$new_key" "$new_value")"
      cat "$file" > /dev/null
      return 0 # Indicates success
    else
      log_message "$(lang "write_value" "unable_add" "$new_key")"
      return 1 # Indicates error
    fi
  fi
  exec 4<&-
}

# Function to modify the value of an existing key in a file
modify_value() {
  local file="$1"
  local key_to_modify="$2"
  local new_value="$3"
  local temp_file=$(mktemp) # Creates a secure temporary file

  # Read the file line by line and make the necessary changes
  exec 5<"$file"
  while IFS= read -r line <&5; do
    #  echo "line letta (hexdump -C):"
    #  echo "$line" | hexdump -C

    # Try a direct string comparison (may be more sensitive to invisible characters)
    if [ "${line%=*}" = "$key_to_modify" ]; then
      # Found key (with direct comparison), writing: "$key_to_modify" and "$new_value" to temporary file"
      echo "${key_to_modify}=${new_value}" >> "$temp_file"
    else
      # "Key not found (with direct comparison), writing original line to temporary"
      echo "$line" >> "$temp_file"
    fi
  done
  exec 5<&-

  # Replace the original file with the modified one
  mv "$temp_file" "$file"

  if [ $? -eq 0 ]; then
    log_message "$(lang "modify_value" "successfully" "$key_to_modify")"
    cat "$file" > /dev/null
    return 0 # Successo
  else
    log_message "$(lang "modify_value" "error" "$key_to_modify")"
    return 1 # Errore
  fi
}

# Function to get the distribution name
get_distro() {
  if [ -f "/etc/os-release" ]; then
    source /etc/os-release
    echo "$ID"
    return 0
  else
    log_message "$(lang "get_distro" "unrecognized_os" "unrecognized_os")"
    return 1
  fi
}


# Function to substitute placeholders in a string
replace_msg() {
  local text="$1"
  shift # Removes the text from the argument list
  local i=1

  while [ $# -gt 0 ]; do
    local placeholder="PARM$i"
    local value="$1"
    text="${text//$placeholder/$value}"
    shift # Removes the current value from the argument list
    i=$((i + 1))
  done

  echo "$text"
}

# Function to retrieve localized text
lang() {
  local lang_file="$CURRENT_LANG_FILE"
  local lang_missing="$LANG_MISSING"
  local key_to_search="$1_$2"
  local missing_test="$3"
  local text

  text=$(read_value "$lang_file" "$key_to_search")
  if [ "$?" -ne 0 ];  then
    local error_message
    error_message=$(read_value "$lang_file" "lang_lang_error")
    # Pass the error message and the parameters to substitute
    replace_msg "$error_message" "$key_to_search" "$lang_file"
    # Call write_value()
    write_value "$lang_missing" "$key_to_search" "$missing_test"
    # Check the write outcome and display a message
    if [ "$?" -eq 0 ]; then
      log_message "$(lang "lang" "added_lang_missing" "$key_to_search" "$lang_missing")"
    else
      log_message "$(lang "lang" "unable_write" "$key_to_search" "$lang_missing")"
    fi
  else
    # Pass the translated text and all additional parameters to replace_msg
    shift 2 # Removes the first two parameters (part1 and part2 of the key)
    replace_msg "$text" "$@"
  fi
}

# Function to perform the initialization of the program, 
initialization() {
  local error_found=0
  local error_check=0
  local max_attempts=3
  local attempt=1
  local distro=""

  while [ "$attempt" -le "$max_attempts" ]; do
    error_found=0
    error_check=0

    if ! check_file "$CONFIG_FILE" "initialization" "false"; then
      log_message "$(lang "inizialization" "find_config_file" "$attempt")"
      if ! check_dir "$RESOURCES_DIR" "initialization"; then
        log_message "$(lang "inizialization" "create_dir_resources" "$RESOURCES_DIR")"
        error_found=1
      fi
      if ! check_dir "$LANG_DIR" "initialization"; then
        log_message "$(lang "inizialization" "create_dir_lang" "$LANG_DIR")"
        error_found=1
      fi
      if ! check_file "$LANG_MISSING" "initialization" "true"; then
        log_message "$(lang "inizialization" "create_lang_missing_file" "$LANG_MISSING")"
        error_found=1
      fi
      if ! check_file "$CURRENT_LANG_FILE" "initialization" "true"; then
        log_message "$(lang "inizialization" "create_current_lang_file" "$CURRENT_LANG_FILE")"
        error_found=1
      fi
      if ! check_file "$LOG_FILE" "initialization" "true"; then
        log_message "$(lang "inizialization" "create_log_file" "$LOG_FILE")"
        error_found=1
      fi 
      if ! check_file "$CONFIG_FILE" "initialization" "true"; then
        log_message "$(lang "inizialization" "create_config_file" "$CONFIG_FILE")"
        error_found=1
      fi
      if ! check_file "$ICON_SUCCESS" "initialization" "false"; then
        log_message "$(lang "inizialization" "check_icon_success_file" "$ICON_SUCCESS")"
        error_found=1
      fi
      if ! check_file "$ICON_RUNNING" "initialization" "false"; then
        log_message "$(lang "inizialization" "check_icon_running_file" "$ICON_RUNNING")"
        error_found=1
      fi
      if ! check_file "$ICON_ERROR" "initialization" "false"; then
        log_message "$(lang "inizialization" "check_icon_error_file" "$ICON_ERROR")"
        error_found=1
      fi
      distro="$(get_distro)"
        if [ $? -eq 1 ]; then
          log_message "$(lang "inizialization" "get_distro")"
          error_found=1
        fi
          if [ "$error_found" -eq 0 ]; then
            log_message "$(lang "inizialization" "write_config_file" "$attempt")"
            if ! write_value "$CONFIG_FILE" "os_detected" "$distro"; then
            log_message "$(lang "inizialization" "os_detected" "$distro" "$CONFIG_FILE")"
            error_found=1
            fi
            if ! write_value "$CONFIG_FILE" "resource_dir_exists" "true"; then
            log_message "$(lang "inizialization" "resource_dir_exists" "$CONFIG_FILE")"
            error_found=1
            fi
            if ! write_value "$CONFIG_FILE" "lang_dir_exists" "true"; then
            log_message "$(lang "inizialization" "lang_dir_exists" "$CONFIG_FILE")"
            error_found=1
            fi
            if ! write_value "$CONFIG_FILE" "config_file_exists" "true"; then
            log_message "$(lang "inizialization" "config_file_exists" "$CONFIG_FILE")"
            error_found=1
            fi
            if ! write_value "$CONFIG_FILE" "icon_success_exists" "true"; then
            log_message "$(lang "inizialization" "icon_success_exists" "$CONFIG_FILE")"
            error_found=1
            fi
            if ! write_value "$CONFIG_FILE" "icon_running_exists" "true"; then
            log_message "$(lang "inizialization" "icon_running_exists" "$CONFIG_FILE")"
            error_found=1
            fi
            if ! write_value "$CONFIG_FILE" "icon_error_exists" "true";then
            log_message "$(lang "inizialization" "icon_error_exists" "$CONFIG_FILE")"
            error_found=1
          else
            log_message "$(lang "inizialization" "written_values" "Initialization values written correctly to the configuration file")"
            break # Exit the loop if initialization is successful
          fi
        else
          log_message "$(lang "inizialization" "written_values_error_occurred" "$attempt")"
        fi  
    else
      log_message "$(lang "inizialization" "config_already_exists" "$attempt")"
      if [ "$(read_value "$CONFIG_FILE" "resource_dir_exists" )" != "true" ]; then
        log_message "$(lang "inizialization" "read_resource_dir_exists" "$CONFIG_FILE")"
        error_check=1
      fi
      if [ "$(read_value "$CONFIG_FILE" "lang_dir_exists" )" != "true" ]; then
        log_message "$(lang "inizialization" "read_lang_dir_exists" "$CONFIG_FILE")"
        error_check=1
      fi
      if [ "$(read_value "$CONFIG_FILE" "config_file_exists" )" != "true" ]; then
        log_message "$(lang "inizialization" "read_config_file_exists" "$CONFIG_FILE")"
        error_check=1
      fi
      if [ "$(read_value "$CONFIG_FILE" "icon_success_exists" )" != "true" ]; then
        log_message "$(lang "inizialization" "read_icon_success_exists" "$CONFIG_FILE")"
        error_check=1
      fi
      if [ "$(read_value "$CONFIG_FILE" "icon_running_exists" )" != "true" ]; then
        log_message "$(lang "inizialization" "read_icon_running_exists" "$CONFIG_FILE")"
        error_check=1
      fi
      if [ "$(read_value "$CONFIG_FILE" "icon_error_exists" )" != "true" ]; then
        log_message "$(lang "inizialization" "read_icon_error_exists" "$CONFIG_FILE")"
        error_check=1
      fi
      local current_distro_check="$(get_distro)"
      if [ $? -eq 0 ] && [ "$(read_value "$CONFIG_FILE" "os_detected" )" != "$current_distro_check" ]; then
        log_message "$(lang "inizialization" "read_os_detected" "$CONFIG_FILE")"
        error_check=1
      fi
      if [ "$error_check" -eq 0 ]; then
        log_message "$(lang "inizialization" "config_ok")"
        log_message "$(lang "inizialization" "check_executed_seccessfully" "$attempt")"
        break # Exit the loop if the file is intact
      else
        log_message "$(lang "inizialization" "config_corrupted" "$attempt")"
        rm "$CONFIG_FILE"
      fi
    fi
    attempt=$((attempt + 1))
  done

  if [ "$attempt" -gt "$max_attempts" ]; then
    handler_error "Inizialization" "$(lang "inizialization" "max_attemps" "$max_attempts")" "$ICON_ERROR"
    return 1 # Indica un fallimento critico
  fi
    log_message "$(lang "inizialization" "inizialization_successfully")" "$ICON_SUCCESS"
  return 0
}

# check and if necessary install libnotify
check_notify_send() {
  local distro="$(read_value "$CONFIG_FILE" "os_detected")"
  if ! command -v notify-send &> /dev/null; then
    log_message "$(lang "notify_send" "not_found")"
    read -p "$(lang "notify_send" "install") " install_notify
    if [[ "$install_notify" == "s" || "$install_notify" == "S" || "$install_notify" == "y" || "$install_notify" == "Y" ]]; then
      case "$distro" in
        debian*)
          sudo apt update && sudo apt install -y libnotify-bin
          if ! command -v notify-send &> /dev/null; then
            handler_error "notify_send" "install_failed" "$ICON_ERROR"
            return 1
          fi
          ;;
        fedora*)
          sudo dnf install -y libnotify
          if ! command -v notify-send &> /dev/null; then
            handler_error "notify_send" "install_failed" "$ICON_ERROR"
            return 1
          fi
          ;;
        arch*)
          sudo pacman -S --noconfirm libnotify
          if ! command -v notify-send &> /dev/null; then
            handler_error "notify_send" "install_failed" "$ICON_ERROR"
            return 1
          fi
          ;;
        opensuse*)
          sudo zypper install -y libnotify
          if ! command -v notify-send &> /dev/null; then
            handler_error "notify_send" "install_failed" "$ICON_ERROR"
            return 1
          fi
          ;;
        *)
          handler_error "notify_send" "install_failed" "$ICON_ERROR"
          return 1
          ;;
      esac
    else
      log_message "$(lang "notify_send" "notify_disabled")"
      return 1
    fi
  fi
  return 0
}

# check the OS, then update and clean repository 
update_system() {
  local error_found=0
  local distro="$(read_value "$CONFIG_FILE" "os_detected")"
  case "$distro" in
   debian*)
    log_message "$(lang "update_system" "debian_update")"
    sudo apt update
    if [[ $? -ne 0 ]]; then
      handler_error "update_system" "$(lang "update_system" "debian_update_error")" "$ICON_ERROR"
      error_found=1
    else
      log_message "$(lang "update_system" "debian_upgrade")"
      sudo apt upgrade -y
      if [[ $? -ne 0 ]]; then
        handler_error "update_system" "$(lang "update_system" "debian_upgrade_error")" "$ICON_ERROR"
        error_found=1
      else
        log_message "$(lang "update_system" "debian_autoremove")"
        sudo apt autoremove -y
        if [[ $? -ne 0 ]]; then
          handler_error "update_system" "$(lang "update_system" "debian_autoremove_error")" "$ICON_ERROR"
          error_found=1
        else
          error_found=0
        fi
      fi
    fi
    ;;
  fedora*)
    log_message "$(lang "update_system" "fedora_update")"
    sudo dnf update --refresh -y
    if [[ $? -ne 0 ]]; then
      handler_error "update_system" "$(lang "update_system" "fedora_update_error")" "$ICON_ERROR"
      error_found=1
    else
      log_message "$(lang "update_system" "fedora_autoremove")"
      sudo dnf autoremove -y
      if [[ $? -ne 0 ]]; then
        handler_error "update_system" "$(lang "update_system" "fedora_autoremove_error")" "$ICON_ERROR"
        error_found=1
      else
        error_found=0
      fi
    fi
    ;;
  arch*)
    log_message "$(lang "update_system" "arch_update")"
    sudo pacman -Syu --noconfirm
    if [[ $? -ne 0 ]]; then
      handler_error "update_system" "$(lang "update_system" "arch_update_error")" "$ICON_ERROR"
      error_found=1
    else
      log_message "$(lang "update_system" "arch_autoremove")"
      sudo pacman -Sc --noconfirm
      if [[ $? -ne 0 ]]; then
        handler_error "update_system" "$(lang "update_system" "arch_autoremove_error")" "$ICON_ERROR"
        error_found=1
      else
        error_found=0
      fi
    fi
    ;;
  opensuse*)
    log_message "$(lang "update_system" "opensuse_update")"
    sudo zypper refresh
    if [[ $? -ne 0 ]]; then
      handler_error "update_system" "$(lang "update_system" "opensuse_update_error")" "$ICON_ERROR"
      error_found=1
    else
      log_message "$(lang "update_system" "opensuse_upgrade")"
      sudo zypper update -y
      if [[ $? -ne 0 ]]; then
        handler_error "update_system" "$(lang "update_system" "opensuse_upgrade_error")" "$ICON_ERROR"
        error_found=1
      else
        log_message "$(lang "update_system" "opensuse_autoremove")"
        sudo zypper clean --all
        if [[ $? -ne 0 ]]; then
          handler_error "update_system" "$(lang "update_system" "opensuse_autoremove_error")" "$ICON_ERROR"
          error_found=1
        else
          error_found=0
        fi
      fi
    fi
    ;;
  *)
   handler_error "update_system" "$(lang "update_system" "unsupport_os")" "$ICON_ERROR"
   error_found=1
    ;;
  esac

  # Upgrade Flatpak
    log_message "$(lang "update_system" "flatpack")"
  flatpak update -y
  if [[ $? -ne 0 ]]; then
    handler_error "update_system" "$(lang "update_system" "flatpack_update_error")" "$ICON_ERROR"
    error_found=1
  else
    log_message "$(lang "update_system" "flatpack_cleaning")"
    flatpak uninstall --unused -y
    if [[ $? -ne 0 ]]; then
      handler_error "update_system" "$(lang "update_system" "flatpack_cleaning_error")" "$ICON_ERROR"
      error_found=1
    else
      error_found=0
    fi
  fi
}


UpApp() {
  
  log_message "_-_-_-_-UpApp-_-_-_-_-"

  if ! check_notify_send; then
    log_message "$(lang "inizialization" "check_notify_send")" 
  fi

  local text="$(lang "startApp" "msg_notify")"
  NOTIFICATION_ID=$(notify-send -a UpApp " " "$text" -i "$ICON_RUNNING"  -p)

  sleep 5
  initialization
  local update=$(update_system)
  if [ "$?" -eq 0 ]; then
    handler_error "startApp" "$(lang "startApp" "update")" "$ICON_SUCCESS"
  else
    handler_error "startApp" "$(lang "startApp" "contact")" "$ICON_ERROR"
  fi

  log_message "-_-_-_-_-Finish log-_-_-_-_-"
}

UpApp