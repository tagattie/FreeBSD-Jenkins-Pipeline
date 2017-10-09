#! /bin/sh -xe

# Build USB stick image for Carambola 2 (mips)

export  LANG=C
export  PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin

SUDO_COMMAND="sudo"

# Comman-line format:
# BuildImage-CARAMBOLA2.sh buildName destDir imageDir hostname branchname archname confname
BUILDNAME=${1}
DESTDIR=${2}
IMAGEDIR=${3}
HOSTNAME=${4}
BRANCHNAME=${5}
ARCHNAME=${6}
CONFNAME=${7}

WORKSPACE="$(pwd)"
WORKDIRBASE="${WORKSPACE}/work"
WORKDIR="${WORKDIRBASE}/${BUILDNAME}/${HOSTNAME}"
IMGWORKDIR="${WORKDIRBASE}/${BUILDNAME}/image"
IMAGEFILE="FreeBSD-${BRANCHNAME}-${ARCHNAME}-${HOSTNAME}-${BUILDNAME}.img"

# KiB=1024
# MiB=$((${KiB}*1024))
# GiB=$((${MiB}*1024))
# FreeBSD kernel firmware
UBOOTARCH="mips"
UBOOTOS="linux"
UBOOTIMGTYPE="kernel"
UBOOTIMGCOMP="lzma"
UBOOTKERNLOADADDR="0x80050000"
UBOOTKERNENTRYPOINT="0x80050100"	# will be overwritten with actual value
UBOOTIMGNAME="FreeBSD"
UBOOTIMGDATA="kernel.lzma"
UBOOTIMGFILE="kernel-${BRANCHNAME}-${ARCHNAME}-${HOSTNAME}-${BUILDNAME}.lzma.uImage"
# FreeBSD partition
FBPARTFSENDIAN="big"
FBPARTFSLABEL="rootfs"
FBPARTFSMINFREE=1024
FSIMAGEFILE="${FBPARTFSLABEL}-${BRANCHNAME}-${ARCHNAME}-${HOSTNAME}-${BUILDNAME}.img"

# Upper bound of image size is 0xfbb000 (16494592) bytes

FSOWNER="root"
FSGROUP="wheel"

mkdir -p "${WORKDIR}"
mkdir -p "${IMGWORKDIR}"

# Create directories
DIRS="/bin /boot /c /dev /etc /lib /libexec /media /mnt /net /proc /rescue \
/root /sbin /tmp /usr /var"
DIRS="${DIRS} /boot/kernel /c/etc /libexec/resolvconf /usr/sbin /usr/bin \
/usr/libexec /usr/lib /usr/share"
DIRS="${DIRS} /c/etc/cfg /c/etc/pam.d /c/etc/rc.d /usr/share/misc \
/usr/share/tabset"
for i in ${DIRS}; do
    "${SUDO_COMMAND}" install -d \
        -o "${FSOWNER}" -g "${FSGROUP}" -m 755 \
        "${WORKDIR}/${i}"
done

# Populate /sbin, /usr/sbin directory
SBINDIR="/sbin"
SBINFILES="dmesg etherswitchcfg fsck_ffs ifconfig init ipfw kldload kldstat \
kldunload mdconfig mount mount_mfs mount_msdosfs newfs ping reboot \
resolvconf route sysctl umount"

echo -n "Populating ${SBINDIR} directory... "
for i in ${SBINFILES}; do
    "${SUDO_COMMAND}" install -c \
        -o "${FSOWNER}" -g "${FSGROUP}" -m 555 \
        "${DESTDIR}/${SBINDIR}/${i}" "${WORKDIR}/${SBINDIR}/${i}"
done
echo "Done."

USRSBINDIR="/usr/sbin"
USRSBINFILES="arp chown cron devinfo gpioctl hostapd hostapd_cli inetd \
ntpdate pciconf pmccontrol pmcstat pwd_mkdb sshd syslogd tcpdump usbconfig \
wlandebug wpa_cli wpa_supplicant"

echo -n "Populating ${USRSBINDIR} directory... "
for i in ${USRSBINFILES}; do
    "${SUDO_COMMAND}" install -c \
        -o "${FSOWNER}" -g "${FSGROUP}" -m 555 \
        "${DESTDIR}/${USRSBINDIR}/${i}" "${WORKDIR}/${USRSBINDIR}/${i}"
