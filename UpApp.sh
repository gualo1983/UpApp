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
   local is_config_corrupted=0 # Inizializza qui

   local files_to_check=(
     "$CONFIG_FILE"
     "$ICON_SUCCESS"
     "$ICON_RUNNING"
     "$ICON_ERROR"
   )

   local files_to_create=(
     "$LANG_MISSING"
     "$CURRENT_LANG_FILE"
     "$LOG_FILE"
     "$CONFIG_FILE"
   )

   local dirs_to_create=(
     "$RESOURCES_DIR"
     "$LANG_DIR"
   )

   local config_writes=(
     "resource_dir_exists:true"
     "lang_dir_exists:true"
     "config_file_exists:true"
     "icon_success_exists:true"
     "icon_running_exists:true"
     "icon_error_exists:true"
   )

   local config_checks=(
     "resource_dir_exists:true:resource_dir_exists_read_error"
     "lang_dir_exists:true:lang_dir_exists_read_error"
     "config_file_exists:true:config_file_exists_read_error"
     "icon_success_exists:true:icon_success_exists_read_error"
     "icon_running_exists:true:icon_running_exists_read_error"
     "icon_error_exists:true:icon_error_exists_read_error"
   )

   create_directories() {
     local dir
     for dir in "${dirs_to_create[@]}"; do
 #      echo "DEBUG: create_directories - Verifico directory: $dir"
       if ! check_dir "$dir" "initialization"; then
         log_message "$(lang "initialization" "create_dir" "$(basename "$dir")" "$dir")"
         error_found=1
       fi
     done
   }

   create_files() {
     local file
     for file in "${files_to_create[@]}"; do
  #     echo "DEBUG: create_files - Verifico file (creazione se manca): $file"
       if ! check_file "$file" "initialization" "true"; then
         log_message "$(lang "initialization" "create_file" "$(basename "$file")" "$file")"
         error_found=1
       fi
     done
   }

   check_files_exist() {
     local file
     for file in "${files_to_check[@]}"; do
 #      echo "DEBUG: check_files_exist - Verifico esistenza file: $file"
       if ! check_file "$file" "initialization" "false"; then
         log_message "$(lang "initialization" "find_file" "$(basename "$file")" "$attempt")"
         error_found=1
       fi
     done
   }

   while [ "$attempt" -le "$max_attempts" ]; do
 #    echo "DEBUG: *** Inizio tentativo di inizializzazione numero: $attempt ***"
     error_found=0
     error_check=0
     is_config_corrupted=0

 #    echo "DEBUG: Chiamo check_file per CONFIG_FILE: $CONFIG_FILE (create_if_missing=false)"
     if check_file "$CONFIG_FILE" "initialization" "false"; then
 #      echo "DEBUG: check_file per CONFIG_FILE ha restituito 0 (il file ESISTE)"
       log_message "$(lang "initialization" "config_already_exists" "$attempt")"

       local check_item
       local expected_value
       local config_key
       local log_key

       for check_item in "${config_checks[@]}"; do
         IFS=':' read -r config_key expected_value log_key <<< "$check_item"
         local current_value="$(read_value "$CONFIG_FILE" "$config_key")"
  #       echo "DEBUG: Controllo config esistente - chiave='$config_key', valore letto='$current_value', valore atteso='$expected_value'"
         if [ "$current_value" != "$expected_value" ]; then
           log_message "$(lang "initialization" "$log_key" "$CONFIG_FILE")"
           is_config_corrupted=1
         fi
       done

       local current_distro_check="$(get_distro)"
       local stored_distro="$(read_value "$CONFIG_FILE" "os_detected")"
  #     echo "DEBUG: Controllo OS - attuale='$current_distro_check', memorizzato='$stored_distro' (codice get_distro: $?)"
       if [ $? -eq 0 ] && [ "$stored_distro" != "$current_distro_check" ]; then
         log_message "$(lang "initialization" "os_detected_read_error" "$CONFIG_FILE")"
         is_config_corrupted=1
       fi

       if [ "$is_config_corrupted" -eq 0 ]; then
         log_message "$(lang "initialization" "config_ok")"
         log_message "$(lang "initialization" "check_executed_successfully" "$attempt")"
         break # Exit the loop if the file is intact
       else
         log_message "$(lang "initialization" "config_corrupted" "$attempt")"
   #      echo "DEBUG: Provo a rimuovere il file CONFIG_FILE: $CONFIG_FILE"
         rm "$CONFIG_FILE"
       fi
     else
   #    echo "DEBUG: check_file per CONFIG_FILE ha restituito 1 (il file NON ESISTE)"
       log_message "$(lang "initialization" "find_config_file" "$attempt")"
       create_directories
       create_files
       check_files_exist

       distro="$(get_distro)"
  #     echo "DEBUG: get_distro ha restituito: $distro (codice uscita: $?)"
       if [ $? -eq 1 ]; then
         log_message "$(lang "initialization" "get_distro")"
         error_found=1
       fi

       if [ "$error_found" -eq 0 ]; then
         log_message "$(lang "initialization" "write_config_file" "$attempt")"
         config_writes+=("os_detected:$distro")
         local key_value
         local key
         local value

         for key_value in "${config_writes[@]}"; do
           IFS=':' read -r key value <<< "$key_value"
   #        echo "DEBUG: Scrivo nel config: chiave='$key', valore='$value'"
           if ! write_value "$CONFIG_FILE" "$key" "$value"; then
             log_message "$(lang "initialization" "write_value_error" "$key" "$value" "$CONFIG_FILE")"
             error_found=1
           fi
         done

         if [ "$error_found" -eq 0 ]; then
           log_message "$(lang "initialization" "written_values")"
           break # Exit the loop if initialization is successful
         else
           log_message "$(lang "initialization" "written_values_error_occurred" "$attempt")"
         fi
       else
         log_message "$(lang "initialization" "error_creating_resources" "$attempt")"
       fi
     fi
     attempt=$((attempt + 1))
   #  echo "DEBUG: *** Fine tentativo numero: $attempt - Stato error_found: $error_found, error_check: $error_check, is_config_corrupted: $is_config_corrupted ***"
   done

   if [ "$attempt" -gt "$max_attempts" ]; then
     handler_error "Initialization" "$(lang "initialization" "max_attempts" "$max_attempts")" "$ICON_ERROR"
     return 1 # Indicates a critical failure
   fi
   log_message "$(lang "initialization" "initialization_successfully")" "$ICON_SUCCESS"
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