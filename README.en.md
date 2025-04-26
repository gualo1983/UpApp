# UpApp - System Update Script

[![Status: In Development]][status-badge]

[status-badge]: (https://img.shields.io/badge/Status-In%20Development-yellow)

**UpApp** is a Bash script designed to simplify the updating of the operating system and Flatpak applications on various Linux distributions. The main goal is to automate the update process, providing visual notifications of the status and logging operations to a file.

## Features

* **Automatic Distribution Detection:** Identifies the running Linux distribution using the standard `/etc/os-release` file.
* **System Update:** Executes specific commands to update the system based on the detected distribution (supports Debian, Fedora, Arch Linux, and openSUSE).
* **System Cleanup:** Removes orphaned or unnecessary packages after the update.
* **Flatpak Update:** Updates all installed Flatpak applications and removes unused ones.
* **Desktop Notifications:** Uses `notify-send` to provide visual feedback to the user on the progress and outcome of operations. Requires `libnotify-bin` (or equivalent packages) to be installed.
* **Detailed Log:** Records all operations, errors, and warnings in a log file (`UpApp.log`) in the resources folder.
* **Language Management:** Supports multiple languages through `.ini` configuration files. English is the default language, with the possibility to add translations.
* **Configuration:** Uses a configuration file (`config.ini`) to store the program's status and settings.
* **Error Handling:** Implements error handling with logging and visual notifications.
* **Initialization Attempts:** Attempts initialization (creating necessary directories and files) up to a maximum of 3 times in case of initial failure.

## Prerequisites

* **Bash:** A compatible Bash shell.
* **sudo:** Administrator privileges (will be required for system updates).
* **notify-send:** Utility for sending desktop notifications (usually provided by the `libnotify-bin` package or equivalent). The script attempts to install it if not found.
* **Flatpak:** Installed on the system for updating Flatpak applications.

## Folder Structure
```
UpApp/
├── resources/
│   ├── config.ini            # Configuration file
│   ├── lang/
│   │   ├── en.ini            # Default language file (English)
│   │   └── it.ini            # Current language file (Italian)
│   │   └── en_missing.ini    # File for missing language keys
│   ├── icon/
│   │   ├── success.svg       # Success icon for notifications
│   │   └── running.svg       # Running icon for notifications
│   │   └── error.svg         # Error icon for notifications
├── UpApp.sh                  # The main script
├── LICENSE                   # GPLv3 license file
└── README.md                 # Markdown file explaining the project
```

## How to Use

1.  **Clone the repository:**
    ```bash
    git clone <repository_url>
    cd UpApp
    ```

2.  **Make the script executable:**
    ```bash
    chmod +x UpApp.sh
    ```

3.  **Run the script:**
    ```bash
    ./UpApp.sh
    ```

    The script will perform initialization, check and (if necessary) install `notify-send`, update the operating system and Flatpak applications, and display status notifications. Details will be logged in the `resources/UpApp.log` file.

## Configuration

The main configuration is managed internally by the script through the `resources/config.ini` file. This file stores the initialization status and the detected distribution. Manual modification is generally not required.

Language files (`.ini`) in the `resources/lang` folder contain translations of the displayed messages. To add or modify a language, you can create a new `.ini` file (following the `[language_code].ini` convention) and set the `CURRENT_LANG` variable in the script to the desired language code.

## Error Handling

The script includes error handling that logs issues to the `UpApp.log` file and displays desktop notifications using specific icons to indicate success, ongoing operation, or error.

## Supported Distributions

Currently, the script supports the following Linux distributions:

* Debian and derivatives (e.g., Ubuntu)
* Fedora
* Arch Linux
* openSUSE

Support for other distributions may be added in the future.

## Customization

* **Languages:** You can add translations for new languages by creating `.ini` files in the `resources/lang` folder.
* **Update Commands:** To support other distributions, you will need to add the specific update commands within the `update_system()` function.
* **Notifications:** The notification icons can be replaced by modifying the `.svg` files in the `resources/icon` folder.

## Contributing

Contributions are welcome! If you have suggestions, bug reports, or want to add support for new distributions, please open an issue or submit a pull request on GitHub.

## Icons

The icons used for notifications were released into the public domain under the [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/) license and originate from [vivek-g](https://iconduck.com/designers/vivek-g).

## Author

gualo1983

## License

This script is distributed under the GNU General Public License v3.0.

For more details, see the [LICENSE](LICENSE) file.