done
echo "Done."


# Populate /bin, /usr/bin directory
BINDIR="/bin"
BINFILES="cat csh chmod cp date dd df expr hostname kenv ln ls mkdir mv ps \
rm sh sleep"
OVERLAYBINFILES="cfg_load cfg_save"

echo -n "Populating ${BINDIR} directory... "
for i in ${BINFILES}; do
    "${SUDO_COMMAND}" install -c \
        -o "${FSOWNER}" -g "${FSGROUP}" -m 555 \
        "${DESTDIR}/${BINDIR}/${i}" "${WORKDIR}/${BINDIR}/${i}"
done
for i in ${OVERLAYBINFILES}; do
    "${SUDO_COMMAND}" install -c \
        -o "${FSOWNER}" -g "${FSGROUP}" -m 555 \
        "${WORKSPACE}/overlays/CARAMBOLA2/${BINDIR}/${i}" \
        "${WORKDIR}/${BINDIR}/${i}"
done
(cd "${WORKDIR}/${BINDIR}" &&
     "${SUDO_COMMAND}" ln -f csh tcsh)
echo "Done."

USRBINDIR="/usr/bin"
USRBIN555FILES="cap_mkdb clear cmp cpio ee false grep gzip head hexdump \
logger more netstat reset ssh systat tail tar telnet touch tput true uname \
uptime vmstat"
USRBIN4555FILES="login passwd su"

echo -n "Populating ${USRBINDIR} directory... "
for i in ${USRBIN555FILES}; do
    "${SUDO_COMMAND}" install -c \
        -o "${FSOWNER}" -g "${FSGROUP}" -m 555 \
        "${DESTDIR}/${USRBINDIR}/${i}" "${WORKDIR}/${USRBINDIR}/${i}"
done
for i in ${USRBIN4555FILES}; do
    "${SUDO_COMMAND}" install -c \
        -o "${FSOWNER}" -g "${FSGROUP}" -m 4755 \
        "${DESTDIR}/${USRBINDIR}/${i}" "${WORKDIR}/${USRBINDIR}/${i}"
done
(cd "${WORKDIR}/${USRBINDIR}" &&
     "${SUDO_COMMAND}" ln -f more less && \
     "${SUDO_COMMAND}" ln -f gzip gunzip)
echo "Done."


# Populate /libexec, /usr/libexec directory
LIBEXECDIR="/libexec"
LIBEXEC555FILES="ld-elf.so.1"
LIBEXEC444FILES="resolvconf/libc"

echo -n "Populating ${LIBEXECDIR} directory... "
for i in ${LIBEXEC555FILES}; do
    "${SUDO_COMMAND}" install -c \
        -o "${FSOWNER}" -g "${FSGROUP}" -m 555 \
        "${DESTDIR}/${LIBEXECDIR}/${i}" "${WORKDIR}/${LIBEXECDIR}/${i}"
done
for i in ${LIBEXEC444FILES}; do
    "${SUDO_COMMAND}" install -c \
        -o "${FSOWNER}" -g "${FSGROUP}" -m 444 \
        "${DESTDIR}/${LIBEXECDIR}/${i}" "${WORKDIR}/${LIBEXECDIR}/${i}"
done
echo "Done."

USRLIBEXECDIR="/usr/libexec"
USRLIBEXECFILES="getty"

echo -n "Populating ${USRLIBEXECDIR} directory... "
for i in ${USRLIBEXECFILES}; do
    "${SUDO_COMMAND}" install -c \
        -o "${FSOWNER}" -g "${FSGROUP}" -m 555 \
        "${DESTDIR}/${USRLIBEXECDIR}/${i}" "${WORKDIR}/${USRLIBEXECDIR}/${i}"
done
echo "Done."


# Populate /lib, /usr/lib directory
LIBDIR="/lib"
LIBFILES="lib80211.so.1 libbsdxml.so.4 libc.so.7 libcrypt.so.5 \
libcrypto.so.8 libdevstat.so.7 libedit.so.7 libelf.so.2 libgcc_s.so.1 \
libgeom.so.5 libipsec.so.4 libjail.so.1 libkiconv.so.4 libkvm.so.7 \
libm.so.5 libmd.so.6 libncurses.so.8 libncursesw.so.8 libnv.so.0 \
libpcap.so.8 libsbuf.so.6 libthr.so.3 libufs.so.6 libutil.so.9 libxo.so.0 \
libz.so.6"

