help([[
  XFCE remote desktop (TigerVNC + noVNC + VirtualGL) for Gila Grace Hopper nodes.

  Usage (from gila-arm.hpc.nlr.gov):
    module load xfce-vnc
    cp $XFCE_VNC_SBATCH .
    sbatch -A <account> xfce-desktop.sbatch
    # once the job is running:
    cat ~/.xfce-vnc/<jobid>/connection.txt

  Run GPU-accelerated OpenGL apps inside the desktop with: vglrun <app>

  Installing software:
    Everything below is stored in xfce-vnc-data/aarch64/ inside the directory you submit
    the desktop job from (override the xfce-vnc-data location with DESKTOP_DATA), not in $HOME.
    Applications (inside the desktop, usable immediately, no root needed):
      pixi global install <pkg>     conda-forge packages, e.g. paraview, gnuplot, ffmpeg
      pixi global list / remove <pkg>
      Run OpenGL apps on the GPU with vglrun, e.g.  vglrun paraview
    Python (inside the desktop):  pip install --user <pkg>   or   python3 -m venv <dir>
    System packages (on the login node, from the same directory, then restart the job):
      xfce-vnc-install apt <package> [...]
      xfce-vnc-install shell        # fakeroot shell to build/install by hand
]])

whatis("Name: xfce-vnc")
whatis("Version: 1.0")
whatis("Description: XFCE desktop container (Apptainer) with VNC/noVNC and VirtualGL")

local base = "/nopt/gila/apps/gracehopper/software/xfce-vnc/1.0"

setenv("XFCE_VNC_ROOT",   base)
setenv("DESKTOP_SIF",     pathJoin(base, "xfce-vnc.sif"))
setenv("XFCE_VNC_SBATCH", pathJoin(base, "xfce-desktop.sbatch"))
prepend_path("PATH",     pathJoin(base, "bin"))
