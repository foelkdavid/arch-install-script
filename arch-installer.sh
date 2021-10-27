#!/bin/sh
#Checks if script is run as root
  ID=$(id -u)
  if [ "$ID" -ne "0" ];
  then
    echo "Command needs to be run as root."
    return 1
    exit
  fi

###################################
######### 1. PARTITIONING #########
###################################

##### NOTE: USED DRIVE MUST NOT HAVE MOUNTED PARTITIONS #####


  echo -e "\033[0;32m$(tput bold)---- Starting Partitioning ----$(tput sgr0)" &&
  sleep 1

  #displays drives over 1GiB to the User
    echo "Starting disk Partitioning"
    echo -e "Following disks are recommendet:"
    echo -e "\033[0;34m$(tput bold)"
    sudo sfdisk -l | grep "GiB" &&
    echo -e "$(tput sgr0)"

  #takes user input and removes existing partitions
    read -p "Please enter the path of the desired Disk for your new System: " DSK &&
    while true; do
        read -p "\033[0;32m$(tput bold)This will remove all existing partitions on "$DSK". Are you sure? [Yy/Nn]$(tput sgr0)" YN
        case $YN in
            [Yy]* ) dd if=/dev/zero of=$DSK bs=512 count=1 conv=notrunc; break; echo"done";;
            [Nn]* )  echo "you selected no"; exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done

    echo "REMOVING EXISTING FILESYSTEMS" &&
    sleep 5 &&

  #checks and prints used bootmode.
    if ls /sys/firmware/efi/efivars ; then
      BOOTMODE=UEFI
    else
      BOOTMODE=BIOS
    fi
    echo bootmode detected: $BOOTMODE &&

  # #creating efi partition if system is booting in UEFI mode
  #   if [ $BOOTMODE = UEFI ]; then printf "n\np\n \n \n+1G\nw\n" | fdisk $DSK; else echo "no efi partition needet, "; fi
  #   echo "creating SWAP space"

  #creating swap partition
    #get RAM size
    RAM=$(free -g | grep Mem: | awk '{print $2}') &&

    #setting swapsize variable to RAMsize+4G
    SWAPSIZE=$(expr $RAM + 4) &&
    echo "SWAPSIZE = "  $SWAPSIZE &&

  #   #creating swap partition
  #   printf "n\np\n \n \n+"$SWAPSIZE"G\nw\n" | fdisk $DSK &&

  # #creating root partition
  # printf "n\np\n \n \n \nw\n" | fdisk $DSK  &&

 if [ $BOOTMODE = UEFI ]; then printf "n\np\n \n \n+1G\nn\np\n \n \n+"$SWAPSIZE"G\nn\np\n \n \n \nw\n" | fdisk $DSK; else printf "n\np\n \n \n+"$SWAPSIZE"G\nn\np\n \n \n \nw\n" | fdisk $DSK; fi





  #getting paths of partitions
  PARTITION1=$(fdisk -l $DSK | grep $DSK | sed 1d | awk '{print $1}' | sed -n "1p") &&
  partprobe $DSK &&
  sleep 2
  PARTITION2=$(fdisk -l $DSK | grep $DSK | sed 1d | awk '{print $1}' | sed -n "2p") &&
  partprobe $DSK &&
  if [ $BOOTMODE = UEFI ]; then PARTITION3=$(fdisk -l $DSK | grep $DSK | sed 1d | awk '{print $3}' | sed -n "3p"); else echo "No third Partition needet."; fi
  sleep 2 &&
  partprobe $DSK &&

  #declaring partition paths as variables
  if [ $BOOTMODE = UEFI ]; then
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
    if [ $BOOTMODE = UEFI ]; then mkfs.fat -F32 $EFIPART; fi

    #swap partition
    mkswap $SWAPPART &&

    #root partition
    mkfs.ext4 $ROOTPART &&

  #filesystem mounting / enabling swapspace
    #root partition
    mount $ROOTPART /mnt &&

    #swap partition
    swapon $SWAPPART &&

    #efi
    if [ $BOOTMODE = UEFI ]; then
      mkdir /mnt/efi
      mount $EFIPART /mnt/efi;
    fi

  echo -e "\033[0;32m$(tput bold)---- Finished Partitioning ----$(tput sgr0)" &&
  printf "\n\n"
  sleep 1

