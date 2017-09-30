#! /bin/sh -xe

export  LANG=C
export  PATH=/sbin:/bin:/usr/sbin:/usr/bin

# Comman-line format:
# Build.sh srcDir objDirPrefix machArch cpuArch buildTarget
SRCDIR=${1}
OBJDIRPREFIX=${2}
ARCH_m=${3}
ARCH_p=${4}
TARGET=${5}

NJOBS=$(sysctl hw.ncpu)

MAKE_ARGS="TARGET=${ARCH_m} TARGET_ARCH=${ARCH_p}"
MAKE_ENVS="MAKEOBJDIRPREFIX=${OBJDIRPREFIX}"
MAKE_FLAGS="-j ${NJOBS} -DDB_FROM_SRC -DNO_FSCHG"

BUILD_COMMAND="env ${MAKE_ENV} make ${MAKE_FLAGS} ${MAKR_ARGS} ${MAKE_TARGET}"

(cd ${SRCDIR} && ${BUILD_COMMAND})
