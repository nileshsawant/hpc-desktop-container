help([[
  XFCE remote desktop (TigerVNC + noVNC + VirtualGL) on a whole 8x A100-80GB node
  (partition gpu-intel-a100-80g), for interactive GPU / machine learning work.

  Usage (from gila.hpc.nlr.gov):
    module load application/25.05 xfce-vnc
    cp $XFCE_VNC_SBATCH .
    sbatch -A <account> xfce-desktop-a100.sbatch
    # once the job is running:
    cat ~/.xfce-vnc/<jobid>/connection.txt

  Run GPU-accelerated OpenGL apps inside the desktop with: vglrun <app>

  Multi-GPU notes:
    GPUs 0-1, 2-3, 4-5 and 6-7 are NVLink pairs (~185 GB/s all-reduce); traffic between
    pairs goes over PCIe (~9 GB/s). For 2-GPU training pin to a pair, e.g.
      CUDA_VISIBLE_DEVICES=0,1 torchrun --standalone --nproc_per_node=2 train.py
    Independent single-GPU runs (one per GPU) are not affected.

  Installing software:
    Everything below is stored in xfce-vnc-data/x86_64/ inside the directory you submit
    the desktop job from (override the xfce-vnc-data location with DESKTOP_DATA), not in $HOME.
    Applications (inside the desktop, usable immediately, no root needed):
      pixi global install <pkg>     conda-forge packages, e.g. paraview, gnuplot, ffmpeg
      pixi global list / remove <pkg>
      Run OpenGL apps on the GPU with vglrun, e.g.  vglrun paraview
    Python (inside the desktop):  pip install --user <pkg>   or   python3 -m venv <dir>
      e.g.  pip install --user torch
    System packages (on the login node, from the same directory, then restart the job):
      xfce-vnc-install apt <package> [...]
      xfce-vnc-install shell        # fakeroot shell to build/install by hand
]])

whatis("Name: xfce-vnc")
whatis("Version: 1.0")
whatis("Description: XFCE desktop container (Apptainer) with VNC/noVNC and VirtualGL, 8x A100 nodes")

local base = "/nopt/gila/apps/gila/software/xfce-vnc/1.0"

setenv("XFCE_VNC_ROOT",   base)
setenv("DESKTOP_SIF",     pathJoin(base, "xfce-vnc.sif"))
setenv("XFCE_VNC_SBATCH", pathJoin(base, "xfce-desktop-a100.sbatch"))
prepend_path("PATH",     pathJoin(base, "bin"))
