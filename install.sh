#!/bin/bash

# Adding colors for output:
red="\e[0;91m"
green="\e[0;92m"
blue="\e[0;94m"
bold="\e[1m"
reset="\e[0m"

# convenience functions:

fail() {
    echo -e "${red}[FAILED]${reset}"
}

failexit() {
    fail
    exit
}

ok() {
    echo -e "${green}[OK]${reset}"
}

# Functions to be used later:

# checks if command is run as root.
rootcheck() {
    [ $(id -u) -eq 0 ] && return 0 || return 1
}

# naive networkcheck
networkcheck() {
    ping -c 2 voidlinux.org > /dev/null && return 0 || return 1
}

# gets the used BOOTLOADER.
# 0 = uefi
# 1 = bios
getbootloader() {
    [ -d /sys/firmware/efi/efivars ] && BOOTLOADER=UEFI || BOOTLOADER=BIOS
}

# TODO: Fix Swap size
# calculates swapsize using a simple table
#     Amount of RAM installed in system 	Recommended swap space
# RAM ≤ 2GB :       swap = 2X RAM
# RAM = 2GB – 8GB : swap = RAM
# RAM > 8GB       : swap = 8GB
getswap() {
    RAMVAL=$(grep MemTotal /proc/meminfo | awk '{print $2}') && RAM=$(( $RAM + 500000 )) && RAM=$(( $RAM/1024000 ))
    RAM=$RAMVAL
    if [[ RAM -lt 2 ]]; then
        SWAP=$(($RAM*2))
        elif [[ RAM -lt 8 ]]; then
        SWAP=$RAM
        elif [[ RAM -gt 8 ]]; then
        SWAP=8
    fi
}

# Actual Installer Functions:

preparation() {
    echo -e "${bold}Step 1 -> prerequisites:${reset}"
    printf "Run as root? "; rootcheck && ok || failexit ; sleep 0.4
    printf "Checking Connection: "; networkcheck && ok || failexit ; sleep 0.4
    printf "Getting Bootloader: "; getbootloader && echo -e "${blue}[$BOOTLOADER]${reset}" || failexit ; sleep 0.4
    printf "Running Updates: ... " ; pacman -Sy --noconfirm > /dev/null && ok || failexit ; sleep 0.4
    printf "Installing Parted for 'partprobe': ... " ; pacman -S --noconfirm parted > /dev/null && ok || failexit ; sleep 1.2
    printf "\n"
}

# lets the user select the system drive
driveselect() {
    # shows drives over 1GiB to the User
    echo -e "Following disks are recommendet:"
    echo -e "${bold}"
    sfdisk -l | grep "GiB" &&
    echo -e "${reset}"
    
    # allows the user to select a DISK $DISK
    while true; do
        read -p "Please enter the path of the desired Disk for your new System: " DISK &&
        [ -b "$DISK" ] && printf $(ok)" ${blue}$DISK${reset}\n" && break ||  printf $(fail)" ${blue}$DISK${reset} is not a valid drive\n"
    done
    
    echo -e "${red}This will remove all existing partitions on "$DISK". ${reset}"
    while true; do
        read -p "Are you sure? [yes/no] " YN
        printf "drive selection: "
        case $YN in
            [yes]* ) ok && return 0;;
            [no]* ) fail && return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# creates filesystem
createfilesystem() {
    #creating efi, swap, root partition for UEFI systems; creating swap, root partition for BIOS systems
    if [ $BOOTLOADER = UEFI ]; then printf "o\nn\np\n \n \n+1G\nn\np\n \n \n+"$SWAP"G\nn\np\n \n \n \nw\n" | fdisk $DISK > /dev/null ; else printf "o\nn\np\n \n \n+"$SWAP"G\nn\np\n \n \n \nw\n" | fdisk $DISK > /dev/null; fi
    partprobe $DISK &&
    #getting paths of partitions
    PARTITION1=$(fdisk -l $DISK | grep $DISK | sed 1d | awk '{print $1}' | sed -n "1p") &&
    PARTITION2=$(fdisk -l $DISK | grep $DISK | sed 1d | awk '{print $1}' | sed -n "2p") &&
    if [ $BOOTLOADER = UEFI ]; then PARTITION3=$(fdisk -l $DISK | grep $DISK | sed 1d | awk '{print $1}' | sed -n "3p"); else echo "No third Partition needet."; fi
    
    #declaring partition paths as variables
    if [ $BOOTLOADER = UEFI ]; then
        EFIPART=$PARTITION1
        SWAPPART=$PARTITION2
        ROOTPART=$PARTITION3
    else
        EFIPART="NOT DEFINED"
        SWAPPART=$PARTITION1
        ROOTPART=$PARTITION2
    fi
    
    #filesystem creation
    #efi partition
    if [ $BOOTLOADER = UEFI ]; then mkfs.fat -F32 $EFIPART > /dev/null; fi
    
    
    #root partition
    mkfs.ext4 $ROOTPART > /dev/null &&
    
    #swap partition
    mkswap $SWAPPART > /dev/null
}

sysinstall() {
    pacstrap /mnt base linux linux-firmware networkmanager grub zsh man-db vim nano sudo neofetch &&
    # genfstab -U /mnt >> /mnt/etc/fstab &&
    sleep 1
arch-chroot /mnt /bin/bash -- << EOCHROOT

      echo "setting timezone:" &&
      ln -sf /usr/share/zoneinfo/Europe/Vienna /etc/localtime &&
      echo "done." &&

      echo "syncing system time:" &&
      hwclock --systohc &&
      echo "done." &&

      echo "appending locales to locale.gen:" &&
      echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen &&
      echo "generating locales:" &&
      locale-gen &&
      echo "setting system locale:" &&
      echo "LANG=en_US.UTF-8" >> /etc/locale.conf &&
      echo "done!" &&

      echo "enabling NetworkManager" &&
      systemctl enable NetworkManager &&


      echo "setting up sudo" &&
      echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers &&
      echo "%wheel ALL=(ALL) NOPASSWD: /sbin/poweroff, /sbin/reboot, /sbin/shutdown" >> /etc/sudoers &&
      echo "done." &&

      echo "locking root user" &&
      passwd -l root &&
      echo "done" &&
      sleep 2
EOCHROOT
    
}


