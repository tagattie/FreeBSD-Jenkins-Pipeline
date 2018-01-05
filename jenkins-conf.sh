#! /bin/sh

export OBJDIR_BASEDIR=/var/tmp/jenkins/freebsd/obj
export OBJDIR=${OBJDIR_BASEDIR}/${DESTHOST}

export DESTDIR_BASEDIR=/var/tmp/jenkins/freebsd/destdir
export DESTDIR_MOUNTTYPE=zfs
export DESTDIR=${DESTDIR_BASEDIR}/${DESTHOST}

# dummy mount targets to pass check
export MOUNT_TARGETS="localhost:${ROOTDIR}:${DESTDIR_MOUNTTYPE}:${ROOTDIR}"
