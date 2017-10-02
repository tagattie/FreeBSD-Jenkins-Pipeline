#! /bin/sh -xe

export  LANG=C
export  PATH=/sbin:/bin:/usr/sbin:/usr/bin

# Comman-line format:
# Build.sh srcDir objDirPrefix machArch cpuArch buildTarget
SRCDIR=${1}
OBJDIRPREFIX=${2}
ARCH_m=${3}
ARCH_p=${4}
if [ -n "${5}" ]; then
    KERN_ARGS="KERNCONF=${5}"
fi
if [ -n "${6}" ]; then
    DEST_ARGS="DESTDIR=${6}"
fi
ADD_ARGS=${7}

shift 7
TARGETS=$@

NJOBS=$(sysctl hw.ncpu|awk '{print $NF}')

MAKE_ENVS="MAKEOBJDIRPREFIX=${OBJDIRPREFIX}"
MAKE_FLAGS="-j ${NJOBS} -DDB_FROM_SRC -DNO_FSCHG"
MAKE_ARGS="TARGET=${ARCH_m} TARGET_ARCH=${ARCH_p} ${KERN_ARGS} ${DEST_ARGS} ${ADD_ARGS}"
MAKE_TARGET="${TARGETS}"

if [ "${dryRunBuild}" == "true" ]; then
    DRYRUN_FLAG="-n"
fi
MAKE_FLAGS="${DRYRUN_FLAG} ${MAKE_FLAGS}"

BUILD_COMMAND="env ${MAKE_ENVS} make ${MAKE_FLAGS} ${MAKE_ARGS} ${MAKE_TARGET}"

(cd ${SRCDIR} && ${BUILD_COMMAND})