configure() {
    # configure locales:
    clear
    echo -e "${bold}Step 4 -> configuration: [1/3]${reset}"
    while true; do
        read -p "Please enter a valid Keymap: " KMP &&
        chroot /mnt/ loadkeys $KMP && echo "KEYMAP="$KMP >> /mnt/etc/vconsole.conf && break ||  printf $(fail)" ${blue}$KMP${reset} is not a valid Keymap\n"
    done
    chroot /mnt/ locale-gen
    
    # configure users:
    clear
    echo -e "${bold}Step 4 -> configuration: [2/3]${reset}"
    echo -e "${blue}Keymap:$KMP${reset}"
    
    
    while true; do
        read -p "Please enter a valid Username: " USRNME &&
        chroot /mnt/ useradd -m $USRNME && break ||  printf $(fail)"\n"
    done
    while true; do
        chroot /mnt/ passwd $USRNME && break ||  printf $(fail)"\n"
    done
    
    chroot /mnt/ usermod -a -G wheel $USRNME &&
    #echo "locking root user" &&
    chroot /mnt/ passwd -l root &&
    #echo "done" &&
    echo "%wheel ALL=(ALL) ALL" >> /mnt/etc/sudoers &&
    echo "%wheel ALL=(ALL) NOPASSWD: /sbin/poweroff, /sbin/reboot, /sbin/shutdown" >> /mnt/etc/sudoers &&
    
    # setting
    clear
    echo -e "${bold}Step 4 -> configuration: [3/3]${reset}"
    echo -e "${blue}Keymap:$KMP${reset}"
    echo -e "${blue}Username:$USRNME${reset}"
    read -p "Please enter a valid Hostname : " CHN &&
    echo $CHN > /mnt/etc/hostname
    
    clear
    echo -e "${green}Finished Configuration:${reset}"
    echo -e "${blue}-----------------------${reset}"
    echo -e "${blue}Keymap:$KMP${reset}"
    echo -e "${blue}Username:$USRNME${reset}"
    echo -e "${blue}Hostname:$CHN${reset}"
    echo -e "${blue}-----------------------${reset}"
    for i in {0..22}
    do
        printf "."
        sleep 0.1
    done
    clear
}


finalize() {

    # installing microcode 
    VENDOR=$(grep vendor_id /proc/cpuinfo | head -n 1 | awk '{print $3}')
    if [ $VENDOR = AuthenticAMD ]; then
        pacstrap /mnt amd-ucode
        elif [ $VENDOR = GenuineIntel ]; then
        pacstrap /mnt intel-ucode
    fi

 



    # setting up GRUB
    if [ $BOOTLOADER = UEFI ]; then
        echo "setting up grub for UEFI system:" &&
        pacstrap /mnt efibootmgr
        arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB &&
        arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg &&
        echo "done";
    else
        echo "setting up grub for BIOS system:" &&
        arch-chroot /mnt grub-install --target=i386-pc $DISK &&
        arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg &&
        echo "done";
    fi
    
    
    
    clear

}


# STEP 1 -> PREREQUISITES
echo -e "${bold}Starting Installer:${reset}" ; sleep 0.4
preparation



# STEP 2 -> DRIVES
clear
echo -e "${bold}Step 2 -> drives:${reset}" ; sleep 0.4
echo -e "${bold}Partitioning:${reset}"
driveselect || exit ; sleep 0.4
echo -e "${bold}Creating Filesystem:${reset}"
getswap ; echo -e "Swapsize: ${blue}[$SWAP GB]${reset}" ; sleep 1
createfilesystem && ok || failexit ; sleep 0.4
echo -e "${bold}Mounting Filesystems:${reset}"
mount $ROOTPART /mnt && swapon $SWAPPART &&

#efi
if [ $BOOTLOADER = UEFI ]; then 
    mkfs.fat -F32 $EFIPART; 
    mkdir /mnt/efi
    mount $EFIPART /mnt/efi;
fi

### -----------------------------------------------------------

# STEP 3 -> INSTALLATION
echo -e "\n${bold}Step 3 -> installation:${reset}" ; sleep 0.4
echo -e "\n${bold}THIS CAN TAKE A WHILE...${reset}" ; sleep 0.4
sysinstall

# STEP 4 -> CONFIGURATION
configure

# configuring fstab
echo $SWAPPART " swap swap rw,noatime,discard 0 0" >> /mnt/etc/fstab
echo $ROOTPART " / ext4 noatime 0 1" >> /mnt/etc/fstab
if [ $BOOTLOADER = UEFI ]; then echo $EFIPART " /boot ext4 noauto,noatime 0 2" >> /mnt/etc/fstab ; fi
echo "tmpfs /tmp tmpfs defaults,nosuid,nodev 0 0" >> /mnt/etc/fstab


# STEP5 -> FINALIZE
echo -e "\n${bold}Step 5 -> finalize:${reset}" ; sleep 0.4
finalize

# REBOOT
echo -e "${green}INSTALLATION COMPLETED${reset}" ; sleep 0.4
echo -e "${bold}enjoy your new system :)${reset}"
printf "\n"
echo "rebooting... see you soon :)" ; sleep 1
reboot now