echo -n "Populating ${LIBDIR} directory... "
for i in ${LIBFILES}; do
    "${SUDO_COMMAND}" install -c \
        -o "${FSOWNER}" -g "${FSGROUP}" -m 444 \
        "${DESTDIR}/${LIBDIR}/${i}" "${WORKDIR}/${LIBDIR}/${i}"
done
echo "Done."

USRLIBDIR="/usr/lib"
USRLIBFILES="libarchive.so.6 libbsm.so.3 libbz2.so.4 libdevinfo.so.6 \
libgnuregex.so.5 libgpio.so.0 liblzma.so.5 libmemstat.so.3 libmp.so.7 \
libnetgraph.so.4 libpam.so.6 libpmc.so.5 libprivatebsdstat.so.1 libssl.so.8 \
libusb.so.3 libwrap.so.6 pam_deny.so.6 pam_group.so.6 pam_lastlog.so.6 \
pam_login_access.so.6 pam_nologin.so.6 pam_permit.so.6 pam_rhosts.so.6 \
pam_rootok.so.6 pam_securetty.so.6 pam_self.so.6 pam_ssh.so.6 pam_unix.so.6"

echo -n "Populating ${USRLIBDIR} directory... "
for i in ${USRLIBFILES}; do
    "${SUDO_COMMAND}" install -c \
        -o "${FSOWNER}" -g "${FSGROUP}" -m 444 \
        "${DESTDIR}/${USRLIBDIR}/${i}" "${WORKDIR}/${USRLIBDIR}/${i}"
done
(cd ${WORKDIR}/${USRLIBDIR} &&
    for i in ${USRLIBFILES}; do
        l=$(echo ${i}|sed -e 's/\.[0-9]$//')
        "${SUDO_COMMAND}" ln -sf ${i} ${l}
    done)
echo "Done."


# Populate /usr/share directory
USRSHAREDIR="/usr/share"
USRSHAREFILES="misc/termcap tabset/vt100"

echo -n "Populating ${USRSHAREDIR} directory... "
for i in ${USRSHAREFILES}; do
    "${SUDO_COMMAND}" install -c \
        -o "${FSOWNER}" -g "${FSGROUP}" -m 755 \
        "${DESTDIR}/${USRSHAREDIR}/${i}" "${WORKDIR}/${USRSHAREDIR}/${i}"
done
echo "Done."


# Populate /boot/kernel directory
KERNDIR="/boot/kernel"
KERNFILES="if_bridge if_gif if_gre if_vlan bridgestp \
if_otus otusfw_init otusfw_main \
urtwn-rtl8188eufw urtwn-rtl8192cfwT urtwn-rtl8192cfwU \
ipfw hwpmc \
wlan wlan_acl wlan_amrr wlan_ccmp wlan_rssadapt wlan_tkip wlan_wep wlan_xauth \
usb usb_quirk usb_template umass ehci ar71xx_ehci"

echo -n "Populating ${KERNDIR} directory... "
for i in ${KERNFILES}; do
    "${SUDO_COMMAND}" install -c \
        -o "${FSOWNER}" -g "${FSGROUP}" -m 555 \
        "${DESTDIR}/${KERNDIR}/${i}.ko" "${WORKDIR}/${KERNDIR}/${i}.ko"
done


# Populate /etc directory
ETCDIR="/etc"
ETCFILES="rc"
CETCDIR="/c/etc"
CETC644FILES="board.cfg crontab rc.conf.default \
cfg/manifest cfg/rc.conf pam.d/atrun pam.d/cron pam.d/ftp pam.d/ftpd \
pam.d/imap pam.d/login pam.d/other pam.d/passwd pam.d/pop3 pam.d/sshd \
pam.d/su pam.d/system pam.d/telnetd pam.d/xdm"
CETC555FILES="rc.hostapd rc.next rc.subr rc.wpa_ibss \
rc.d/bridge rc.d/cron rc.d/ether rc.d/firewall rc.d/ifdown rc.d/ifup \
rc.d/inetd rc.d/net rc.d/ntpdate rc.d/routing rc.d/srv rc.d/sysctl \
rc.d/vlan rc.d/wifi"
CETC644FILESFROMDESTDIR="fbtab gettytab group login.access login.conf \
master.passwd  nsswitch.conf passwd protocols regdomain.xml services ttys"

