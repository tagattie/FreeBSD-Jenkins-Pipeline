#! /bin/sh -xe

# Build USB stick image for EdgeRouter Lite (mips64)

export  LANG=C
export  PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin

SUDO_COMMAND=sudo

# Comman-line format:
# BuildImage-ERL.sh buildName destDir imageDir hostname branchname archname confname
BUILDNAME=${1}
DESTDIR=${2}
IMAGEDIR=${3}
HOSTNAME=${4}
BRANCHNAME=${5}
ARCHNAME=${6}
CONFNAME=${7}

WORKSPACE=$(pwd)
WORKDIR=${WORKSPACE}/work
IMAGEFILE=FreeBSD-${BRANCHNAME}-${ARCHNAME}-${HOSTNAME}-${BUILDNAME}.img

KiB=1024
MiB=$((${KiB}*1024))
GiB=$((${MiB}*1024))
# Image size is 2GiB
IMGSIZE=$((2*${GiB}))
IMGSIZEMB=$((${IMGSIZE}/${MiB}))
# Very traditional logical disk structure
SECTORSPERTRACK=63
HEADSPERCYLINDER=255
BYTESPERSECTOR=512
STARTSECTOR=63
# Parition scheme is MBR
PARTSCHEME=MBR
# Boot partition
BOOTPARTSIZE=$((256*${MiB}))
BOOTPARTSIZEMB=$((${BOOTPARTSIZE}/${MiB}))
BOOTPARTSECTORMARGIN=1
BOOTPARTTYPE='!12'            # FAT32 (LBA-addressable)
BOOTPARTLABEL=msdosboot
BOOTPARTFSTYPE=msdosfs
BOOTPARTFS=16                 # FAT16
# FreeBSD partition
FBPARTTYPE=freebsd
FBPARTSCHEME=BSD
FBPARTFSTYPE=freebsd-ufs
FBPARTFSALIGN=$((64*${KiB}))
FBPARTFSENDIAN=big
FBPARTFSLABEL=rootfs
FBPARTFSMINFREE=$(bc -e "${IMGSIZE}/1024*0.5" -e quit | awk -F'.' '{print $1}')
FBPARTFSMARGIN=$((64*${MiB}))
FBPARTFSSIZE=$(((${IMGSIZEMB}-${BOOTPARTSIZEMB})*${MiB}-${FBPARTFSMARGIN}))
### Swapfile
# SWAPFILENAME="swap0"
# SWAPFILESIZE=$((1*${GiB}))
### You need to increase IMGSIZE if you create swapfile here.

# Populate some files in advance of image building
OVERLAYFILES="boot/loader.conf etc/fstab etc/rc.conf"
OVERLAYFILEMODE=644
OVERLAYFILEOWNER=root
OVERLAYFILEGROUP=wheel
FIRSTBOOTSENTINEL=firstboot
for i in ${OVERLAYFILES}; do
    ${SUDO_COMMAND} install -c \
        -m ${OVERLAYFILEMODE} \
        -o ${OVERLAYFILEOWNER} \
        -g ${OVERLAYFILEGROUP} \
        ${WORKSPACE}/overlays/${CONFNAME}/${i} ${DESTDIR}/${i}
done
${SUDO_COMMAND} install -d \
    -o ${OVERLAYFILEOWNER} \
    -g ${OVERLAYFILEGROUP} \
    ${DESTDIR}/boot/msdos
### Swapfile
# "${SUDO_COMMAND}" truncate -s "${SWAPFILESIZE}" "${DESTDIR}/${SWAPFILENAME}"
# "${SUDO_COMMAND}" chmod 600 "${DESTDIR}/${SWAPFILENAME}"
###
${SUDO_COMMAND} touch ${DESTDIR}/${FIRSTBOOTSENTINEL}

mkdir -p ${WORKDIR}

# Create image file and mount it as memory disk
truncate -s ${IMGSIZE} ${WORKDIR}/${IMAGEFILE}
MDDEVNAME=$(${SUDO_COMMAND} mdconfig -a -t vnode \
    -x ${SECTORSPERTRACK} -y ${HEADSPERCYLINDER} -f ${WORKDIR}/${IMAGEFILE})
echo "Memory disk device name is ${MDDEVNAME}."

# Create partition scheme
${SUDO_COMMAND} gpart create -s ${PARTSCHEME} ${MDDEVNAME}
# Create FAT32(LBA-addressable) partition for boot (1st slice)
${SUDO_COMMAND} gpart add -a ${SECTORSPERTRACK} \
    -b ${STARTSECTOR} \
    -s $((${BOOTPARTSIZE}/${BYTESPERSECTOR}-${BOOTPARTSECTORMARGIN})) \
    -t ${BOOTPARTTYPE} ${MDDEVNAME}
# Make the slice (boot slice) active (bootable)
${SUDO_COMMAND} gpart set -a active -i 1 ${MDDEVNAME}
# Create FAT16 filesystem in the boot slice
${SUDO_COMMAND} newfs_msdos -L ${BOOTPARTLABEL} \
    -F ${BOOTPARTFS} /dev/${MDDEVNAME}s1
# Mount the FAT16 filesystem and copy necessary files onto it
mkdir -p ${WORKDIR}/${BOOTPARTLABEL}
${SUDO_COMMAND} mount -t ${BOOTPARTFSTYPE} \
    -l /dev/${MDDEVNAME}s1 ${WORKDIR}/${BOOTPARTLABEL}

install -d ${WORKDIR}/${BOOTPARTLABEL}/kernel
(cd ${DESTDIR}/boot/kernel && \
    find . -print -depth | \
    cpio -padm ${WORKDIR}/${BOOTPARTLABEL}/kernel)

${SUDO_COMMAND} umount ${WORKDIR}/${BOOTPARTLABEL}
rmdir ${WORKDIR}/${BOOTPARTLABEL}

# Create FreeBSD partition (2nd slice)
${SUDO_COMMAND} gpart add -t ${FBPARTTYPE} ${MDDEVNAME}
# Set partition scheme of the FreeBSD slice
${SUDO_COMMAND} gpart create -s ${FBPARTSCHEME} ${MDDEVNAME}s2
# Add freebsd-ufs partition (make alignment to 64KiB)
${SUDO_COMMAND} gpart add -a ${FBPARTFSALIGN} \
    -t ${FBPARTFSTYPE} ${MDDEVNAME}s2
# Make UFS filesystem (big endian) from the distribution
${SUDO_COMMAND} makefs -B ${FBPARTFSENDIAN} \
    -f ${FBPARTFSMINFREE} \
    -t ffs \
    -o label=${FBPARTFSLABEL} -o version=2 \
    -s ${FBPARTFSSIZE} \
    ${WORKDIR}/$(basename ${IMAGEFILE} .img).ufs ${DESTDIR}
${SUDO_COMMAND} dd if=${WORKDIR}/$(basename ${IMAGEFILE} .img).ufs \
    of=/dev/${MDDEVNAME}s2a bs=1m
${SUDO_COMMAND} mdconfig -d -u ${MDDEVNAME}

# Copy image file to specified directory
mkdir -p ${IMAGEDIR}
cp -pf ${WORKDIR}/${IMAGEFILE} ${IMAGEDIR}

echo "Your image is ready at ${IMAGEDIR}/${IMAGEFILE}."
echo "To write the image to a USB stick, do the following command:"
echo "sudo dd if=${IMAGEDIR}/${IMAGEFILE} of=/dev/<your USB stick> bs=1m"

rm -rf ${WORKDIR}
