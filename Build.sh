#! /bin/sh -xe

export  LANG=C
export  PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin

SUDO_COMMAND=sudo

# Comman-line format:
# Build.sh srcDir objDirPrefix machArch cpuArch kernArgs destArgs additionalArgs buildTargets
SRCDIR=${1}
OBJDIRPREFIX=${2}
ARCH_m=${3}
ARCH_p=${4}
if [ "${5}" != "null" ]; then
    KERN_ARGS="KERNCONF=${5}"
fi
if [ "${6}" != "null" ]; then
    DEST_ARGS="DESTDIR=${6}"
fi
if [ "${7}" != "null" ]; then
    ADD_ARGS=${7}
fi

NJOBS=$(sysctl hw.ncpu|awk '{print $NF}')

MAKE_ENVS="MAKEOBJDIRPREFIX=${OBJDIRPREFIX}"
MAKE_FLAGS="-DDB_FROM_SRC -DNO_FSCHG"
MAKE_ARGS="TARGET=${ARCH_m} TARGET_ARCH=${ARCH_p} ${KERN_ARGS} ${DEST_ARGS} ${ADD_ARGS}"
MAKE_TARGET=${TARGETS}

if [ "${dryRunBuild}" == "true" ]; then
    DRYRUN_FLAG="-n"
fi
MAKE_FLAGS="${DRYRUN_FLAG} ${MAKE_FLAGS}"

shift 7
for i in "$@"; do
    if [ "${i}" == "buildworld" ] || \
           [ "${i}" == "buildkernel" ]; then
        FINAL_MAKE_FLAGS="-j ${NJOBS} ${MAKE_FLAGS}"
    elif [ "${i}" == "installworld" ] || \
             [ "${i}" == "installkernel" ] || \
             [ "${i}" == "distribution" ]; then
        FINAL_MAKE_FLAGS=${MAKE_FLAGS}
    fi
    BUILD_COMMAND="${SUDO_COMMAND} env ${MAKE_ENVS} make ${FINAL_MAKE_FLAGS} ${MAKE_ARGS} ${i}"
    (cd ${SRCDIR} && ${BUILD_COMMAND})
done
