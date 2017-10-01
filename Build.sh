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

NJOBS=$(sysctl hw.ncpu|awk '{print $NF}')

MAKE_ENVS="MAKEOBJDIRPREFIX=${OBJDIRPREFIX}"
MAKE_FLAGS="-j ${NJOBS} -DDB_FROM_SRC -DNO_FSCHG"
MAKE_ARGS="TARGET=${ARCH_m} TARGET_ARCH=${ARCH_p}"
MAKE_TARGET="${TARGET}"

if [ "${dryRunBuild}" == "true" ]; then
    DRYRUN_FLAG="-n"
fi
MAKE_FLAGS="${DRYRUN_FLAG} ${MAKE_FLAGS}"

BUILD_COMMAND="env ${MAKE_ENVS} make ${MAKE_FLAGS} ${MAKE_ARGS} ${MAKE_TARGET}"

(cd ${SRCDIR} && ${BUILD_COMMAND})
