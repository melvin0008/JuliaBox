#! /usr/bin/env bash
# Mount JuliaBox loopback volumes

if [ $# -ne 3 ]
then
    echo "Usage: sudo mount_fs.sh <ndisks> <ds_size_mb> <fs_user_id>"
    exit 1
fi

if [ "root" != `whoami` ]
then
    echo "Must be run as superuser"
	exit 1
fi

NDISKS=$1
FS_SIZE_MB=$2
ID=$3
echo "Creating and mounting $NDISKS user disks of size $FS_SIZE_MB MB each..."

function error_exit {
	echo "$1" 1>&2
	exit 1
}

function make_ebs_fstab_entries {
    let var=1
    for pfx1 in {b..c}
    do
        for pfx2 in {a..z}
        do
            if [ $var -le $2 ]
            then
                dev_id="xvd${pfx1}${pfx2}"
                fstab_line="/dev/${dev_id} $1/${dev_id} ext4 rw,user,exec 0 0"
                found_line=$( grep -ic "${fstab_line}" /etc/fstab )
                if [ $found_line -ne 1 ]
                then
                    echo "${fstab_line}" >> /etc/fstab
                fi
                let var=var+1
            fi
        done
    done
}

FS_DIR=/mnt/jbox
IMG_DIR=${FS_DIR}/img
MNT_DIR=${FS_DIR}/mnt
EBS_DIR=${FS_DIR}/ebs
echo "    Creating folders to hold filesystems..."
mkdir -p ${FS_DIR} ${IMG_DIR} ${MNT_DIR} ${EBS_DIR} || error_exit "Could not create folders to hold filesystems"
echo "    Creating fstab entries..."
make_ebs_fstab_entries ${EBS_DIR} ${NDISKS}

echo "    Stopping docker to make sure no loop devices are in use..."
service docker stop

echo "Creating template disk image..."
dd if=/dev/zero of=${MNT_DIR}/jimg bs=1M count=${FS_SIZE_MB} || error_exit "Error creating disk image file"
losetup /dev/loop0 ${MNT_DIR}/jimg || error_exit "Error mapping template disk image"
mkfs -t ext3 -m 1 -v /dev/loop0 || error_exit "Error making ext3 filesystem at /dev/loop0"
chown -R ${ID}:${ID} /dev/loop0 || error_exit "Error changing file ownership on /dev/loop0"
losetup -d /dev/loop0

echo "    Creating loopback devices..."
NDISKS=$((NDISKS-1))
for i in $(seq 0 ${NDISKS})
do
    echo -n "${i}."
    LOOP=/dev/loop$i
    MNT=${MNT_DIR}/${i}
    IMG=${IMG_DIR}/${i}

    if [ ! -e $LOOP ]
    then
        mknod -m0660 $LOOP b 7 $i || error_exit "Could not create loop device $LOOP."
        chown root.disk /dev/loop$i || error_exit "Could not create loop device $LOOP. Error setting owner."
    fi

    if [ ! -e ${IMG} ]
    then
        cp ${MNT_DIR}/jimg ${IMG}
    fi
    losetup ${LOOP} ${IMG} || error_exit "Error mapping ${IMG} to ${LOOP}"

    if [ ! -e ${MNT} ]
    then
        mkdir -p ${MNT} || error_exit "Error creating mount point ${MNT}"
    fi

    mount ${LOOP} ${MNT} || error_exit "Error mounting filesystem at ${MNT}"
    chown -R ${ID}:${ID} ${MNT} || error_exit "Error changing file ownership on ${MNT}"
done

rm -f ${MNT_DIR}/jimg

echo "    Creating mount points for EBS devices..."
ebs_mnt_dirs=`grep "${EBS_DIR}" /etc/fstab | cut -d" " -f2`
for ebs_mnt_dir in ${ebs_mnt_dirs}
do
    mkdir -p ${ebs_mnt_dir}
done
chown -R ${ID}:${ID} ${EBS_DIR}

echo ""
echo "DONE"
