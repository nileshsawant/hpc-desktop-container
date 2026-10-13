#!/bin/bash
# Launch an XFCE remote desktop on a whole Gila 8x A100-80GB node (gpu-intel-a100-80g).
#
# Usage (from gila.hpc.nlr.gov):
#   sbatch -A <account> xfce-desktop-a100.sbatch
#   # once running:
#   cat ~/.xfce-vnc/<jobid>/connection.txt
#
# The job gets the whole node: 8 GPUs, 42 cores, all memory.
# GPUs 0-1, 2-3, 4-5 and 6-7 are NVLink pairs (~185 GB/s all-reduce); traffic between pairs
# goes over PCIe (~9 GB/s). Pin 2-GPU jobs to a pair, e.g. CUDA_VISIBLE_DEVICES=2,3.
#
# Override resources on the command line, e.g.  sbatch -A <acct> -t 8:00:00 xfce-desktop-a100.sbatch
# Optional env: DESKTOP_GEOMETRY=2560x1440  DESKTOP_NOVNC=0
#               DESKTOP_DATA=<dir>  where pip --user / pixi installs, caches and the apt overlay live
#                                   (default: xfce-vnc-data/ in the directory you submit from)
#
#SBATCH --job-name=xfce-desktop
#SBATCH --partition=gpu-intel-a100-80g
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=42
#SBATCH --mem=0
#SBATCH --gres=gpu:8
#SBATCH --exclusive
#SBATCH --time=04:00:00
#SBATCH --output=%x-%j.out

SIF=${DESKTOP_SIF:-/nopt/gila/apps/gila/software/xfce-vnc/1.0/xfce-vnc.sif}
BINDS=/projects,/scratch,/nopt

# NVIDIA EGL on Grace needs libnvidia-rmapi-tegra, which Apptainer's nvliblist.conf
# does not bind; without it VirtualGL falls back to software rendering.
for lib in /usr/lib64/libnvidia-rmapi-tegra.so.*; do
    [[ -e $lib ]] && BINDS+=",$lib:/usr/lib/aarch64-linux-gnu/${lib##*/}"
done

# The node's FQDN (e.g. gila-gpu-2.novalocal) resolves only to IPv6 link-local addresses,
# which makes torchrun --standalone and other tools that look up their own hostname hang.
if ! getent ahostsv4 "$(hostname)" >/dev/null; then
    ip=$(getent ahostsv4 "$(hostname -s)" | awk 'NR==1{print $1}')
    if [[ -n $ip ]]; then
        HOSTS=$(mktemp /tmp/xfce-vnc-hosts.XXXXXX)
        { cat /etc/hosts; echo "$ip $(hostname) $(hostname -s)"; } > "$HOSTS"
        chmod 644 "$HOSTS"
        BINDS+=",$HOSTS:/etc/hosts"
    fi
fi

# User-installed software and caches go next to the job, not in the small $HOME quota.
# One subdirectory per CPU architecture: packages built for aarch64 do not run on x86_64.
BASE=${DESKTOP_DATA:-${SLURM_SUBMIT_DIR:-$PWD}/xfce-vnc-data}
DATA=$BASE/$(uname -m)
# Move data from the original single-architecture layout (Grace Hopper only)
if [[ $(uname -m) == aarch64 && ! -e $DATA ]]; then
    for d in local cache overlay; do
        if [[ -e $BASE/$d ]]; then
            mkdir -p "$DATA" && mv "$BASE/$d" "$DATA/" && echo "Moved $BASE/$d -> $DATA/$d"
        fi
    done
fi
mkdir -p "$DATA/local" "$DATA/cache"
# APPTAINERENV_* is applied after the image's %environment, which would otherwise win
export APPTAINERENV_PYTHONUSERBASE=$DATA/local       # pip install --user
export APPTAINERENV_PIXI_HOME=$DATA/pixi             # pixi global install
export APPTAINERENV_PREPEND_PATH=$DATA/pixi/bin:$DATA/local/bin
export XDG_CACHE_HOME=$DATA/cache    # pip, torch hub, Hugging Face, Firefox caches
echo "Desktop data directory: $DATA"
[[ $DATA == /scratch/* ]] && echo "Note: /scratch is purged after 28 days without use."

# Personal overlay with extra packages (see xfce-vnc-install); read-only so several
# desktops can share it.
OVERLAY=${DESKTOP_OVERLAY:-$DATA/overlay}
OVL_ARGS=()
[[ -d $OVERLAY ]] && OVL_ARGS=(--overlay "$OVERLAY:ro")

exec apptainer run --nv "${OVL_ARGS[@]}" --bind "$BINDS" "$SIF"
