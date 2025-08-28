#!/bin/bash

# Fedora Setup Script
# This script installs and configures a comprehensive set of applications and tools for Fedora

# ----- Variables -----
ACTUAL_USER=$(logname)
ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)
LOG_FILE="$ACTUAL_HOME/fedora_setup.log"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ----- Helper Functions -----
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] [INFO] $1" >> "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] [SUCCESS] $1" >> "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] [WARNING] $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] [ERROR] $1" >> "$LOG_FILE"
}

# ----- System Checks -----
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_fedora() {
    if ! grep -q "Fedora" /etc/os-release; then
        log_error "This script is designed for Fedora"
        exit 1
    fi
}

# ----- Installation Functions -----
setup_repositories() {
    log "Setting up repositories..."

    # Install DNF plugins
    dnf install -y dnf-plugins-core

    # Remove unwanted repositories
    log "Removing irrelevant repositories..."
    rm -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:phracek:PyCharm.repo
    rm -f /etc/yum.repos.d/google-chrome.repo
    rm -f /etc/yum.repos.d/rpmfusion-nonfree-nvidia-driver.repo
    rm -f /etc/yum.repos.d/rpmfusion-nonfree-steam.repo

    # Install RPM Fusion repositories
    log "Installing RPM Fusion repositories..."
    dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
                   https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

    # Setup Brave repository
    log "Setting up Brave browser repository..."
    dnf config-manager --add-repo https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
    rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc

    log_success "Repositories configured successfully"
}

setup_snapshots() {
    log "Setting up Snapper and creating initial snapshot..."

    # Check if filesystem is BTRFS
    if [ "$(findmnt -no FSTYPE /)" != "btrfs" ]; then
        log_warning "Not using BTRFS filesystem, snapshots may not work correctly"
    fi

    # Install snapper
    dnf install -y snapper

    # Configure snapper
    DATE=$(date +%Y-%m-%d-%H-%M-%S)

    # Enable and start snapper services
    systemctl enable --now snapper-timeline.timer snapper-cleanup.timer

    # Create configs if they don't exist
    if ! snapper -c root list &>/dev/null; then
        snapper -c root create-config /
    fi

    if ! snapper -c home list &>/dev/null; then
        snapper -c home create-config /home
    fi

    # Create initial snapshots
    log "Creating initial snapshot of clean, updated system..."
    snapper -c root create -d "${DATE}_Root_PostUpdate"
    snapper -c home create -d "${DATE}_Home_PostUpdate"
    log_success "Snapper configured and initial snapshots created"
}

create_final_snapshot() {
    log "Creating final snapshot of configured system..."
    DATE=$(date +%Y-%m-%d-%H-%M-%S)
    snapper -c root create -d "${DATE}_Root_PostSetup"
    snapper -c home create -d "${DATE}_Home_PostSetup"
    log_success "Final system snapshots created"
}

optimize_system() {
    log "Optimizing system configuration..."

    # Set hostname
    hostnamectl set-hostname Munchora

    # Optimize DNF
    log "Optimizing DNF configuration..."
    cp /etc/dnf/dnf.conf /etc/dnf/dnf.conf.bak

    # Update DNF configuration
    if grep -q "^fastestmirror=" /etc/dnf/dnf.conf; then
        sed -i 's/^fastestmirror=.*/fastestmirror=True/' /etc/dnf/dnf.conf
    else
        echo "fastestmirror=True" >> /etc/dnf/dnf.conf
    fi

    if grep -q "^max_parallel_downloads=" /etc/dnf/dnf.conf; then
        sed -i 's/^max_parallel_downloads=.*/max_parallel_downloads=10/' /etc/dnf/dnf.conf
    else
        echo "max_parallel_downloads=10" >> /etc/dnf/dnf.conf
    fi

    log_success "System optimization completed"
}

update_system() {
    log "Updating system packages..."
    dnf upgrade -y --refresh
    log_success "System updated successfully"
}

install_flatpak_support() {
    log "Setting up Flatpak..."
    dnf install -y flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak repair --system
    flatpak update -y
    log_success "Flatpak support installed and configured"
}

