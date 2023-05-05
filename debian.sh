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
#    # For 17g package build
#    apt-get install git devscripts equivs -y
fi

set -ex
#### Chroot create
mkdir chroot || true


### Chroot oluşturmak için
mkdir kaynak
chown root kaynak

### pardus için
debootstrap --arch=amd64 yirmibir kaynak http://depo.pardus.org.tr/pardus

### bind bağı için
for i in dev dev/pts proc sys; do mount -o bind /$i kaynak/$i; done

### depo eklemek için
echo '### The Official Pardus Package Repositories ###' > kaynak/etc/apt/sources.list
echo 'deb http://depo.pardus.org.tr/pardus yirmibir main contrib non-free' >> kaynak/etc/apt/sources.list
echo '# deb-src http://depo.pardus.org.tr/pardus yirmibir main contrib non-free' >> kaynak/etc/apt/sources.list
echo 'deb http://depo.pardus.org.tr/guvenlik yirmibir main contrib non-free' >> kaynak/etc/apt/sources.list
echo '# deb-src http://depo.pardus.org.tr/guvenlik yirmibir main contrib non-free' >> kaynak/etc/apt/sources.list
echo 'deb http://depo.pardus.org.tr/backports yirmibir-backports main contrib non-free' > kaynak/etc/apt/sources.list.d/yirmibir-backports.list
chroot kaynak apt update

### kernel paketini kuralım (Backpots istemiyorsanız -t yirmibir-backports yazısını siliniz!)
chroot kaynak apt install -t yirmibir-backports linux-image-amd64 -y

### grub paketleri için
chroot kaynak apt install grub-pc-bin grub-efi-ia32-bin grub-efi -y

### live paketleri için
chroot kaynak apt install live-config live-boot -y 

### init paketleri için
chroot kaynak apt install xorg xinit -y

### giriş ekranı kuralım
chroot kaynak apt install lightdm -y

### firmware paketleri için (Burada kendi donanımınıza göre tercih yapabilirsiniz!) 
chroot kaynak apt install firmware-linux -y
chroot kaynak apt install firmware-linux-free -y
chroot kaynak apt install firmware-linux-nonfree -y
chroot kaynak apt install firmware-misc-nonfree -y
chroot kaynak apt install firmware-amd-graphics -y
chroot kaynak apt install firmware-realtek -y
chroot kaynak apt install bluez-firmware -y
#chroot kaynak apt install hdmi2usb-fx2-firmware -y

### benim laptopda bunlar fazlalık! :)
#chroot kaynak apt-get install atmel-firmware -y
#chroot kaynak apt-get install dahdi-firmware-nonfree -y
#chroot kaynak apt-get install firmware-ath9k-htc -y
#chroot kaynak apt-get install firmware-atheros -y
#chroot kaynak apt-get install firmware-b43-installer -y
#chroot kaynak apt-get install firmware-b43legacy-installer -y
#chroot kaynak apt-get install firmware-bnx2 -y
#chroot kaynak apt-get install firmware-bnx2x -y
#chroot kaynak apt-get install firmware-brcm80211 -y
#chroot kaynak apt-get install firmware-cavium -y
#chroot kaynak apt-get install firmware-intel-sound -y
#chroot kaynak apt-get install firmware-intelwimax -y
#chroot kaynak apt-get install firmware-ipw2x00 -y
#chroot kaynak apt-get install firmware-ivtv -y
#chroot kaynak apt-get install firmware-iwlwifi -y
#chroot kaynak apt-get install firmware-libertas -y
#chroot kaynak apt-get install firmware-myricom -y
#chroot kaynak apt-get install firmware-netronome -y
#chroot kaynak apt-get install firmware-netxen -y
#chroot kaynak apt-get install firmware-qcom-soc -y
#chroot kaynak apt-get install firmware-qlogic -y
#chroot kaynak apt-get install firmware-samsung -y
#chroot kaynak apt-get install firmware-siano -y
#chroot kaynak apt-get install firmware-sof-signed -y
#chroot kaynak apt-get install firmware-ti-connectivity -y
#chroot kaynak apt-get install firmware-zd1211 -y


### Xfce ve gerekli araçları kuralım
chroot kaynak apt install xfce4 xfce4-terminal xfce4-whiskermenu-plugin thunar thunar-archive-plugin xfce4-screenshooter mousepad ristretto -y
chroot kaynak apt install xfce4-datetime-plugin xfce4-timer-plugin xfce4-mount-plugin xfce4-taskmanager xfce4-battery-plugin xfce4-power-manager -y
chroot kaynak apt install network-manager-gnome gvfs-backends blueman qmplay2 -y

### İsteğe bağlı paketleri kuralım
chroot kaynak apt install inxi gnome-calculator file-roller synaptic librewolf -y

### Pardus paketleri kuralım 
chroot kaynak apt install pardus-xfce-settings pardus-locales pardus-software -y
chroot kaynak apt install pardus-package-installer pardus-installer pardus-about -y
chroot kaynak apt install pardus-dolunay-grub-theme pardus-gtk-theme pardus-icon-theme -y

### Yazıcı tarayıcı ve bluetooth paketlerini kuralım (isteğe bağlı)
chroot kaynak apt install printer-driver-all system-config-printer simple-scan -y


### zorunlu kurulu gelen paketleri silelim (isteğe bağlı)
chroot kaynak apt remove xterm termit xarchiver icedtea-netx -y

### Zorunlu değil ama grub güncelleyelim
chroot kaynak update-grub
chroot kaynak apt upgrade -y

umount -lf -R kaynak/* 2>/dev/null

### temizlik işlemleri
chroot kaynak apt autoremove
chroot kaynak apt clean
rm -f kaynak/root/.bash_history
rm -rf kaynak/var/lib/apt/lists/*
find kaynak/var/log/ -type f | xargs rm -f

### isowork filesystem.squashfs oluşturmak için
mkdir isowork
mksquashfs kaynak filesystem.squashfs -comp gzip -wildcards
mkdir -p isowork/live
mv filesystem.squashfs isowork/live/filesystem.squashfs

cp -pf kaynak/boot/initrd.img* isowork/live/initrd.img
cp -pf kaynak/boot/vmlinuz* isowork/live/vmlinuz

### grub işlemleri 
mkdir -p isowork/boot/grub/
echo 'insmod all_video' > isowork/boot/grub/grub.cfg
echo 'menuentry "Start PARDUS Backports Unofficial 64-bit" --class debian {' >> isowork/boot/grub/grub.cfg
echo '    linux /live/vmlinuz boot=live live-config live-media-path=/live --' >> isowork/boot/grub/grub.cfg
echo '    initrd /live/initrd.img' >> isowork/boot/grub/grub.cfg
echo '}' >> isowork/boot/grub/grub.cfg

echo "ISO oluşturuluyor.."
grub-mkrescue isowork -o pardus-xfce-live-$(date +%x).iso
