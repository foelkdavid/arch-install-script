# Archived! Just use archinstall!


# arch-installer
Shell Script that installs a minimal Archlinux System.

## usage:
on a booted installation media do the following:
- make sure you are connected to the internet
```bash
git clone https://github.com/foelkdavid/arch-installer
cd arch-installer
chmod +x install.sh
./install.sh
```

now the script will run you through the installation.

have fun!

### TODO:
write drives via UID into the fstab file.
using the /dev/... path can be unreliable if the system configuration gets modified.
