#!/bin/bash
# Build the xfce-vnc image for this node's architecture and optionally install it.
# Run inside a job on a compute node of the target architecture (gh or gpu-intel-a100-80g).
#
# Usage: ./build.sh [--deploy] [output.sif]
#   --deploy  install the image, job script, installer and modulefile into the /nopt tree
#             for this architecture (image replaced atomically; running desktops are unaffected)
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

DEPLOY=0
if [[ ${1:-} == --deploy ]]; then DEPLOY=1; shift; fi

ARCH=$(uname -m)
case $ARCH in
    aarch64)
        ROOT=/nopt/gila/apps/gracehopper/software/xfce-vnc
        SBATCH=xfce-desktop.sbatch
        MODULE=modules/gracehopper/xfce-vnc/1.0.lua
        # Some ports.ubuntu.com IPs hang from Gila
        BUILD_ARGS=(--build-arg "UBUNTU_MIRROR=${UBUNTU_MIRROR:-http://mirrors.ocf.berkeley.edu/ubuntu-ports}")
        ;;
    x86_64)
        ROOT=/nopt/gila/apps/gila/software/xfce-vnc
        SBATCH=xfce-desktop-a100.sbatch
        MODULE=modules/gila/xfce-vnc/1.0.lua
        BUILD_ARGS=()
        ;;
    *)
        echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
esac
DEST=$ROOT/1.0
OUT=${1:-/tmp/xfce-vnc-$ARCH.sif}

if [[ -z ${SLURM_JOB_ID:-} ]]; then
    echo "Run this inside a job on a compute node, not on a login node." >&2; exit 1
fi

# Node-local disk; building on Ceph is much slower
export APPTAINER_CACHEDIR=${APPTAINER_CACHEDIR:-/tmp/$USER-apptainer-cache}
APPTAINER_TMPDIR=$(mktemp -d /tmp/aptbuild.XXXXXX)
export APPTAINER_TMPDIR
trap 'rm -rf "$APPTAINER_TMPDIR"' EXIT

apptainer build --force --fakeroot "${BUILD_ARGS[@]}" "$OUT" xfce-vnc.def
echo "Built $OUT"

(( DEPLOY )) || exit 0

# Group-writable for n-apps regardless of the caller's umask
install -m 664 -g n-apps "$OUT" "$DEST/.xfce-vnc.sif.tmp"
mv -f "$DEST/.xfce-vnc.sif.tmp" "$DEST/xfce-vnc.sif"
install -m 664 -g n-apps "$SBATCH" xfce-vnc.def "$DEST/"
install -m 775 -g n-apps start-desktop bwrap-wrapper "$DEST/"
install -m 775 -g n-apps xfce-vnc-install "$DEST/bin/"
install -m 664 -g n-apps "$MODULE" "$ROOT/modules/xfce-vnc/1.0.lua"
echo "Deployed to $DEST"