# ##################################
# ######### 2. PREPARATION #########
# ##################################

  echo -e "\033[0;32m$(tput bold)---- Starting Preparation ----$(tput sgr0)" &&
  sleep 1

#   echo "installing required packages to new system"
#   pacstrap /mnt base linux linux-firmware networkmanager grub zsh man-db &&

# #  echo "installing extended packages to new system"
# #  pacstrap /mnt neofetch 

#   echo "generating fstab file:" &&
#   fstabgen -U /mnt >> /mnt/etc/fstab &&

#   echo -e "\033[0;32m$(tput bold)---- Finished Preparation ----$(tput sgr0)" &&
#   printf "\n\n"
# #################################
# ######## 3. INSTALLATION ########
# #################################
#  echo -e "\033[0;32m$(tput bold)---- Starting Installation ----$(tput sgr0)" &&
#   sleep 1

#   chroot-script () {
#       echo "setting timezone:" &&
#       ln -sf /usr/share/zoneinfo/Europe/Vienna /etc/localtime &&
#       echo "done." &&

#       echo "syncing system time:" &&
#       hwclock --systohc &&
#       echo "done." &&

#       echo "appending locales to locale.gen:" &&
#       echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen &&
#       echo "generating locales:" &&
#       locale-gen &&
#       echo "setting system locale:" &&
#       echo "LANG=en_US.UTF-8" >> /etc/locale.conf &&
#       echo "done!" &&

#       echo "setting keymap" &&
#       echo "KEYMAP=de-latin1" >> /etc/vconsole.conf &&
#       echo "done" &&

#       echo "setting hostname:" &&
#       read -p "Please enter a valid Hostname : " CHN &&
#       echo $CHN >> /etc/hostname &&
#       echo "127.0.0.1 localhost" >> /etc/hosts &&
#       echo "::1" >> /etc/hosts &&
#       echo "127.0.1.1 $CHN.localdomain $CHN" >> /etc/hosts &&
#       echo "done!" &&

#       echo "installing microcode" &&

#       read -p "Please enter your CPU manufacturer:  [ amd | intel ]" SYSBRND && 
#       pacman -S $SYSBRND-ucode &&
#       echo "done!" &&

#       echo "enabling NetworkManager" &&
#       systemctl enable NetworkManager &&

#       # echo "filling /etc/skel directory" &&
#       # rm -rf /etc/skel/* &&
#       # cd /tmp &&
#       # git clone https://github.com/foelkdavid/instartix-dotfiles &&
#       # cd /tmp/instartix-dotfiles/ &&
#       # cp -rf .config .z* /etc/skel &&

#       echo "creating new User" &&
#       read -p "Please enter a valid username: " USRNME &&
#       useradd -s /bin/zsh -m $USRNME &&
#       passwd $USRNME &&
#       usermod -a -G wheel $USRNME &&

#       echo "setting up sudo" &&
#       echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers &&
#       echo "%wheel ALL=(ALL) NOPASSWD: /sbin/poweroff, /sbin/reboot, /sbin/shutdown" >> /etc/sudoers &&
#       echo "done." &&

#       echo "locking root user" &&
#       passwd -l root &&
#       echo "done" &&
#   }

#   grub-uefi-script () {
#     echo "setting up grub for UEFI system:" &&
#     pacman -S efibootmgr
#     read -p "Please enter path for efi mountpoint: " EFIMP &&
#     grub-install --target=x86_64-efi --efi-directory=$EFIMP --bootloader-id=GRUB &&
#     grub-mkconfig -o /boot/grub/grub.cfg &&
#     echo "done"
# }

#   grub-bios-script () {
#     echo "setting up grub for BIOS system:" &&
#     read -p "Please enter path for filesystem: " FSPI &&
#     grub-install --target=i386-pc $FSPI &&
#     grub-mkconfig -o /boot/grub/grub.cfg &&
#     echo "done"
# }

#   arch-chroot /mnt chroot-script &&
#   if [ $BOOTMODE = UEFI ]; then grub-uefi-script; else grub-bios-script; fi

# echo -e "\033[0;32m$(tput bold)---- Finished Installation ----$(tput sgr0)" &&
#   printf "\n\n"
# echo -e "\033[0;32m$(tput bold)---- Enjoy your new System :) ----$(tput sgr0)" 
