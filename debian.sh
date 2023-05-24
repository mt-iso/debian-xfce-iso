#!/bin/bash
set -e
#### Check root
if [[ ! $UID -eq 0 ]] ; then
    echo -e "\033[31;1mYou must be root!\033[:0m"
    exit 1
fi
#### Remove all environmental variable
for e in $(env | sed "s/=.*//g") ; do
    unset "$e" &>/dev/null
done

#### Set environmental variables
export PATH=/bin:/usr/bin:/sbin:/usr/sbin
export LANG=C
export SHELL=/bin/bash
export TERM=linux
export DEBIAN_FRONTEND=noninteractive

#### Install dependencies
if which apt &>/dev/null && [[ -d /var/lib/dpkg && -d /etc/apt ]] ; then
    apt-get update
    apt-get install curl mtools squashfs-tools grub-pc-bin grub-efi-amd64-bin grub2-common grub-common grub-efi-ia32-bin xorriso debootstrap binutils -y
fi

set -ex
#### Chroot create
mkdir chroot || true

##### For debian
debootstrap --variant=minbase --no-check-gpg --arch=amd64 testing chroot https://deb.devuan.org/devuan
echo "deb https://deb.devuan.org/devuan testing main contrib non-free non-free-firmware" > chroot/etc/apt/sources.list


#### Fix apt & bind
for i in dev dev/pts proc sys; do mount -o bind /$i chroot/$i; done
chroot chroot apt-get install gnupg -y


#### grub packages
chroot chroot apt-get install grub-pc-bin grub-efi-ia32-bin grub-efi -y

#### live packages for debian/devuan
chroot chroot apt-get install live-config live-boot -y
echo "DISABLE_DM_VERITY=true" >> chroot/etc/live/boot.conf


#### firmware

# https://github.com/Whonix/whonix-legacy/blob/master/debian/whonix-legacy.preinst#L49
#echo b43-fwcutter b43-fwcutter/cut_firmware boolean true | debconf-set-selections
#echo firmware-ipw2x00 firmware-ipw2x00/license/accepted boolean true | debconf-set-selections
#echo firmware-iwlwifi firmware-iwlwifi/license/accepted boolean true | debconf-set-selections
#echo firmware-ralink firmware-ralink/license/accepted boolean true | debconf-set-selections



#### stock kernel 
chroot chroot apt-get install linux-image-amd64 -y
#chroot chroot apt-get install linux-headers-amd64 -y

#### xorg & desktop pkgs
chroot chroot apt-get install xserver-xorg xinit -y

#### Install xfce
### Xfce ve gerekli araçları kuralım
chroot chroot apt-get install xfce4 xfce4-terminal -y
#xfce4-whiskermenu-plugin thunar thunar-archive-plugin xfce4-screenshooter mousepad ristretto -y
#chroot chroot apt-get install xfce4-datetime-plugin xfce4-timer-plugin xfce4-mount-plugin xfce4-taskmanager xfce4-battery-plugin xfce4-power-manager -y
#chroot chroot apt-get install network-manager-gnome gvfs-backends blueman -y

### İsteğe bağlı paketleri kuralım
#chroot chroot apt-get install inxi gnome-calculator file-roller synaptic -y


### Yazıcı tarayıcı ve bluetooth paketlerini kuralım (isteğe bağlı)
#chroot chroot apt-get install printer-driver-all system-config-printer simple-scan -y

#chroot chroot wget https://cdimage.debian.org/cdimage/firmware/testing/current/firmware.zip
chroot chroot apt-get install lightdm lightdm-gtk-greeter 
#network-manager-gnome pulseaudio -y
chroot chroot apt-get remove xterm -y

#### usbcore stuff (for initramfs)
echo "#!/bin/sh" > chroot/etc/initramfs-tools/scripts/init-top/usbcore.sh
echo "echo Y > /sys/module/usbcore/parameters/old_scheme_first" >> chroot/etc/initramfs-tools/scripts/init-top/usbcore.sh
chmod +x chroot/etc/initramfs-tools/scripts/init-top/usbcore.sh
chroot chroot update-initramfs -u -k all

#### Clear logs and history
chroot chroot apt-get clean
rm -f chroot/root/.bash_history
rm -rf chroot/var/lib/apt/lists/*
find chroot/var/log/ -type f | xargs rm -f

### create iso template
mkdir -p debian/boot || true
mkdir -p debian/live || true
ln -s live debian/casper || true

#### Copy kernel and initramfs (Debian/Devuan)
cp -pf chroot/boot/initrd.img-* debian/boot/initrd.img
cp -pf chroot/boot/vmlinuz-* debian/boot/vmlinuz

#### Remove initrd.img for minimize iso size (optional)
rm -rf chroot/boot/initrd.img-*

#### Create squashfs
for dir in dev dev/pts proc sys ; do
    while umount -lf -R chroot/$dir 2>/dev/null ; do true; done
done
# For better installation time
#mksquashfs chroot filesystem.squashfs -comp gzip -wildcards
# For better compress ratio
mksquashfs chroot filesystem.squashfs -comp xz -wildcards

### move squashfs file
mv filesystem.squashfs debian/live/filesystem.squashfs

#### Write grub.cfg
mkdir -p debian/boot/grub/
echo 'menuentry "Start Devuan GNU/Linux 64-bit" --class debian {' > debian/boot/grub/grub.cfg
echo '    linux /boot/vmlinuz boot=live live-config quiet --' >> debian/boot/grub/grub.cfg
echo '    initrd /boot/initrd.img' >> debian/boot/grub/grub.cfg
echo '}' >> debian/boot/grub/grub.cfg

#### Create iso
grub-mkrescue debian -o devuan-x86.iso
