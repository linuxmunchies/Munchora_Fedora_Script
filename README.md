[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/H2H11MFEZL)
### **Overall Purpose**

This script is a comprehensive, post-installation utility for Fedora Linux. Its primary goal is to automate the setup of a fully-featured desktop environment tailored for development, multimedia, and gaming. It handles system checks, repository configuration, package installation, system optimization, user environment configuration, and hardware-specific tweaks based on your updated preferences.

***

### **1. Initial Setup and Pre-flight**

This section defines the foundational variables, helper functions, and system checks that ensure the script runs correctly.

* **Variables**: Defines key variables like `$ACTUAL_USER` (the non-root user), `$ACTUAL_HOME` (the user's home directory), and `$LOG_FILE` for recording the script's actions. It also sets up color codes for readable terminal output.
* **Helper Functions**: Includes logging functions (`log`, `log_success`, `log_warning`, `log_error`) to provide consistent, color-coded output to both the terminal and the log file.
* **System Checks**: Before running, the script confirms it has **root privileges** (`check_root`) and is running on **Fedora Linux** (`check_fedora`), exiting if either check fails.

---

### **2. System Preparation and Optimization**

This stage prepares the system's package manager, updates all packages, creates an initial system snapshot, and applies performance optimizations.

* **`setup_repositories()`**: Configures the system's DNF software sources. This includes adding the crucial **RPM Fusion** (free and non-free) and **Brave Browser** repositories.
* **`update_system()`**: Performs a full system upgrade by running `dnf upgrade`. This is now one of the first major steps to ensure the system is on a clean, up-to-date base before installing new software.
* **`setup_snapshots()`**: Configures system snapshots using `snapper`. It creates an **initial baseline snapshot** of the system *after* the update is complete but *before* new software and configurations are applied. This gives you a "clean install + updates" recovery point.
* **`optimize_system()`**: Applies system and DNF optimizations.
    * Sets the machine's hostname to **`Munchora`**.
    * Optimizes DNF by enabling the `fastestmirror` and increasing `max_parallel_downloads` for quicker package installation.

---

### **3. Software Installation**

This is the core of the script, where it installs a wide array of applications and tools from DNF and Flatpak.

* **`install_flatpak_support()`**: This new function installs the Flatpak client, adds the main **Flathub** remote repository, and runs an update. It is strategically called *after* the main system update to ensure the latest version of Flatpak is installed.
* **`install_system_tools()`**: Installs a large collection of command-line utilities. This includes `btop`, `git`, `neovim`, `zsh`, `kitty`, `rclone`, and the **Rust** programming language. It also now installs `python3-pip` and **`python3-devel`** for a more complete Python development environment.
* **`setup_virtualization()`**: Installs the QEMU/KVM virtualization stack and adds the user to the `libvirt` group for passwordless management of virtual machines.
* **`setup_multimedia()`**: Installs essential multimedia codecs and applications.
    * It now defaults to installing hardware acceleration drivers for **AMD GPUs**. The drivers for Intel GPUs are commented out but can be easily re-enabled.
    * It swaps `ffmpeg-free` for the full `ffmpeg` from RPM Fusion and installs tools like `vlc`, `mpv`, and `yt-dlp`.
* **`install_gaming()`**: Installs essential tools for gaming, including **Steam**, **GameMode**, **MangoHud**, and **GOverlay**. It also attempts to install ROCm packages if an AMD GPU is detected.
* **`install_brave_browser()`**: A dedicated function to install the Brave Browser.
* **`install_flatpaks()`**: Installs a curated list of applications from Flathub. The list has been updated to include:
    * **Added**: `com.discordapp.Discord` (the official Discord client).
    * **Removed**: Plex, Plexamp, Yuzu, Tube Converter, Tidal Hifi, and VideoDownloader.
* **Font Installation**: The script installs both developer-focused **Nerd Fonts** (`Hack`, `FiraCode`, etc.) locally for the user and a wide range of system-wide fonts (Google Noto, Microsoft Core Fonts) for excellent document and web compatibility.

---

### **4. System and User Configuration**

This section configures the user's environment, hardware settings, and system services to match your specifications.

* **`setup_gaming_tweaks()`**: Applies performance enhancements for gaming by creating configuration files for lower audio latency in **PipeWire** and optimized performance settings in **GameMode**.
* **`setup_gamedrive_mount()`**: Automates mounting a secondary game drive.
    * The hardcoded UUID has been changed to **`0095fb41-1e53-43fb-af70-11b11e746889`**.
    * The BTRFS mount options have been updated to `rw,noatime,space_cache=v2,compress=zstd:1,nofail` for better performance on a drive used for games.
* **`setup_cifs_mount()`**: An interactive function that prompts the user to set up CIFS/SMB network shares. It is called twice, allowing for the configuration of two separate mounts in one run.
* **User and Hardware Setup**: The script automates adding the user to necessary hardware groups (`render`, `video`), creating a custom directory structure in `~/ProtonDrive/`, and applying a power-monitoring fix for Intel CPUs (`setup_intel_powercap`).
* **Shell and Editor Setup**: The script replaces the default shell with **Zsh**, installing "Oh My Zsh" and a custom `.zshrc` from a GitHub repository. It also sets up Neovim with the "kickstart.nvim" configuration.
* **KDE Dark Mode Removed**: The function to automatically set a dark theme for KDE Plasma has been completely **removed**.

---

### **5. Finalization**

The script concludes with a final snapshot, cleanup, and a summary report.

* **`create_final_snapshot()`**: This new function runs at the end of the process to create a **final snapshot** of the fully configured system. This provides a "post-setup" recovery point.
* **`cleanup()`**: Frees up disk space by cleaning the DNF package cache and removing any unused Flatpak runtimes.
* **`generate_summary()`**: Displays a final "Setup Complete" message, shows the location of the log file, and runs `fastfetch` to provide a detailed system information overview.
* **`main()`**: The master function orchestrates the entire process in the correct order and concludes by prompting the user to reboot the system.