setup_multimedia() {
    log "Setting up multimedia support..."

    # Install multimedia codecs
    dnf swap -y ffmpeg-free ffmpeg --allowerasing
    dnf group install multimedia -y

    # Install hardware acceleration for Intel (commented out by default)
    # dnf install -y intel-media-driver libva-intel-driver

    # Install hardware acceleration for AMD
    dnf install -y libva-mesa-driver mesa-vdpau
    dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld
    dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld

    # Install multimedia packages
    dnf install -y gstreamer1-plugins-{good,base} gstreamer1-plugins-bad-free \
                   ffmpeg yt-dlp vlc mpv strawberry mediainfo flac lame \
                   libmpeg2 x264 x265

    log_success "Multimedia support installed"
}

install_system_tools() {
    log "Installing system utilities..."

    # Install system monitoring and utilities
    dnf install -y snapper fwupd cifs-utils samba-client btop htop \
                   fastfetch p7zip unzip git vim neovim curl wget fzf \
                   rsync lsof zsh gcc make python3-pip python3-devel duf inxi ncdu \
                   kitty bat wl-clipboard go tldr intel-gpu-tools rclone

    # Install Rust
    log "Installing rust..."
    if ! (sudo -u $ACTUAL_USER bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'); then
        log_error "Failed to install rust!"
    fi
    log_success "System utilities installed"
}

setup_virtualization() {
    log "Setting up virtualization support..."

    # Install virtualization packages
    dnf install -y @virtualization

    # Enable and start libvirtd service
    systemctl enable libvirtd
    systemctl start libvirtd

    # Add user to libvirt group
    usermod -aG libvirt $ACTUAL_USER

    log_success "Virtualization support installed"
}

install_gaming() {
    log "Installing gaming support..."

    # Install gaming utilities
    dnf install -y mangohud goverlay gamemode steam vulkan-loader steam-devices

    # ROCm packages if applicable
    if lspci | grep -i amd > /dev/null; then
        log "AMD GPU detected, checking for ROCm packages..."
        if dnf list rocm-opencl &>/dev/null; then
            log "Installing ROCm packages..."
            dnf install -y rocm-opencl rocm-hip-devel rocm-clinfo --allowerasing
        else
            log_warning "ROCm packages not found in repositories, skipping"
        fi
    fi

    log_success "Gaming support installed"
}

setup_gaming_tweaks() {
    log "Setting up gaming tweaks..."

    # Enable lower latency audio
    if systemctl --user -M $ACTUAL_USER@ is-active --quiet pipewire; then
        PIPEWIRE_DIR="$ACTUAL_HOME/.config/pipewire"
        mkdir -p "$PIPEWIRE_DIR/pipewire.conf.d"

        # Lower latency config
        cat > "$PIPEWIRE_DIR/pipewire.conf.d/99-lowlatency.conf" << EOF
{
  "context.properties": {
    "default.clock.rate": 48000,
    "default.clock.quantum": 256,
    "default.clock.min-quantum": 256,
    "default.clock.max-quantum": 1024
  }
}
EOF
        chown -R $ACTUAL_USER:$ACTUAL_USER "$PIPEWIRE_DIR"
        log "Configured low-latency audio"
    else
        log_warning "Pipewire not running, skipping audio latency optimization"
    fi

    # Install gamemode with correct configuration
    if command -v gamemode-simulate-game &> /dev/null; then
        GAMEMODE_DIR="$ACTUAL_HOME/.config/gamemode"
        mkdir -p "$GAMEMODE_DIR"

        # Create gamemode config file
        cat > "$GAMEMODE_DIR/gamemode.ini" << EOF
[general]
renice=10
ioprio=0
inhibit_screensaver=1

[gpu]
apply_gpu_optimisations=1
gpu_device=0
amd_performance_level=high

[custom]
start=notify-send "GameMode started"
end=notify-send "GameMode ended"
EOF
        chown -R $ACTUAL_USER:$ACTUAL_USER "$GAMEMODE_DIR"
        log "Configured GameMode for optimal performance"
    else
        log_warning "GameMode not installed, skipping GameMode configuration"
    fi

    log_success "Gaming tweaks applied successfully"
}

mkdir_proton() {
  mkdir -p $ACTUAL_HOME/ProtonDrive/Archives/{Discord,Obsidian} $ACTUAL_HOME/ProtonDrive/Career/MainDocs/
  chown -R $ACTUAL_USER:$ACTUAL_USER $ACTUAL_HOME/ProtonDrive
  log_success "ProtonDrive directories created successfully"
}

setup_gamedrive_mount() {
  log "Setting up game drive mount..."

  # Set mount details
  GAME_DRIVE_UUID="0095fb41-1e53-43fb-af70-11b11e746889"
  MOUNT_POINT="/mnt/gamedrive"
  MOUNT_OPTIONS="rw,noatime,space_cache=v2,compress=zstd:1,nofail"
  FSTAB_ENTRY="UUID=$GAME_DRIVE_UUID $MOUNT_POINT btrfs $MOUNT_OPTIONS 0 0"

  # Check if drive exists using UUID
  if ! blkid -U "$GAME_DRIVE_UUID" > /dev/null 2>&1; then
    log_warning "Game drive with UUID $GAME_DRIVE_UUID not detected, skipping mount setup"
    return 0
  fi

  log "Game drive detected, proceeding with mount setup"

  # Create mount point if it doesn't exist
  if ! [ -d "$MOUNT_POINT" ]; then
    log "Creating mount point at $MOUNT_POINT"
    mkdir -p "$MOUNT_POINT"
  fi

  # Mount the drive if not already mounted
  if ! mount | grep -q "$MOUNT_POINT"; then
    log "Mounting game drive to $MOUNT_POINT"
    mount -U "$GAME_DRIVE_UUID" "$MOUNT_POINT" -o "$MOUNT_OPTIONS"
    if [ $? -ne 0 ]; then
      log_error "Failed to mount game drive"
      return 1
    fi
  else
    log "Game drive already mounted to $MOUNT_POINT"
  fi

  # Add to fstab if not already there
  if ! grep -q "$GAME_DRIVE_UUID" /etc/fstab; then
    log "Adding game drive to /etc/fstab for auto-mount on boot"
    echo "$FSTAB_ENTRY" | tee -a /etc/fstab > /dev/null
  else
    log "Game drive already in /etc/fstab"
  fi

  # Reload systemd to recognize changes in fstab
  systemctl daemon-reload

  log_success "Game drive mounted successfully and set up for auto-mount on boot"
  return 0
}

setup_user_groups() {
  log "Adding user to important system groups..."

  for GROUP in render video input dialout plugdev; do
    if getent group $GROUP > /dev/null; then
      usermod -a -G $GROUP $ACTUAL_USER
      log "Added user to $GROUP group"
    else
      log_warning "$GROUP group not found, skipping"
    fi
  done

  log_success "User groups setup completed"
}

install_nerd_fonts() {
  log "Installing Nerd Fonts..."

  FONTS_DIR="$ACTUAL_HOME/.local/share/fonts"
  mkdir -p "$FONTS_DIR"

  TEMP_DIR=$(mktemp -d)

  # Function to download and extract font
  download_font() {
    local font_name=$1
    local zip_file="${font_name}.zip"
    log "Downloading ${font_name} Nerd Font..."
    if wget -q "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/${zip_file}" -P "$TEMP_DIR"; then
      unzip -q "$TEMP_DIR/$zip_file" -d "$FONTS_DIR/${font_name}"
      log "Installed ${font_name} Nerd Font"
    else
      log_error "Failed to download ${font_name} Nerd Font"
    fi
  }

  download_font "Hack"
  download_font "FiraCode"
  download_font "JetBrainsMono"
  download_font "CascadiaCode"

  rm -rf "$TEMP_DIR"

  # Update font cache as the user
  sudo -u $ACTUAL_USER fc-cache -f

  chown -R $ACTUAL_USER:$ACTUAL_USER "$FONTS_DIR"

  log_success "Nerd Fonts installed successfully"
}

install_system_fonts() {
  log "Installing system fonts..."

  dnf install -y google-noto-sans-fonts google-noto-serif-fonts google-noto-cjk-fonts google-noto-emoji-fonts \
                 liberation-fonts dejavu-fonts-all \
                 cabextract xorg-x11-font-utils \
                 ibm-plex-fonts-all mozilla-fira-fonts-common mozilla-fira-sans-fonts mozilla-fira-mono-fonts \
                 wqy-zenhei-fonts vlgothic-fonts smc-fonts-common

  # Install Microsoft fonts
  rpm -i https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm

  log_success "System fonts installed successfully"
}

install_flatpaks() {
    log "Installing Flatpak applications..."

    # Productivity apps
    flatpak install -y flathub org.onlyoffice.desktopeditors md.obsidian.Obsidian \
                             org.gimp.GIMP net.ankiweb.Anki

    # Browsers and communication
    flatpak install -y flathub io.gitlab.librewolf-community app.zen_browser.zen \
                             im.riot.Riot org.telegram.desktop dev.vencord.Vesktop \
                             com.discordapp.Discord

    # Media applications
    flatpak install -y flathub com.github.iwalton3.jellyfin-media-player \
                             org.kde.gwenview com.obsproject.Studio \
                             org.kde.kdenlive org.blender.Blender org.kde.krita \
                             com.spotify.Client

    # Gaming
    flatpak install -y flathub net.lutris.Lutris com.heroicgameslauncher.hgl

    # System utilities
    flatpak install -y flathub com.github.tchx84.Flatseal com.usebottles.bottles \
                             net.nokyan.Resources io.github.dimtpap.coppwr \
                             org.nickvision.cavalier com.rustdesk.RustDesk \
                             org.kde.kwalletmanager5

    log_success "Flatpak applications installed"
}

install_brave_browser() {
    log "Installing Brave Browser..."
    dnf install -y brave-browser
    log_success "Brave Browser installed"
}

setup_cifs_mount() {
    log "Setting up CIFS mounts..."

    read -p "Do you want to set up a CIFS/SMB network share? (y/n): " setup_cifs
    if [[ "$setup_cifs" != "y" && "$setup_cifs" != "Y" ]]; then
        log "Skipping CIFS mount setup"
        return
    fi

    read -p "Enter server IP address (e.g., 192.168.0.2): " SERVER_IP
    read -p "Enter share name (e.g., media): " SHARE_NAME
    read -p "Enter mount point (e.g., /mnt/media): " MOUNT_POINT

    SHARE="//$SERVER_IP/$SHARE_NAME"
    CREDENTIALS_FILE="/etc/cifs-credentials-$(echo $SHARE_NAME | tr -d '/')"
    FSTAB_ENTRY="$SHARE $MOUNT_POINT cifs credentials=$CREDENTIALS_FILE,vers=3.0,uid=$ACTUAL_USER,gid=$ACTUAL_USER,nofail 0 0"

    read -p "Enter CIFS username: " CIFS_USER
    read -s -p "Enter CIFS password: " CIFS_PASS
    echo ""

    echo -e "username=$CIFS_USER\npassword=$CIFS_PASS" > "$CREDENTIALS_FILE"
    chmod 600 "$CREDENTIALS_FILE"

    mkdir -p "$MOUNT_POINT"

    mount -t cifs "$SHARE" "$MOUNT_POINT" -o "credentials=$CREDENTIALS_FILE,vers=3.0,uid=$ACTUAL_USER,gid=$ACTUAL_USER,nofail"

    if ! grep -q "$SHARE" /etc/fstab; then
        echo "$FSTAB_ENTRY" >> /etc/fstab
    fi

    systemctl daemon-reload

    log_success "CIFS share mounted and set up for auto-mount on boot"
}

install_kickstart_nvim() {
    log "Setting up Kickstart Neovim..."

    if ! command -v git &>/dev/null; then
        log "Git not found, installing..."
        dnf install -y git
    fi

    NVIM_CONFIG_DIR="$ACTUAL_HOME/.config/nvim"

    if [ -d "$NVIM_CONFIG_DIR" ]; then
        BACKUP_DIR="$NVIM_CONFIG_DIR.backup.$(date +%Y%m%d%H%M%S)"
        log "Backing up existing Neovim config to $BACKUP_DIR"
        mv "$NVIM_CONFIG_DIR" "$BACKUP_DIR"
    fi

    rm -rf "$ACTUAL_HOME/.local/share/nvim" "$ACTUAL_HOME/.local/state/nvim" "$ACTUAL_HOME/.cache/nvim"

    log "Cloning Kickstart Neovim..."
    sudo -u $ACTUAL_USER git clone https://github.com/nvim-lua/kickstart.nvim.git "$NVIM_CONFIG_DIR"

    log_success "Kickstart Neovim configured successfully"
}

change_to_zsh() {
    log "Setting up Zsh..."

    if ! command -v zsh &>/dev/null; then
        log "Zsh not found, installing..."
        dnf install -y zsh
    fi

    ZSH_PATH=$(which zsh)
    if [ -z "$ZSH_PATH" ]; then
        log_error "Could not find zsh path. Aborting zsh setup."
        return
    fi

    log "Installing Oh My Zsh..."
    sudo -u $ACTUAL_USER sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended"

    log "Downloading custom .zshrc from GitHub..."
    if curl -fsSL https://raw.githubusercontent.com/linuxmunchies/.zshrc/main/.zshrc -o "$ACTUAL_HOME/.zshrc.tmp"; then
        if [ -f "$ACTUAL_HOME/.zshrc" ]; then
            mv "$ACTUAL_HOME/.zshrc" "$ACTUAL_HOME/.zshrc.backup.$(date +%Y%m%d%H%M%S)"
            log "Backed up existing .zshrc file"
        fi

        mv "$ACTUAL_HOME/.zshrc.tmp" "$ACTUAL_HOME/.zshrc"
        chown $ACTUAL_USER:$ACTUAL_USER "$ACTUAL_HOME/.zshrc"

        chsh -s "$ZSH_PATH" $ACTUAL_USER
        log_success "Zsh configured as default shell with custom .zshrc"
    else
        log_error "Failed to download custom .zshrc file."
    fi
}

cleanup() {
    log "Performing cleanup..."

    dnf clean packages

    flatpak uninstall --unused -y

    log_success "Cleanup completed"
}

generate_summary() {
    log "Generating setup summary..."

    echo -e "\n${GREEN}======================================${NC}"
    echo -e "       ${GREEN}Fedora Setup Complete!         ${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo "Hostname: $(hostname)"
    echo "Setup completed at: $(date)"
    echo "Log file: $LOG_FILE"
    echo -e "${GREEN}======================================${NC}\n"

    if command -v fastfetch &> /dev/null; then
        fastfetch
    fi
}

setup_intel_powercap() {
    log "Checking for Intel CPU and setting up power monitoring..."

    if grep -q "Intel" /proc/cpuinfo; then
        log "Intel CPU detected, configuring energy_uj permissions"

        ENERGY_FILE="/sys/class/powercap/intel-rapl:0/energy_uj"
        UDEV_RULE_FILE="/etc/udev/rules.d/99-intel-rapl.rules"

        if [ -f "$ENERGY_FILE" ]; then
            chmod o+r "$ENERGY_FILE"
            log_success "Applied temporary energy_uj permissions fix"

            cat > "$UDEV_RULE_FILE" << EOF
# Allow all users to read Intel RAPL energy_uj for monitoring tools
ACTION=="add", SUBSYSTEM=="powercap", KERNEL=="intel-rapl:0", ATTR{energy_uj}="*", RUN+="/bin/chmod o+r /sys/class/powercap/intel-rapl:0/energy_uj"
EOF

            udevadm control --reload-rules
            log_success "Created persistent udev rule for Intel power monitoring"
        else
            log_warning "Intel CPU detected but energy_uj file not found at expected location"
        fi
    else
        log "No Intel CPU detected, skipping energy_uj permissions setup"
    fi
}

# ----- Main Execution -----
main() {
    clear
    log "Starting Fedora setup script..."

    check_root
    check_fedora

    touch "$LOG_FILE"
    chown $ACTUAL_USER:$ACTUAL_USER "$LOG_FILE"

    setup_repositories
    update_system
    setup_snapshots
    optimize_system
    install_flatpak_support
    install_system_tools
    setup_virtualization
    setup_multimedia
    install_gaming
    setup_gaming_tweaks
    install_brave_browser
    install_flatpaks
    # Call twice to allow setting up two different network mounts
    setup_cifs_mount
    setup_cifs_mount
    mkdir_proton
    setup_gamedrive_mount
    setup_user_groups
    setup_intel_powercap
    install_nerd_fonts
    install_system_fonts
    install_kickstart_nvim
    change_to_zsh
    create_final_snapshot
    cleanup
    generate_summary

    log_success "Fedora setup completed successfully!"
    echo -e "\n${YELLOW}Please reboot your system to apply all changes.${NC}"
}

# Run the main function
main