echo -n "Populating ${ETCDIR} directory... "
for i in ${ETCFILES}; do
    "${SUDO_COMMAND}" install -c \
        -o "${FSOWNER}" -g "${FSGROUP}" -m 644 \
        "${WORKSPACE}/overlays/CARAMBOLA2/${ETCDIR}/${i}" \
        "${WORKDIR}/${ETCDIR}/${i}"
done
echo "Done."
echo -n "Populating ${CETCDIR} directory... "
for i in ${CETC644FILES}; do
    "${SUDO_COMMAND}" install -c \
        -o "${FSOWNER}" -g "${FSGROUP}" -m 644 \
        "${WORKSPACE}/overlays/CARAMBOLA2/${CETCDIR}/${i}" \
        "${WORKDIR}/${CETCDIR}/${i}"
done
for i in ${CETC555FILES}; do
    "${SUDO_COMMAND}" install -c \
        -o "${FSOWNER}" -g "${FSGROUP}" -m 555 \
        "${WORKSPACE}/overlays/CARAMBOLA2/${CETCDIR}/${i}" \
        "${WORKDIR}/${CETCDIR}/${i}"
done
for i in ${CETC644FILESFROMDESTDIR}; do
    "${SUDO_COMMAND}" install -c \
        -o "${FSOWNER}" -g "${FSGROUP}" -m 644 \
        "${DESTDIR}/${ETCDIR}/${i}" \
        "${WORKDIR}/${CETCDIR}/${i}"
done
echo "Done."


# Create FreeBSD kernel firmware
mkdir -p "${IMAGEDIR}"

/usr/local/bin/lzma e "${DESTDIR}/boot/kernel/kernel" \
    "${IMGWORKDIR}/kernel.lzma"
UBOOTKERNENTRYPOINT=$(elfdump -e ${DESTDIR}/boot/kernel/kernel | \
    grep e_entry | \
    awk -F':' '{print $2}')
"${SUDO_COMMAND}" mkimage -A "${UBOOTARCH}" \
    -O "${UBOOTOS}" \
    -T "${UBOOTIMGTYPE}" \
    -C "${UBOOTIMGCOMP}" \
    -a "${UBOOTKERNLOADADDR}" \
    -e "${UBOOTKERNENTRYPOINT}" \
    -n "${UBOOTIMGNAME}" \
    -d "${IMGWORKDIR}/${UBOOTIMGDATA}" \
    "${IMAGEDIR}/${UBOOTIMGFILE}"

# Create FreeBSD filesystem
"${SUDO_COMMAND}" chown "${FSOWNER}":"${FSGROUP}" "${WORKDIR}"
"${SUDO_COMMAND}" makefs -B "${FBPARTFSENDIAN}" \
    -f "${FBPARTFSMINFREE}" \
    -t ffs \
    -o label="${FBPARTFSLABEL}" \
    -o version=1 \
    -o bsize=4096 \
    -o fsize=512 \
    "${IMGWORKDIR}/${FSIMAGEFILE}" "${WORKDIR}"
mkuzip -L -d -s 131072 -v \
    -o "${IMGWORKDIR}/${FSIMAGEFILE}.ulzma" "${IMGWORKDIR}/${FSIMAGEFILE}"

# Copy image file to the specified directory
cp -pf "${IMGWORKDIR}/${FSIMAGEFILE}.ulzma" "${IMAGEDIR}"

(cd "${IMAGEDIR}" &&
    dd if="${UBOOTIMGFILE}" bs=64k conv=sync &&
    dd if="${FSIMAGEFILE}.ulzma") > "${IMAGEDIR}/${IMAGEFILE}"

echo "Your image is ready at ${IMAGEDIR}/${IMAGEFILE}"
echo "To write the image to a USB stick, do the following command:"
echo "sudo dd if=${IMAGEDIR}/${IMAGEFILE} of=/dev/<your USB stick> bs=1m"

"${SUDO_COMMAND}" rm -rf "${WORKDIRBASE}"
