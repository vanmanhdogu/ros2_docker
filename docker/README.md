# ROS 2 Foxy container

Ubuntu 24.04 can't run Foxy natively (Foxy targets 20.04), so this runs it in a
container with your `src/` mounted from the host.

## One-time setup

```bash
# 1. Install Docker Engine (asks for your password)
sudo bash docker/install-docker.sh

# 2. Pick up the docker group without logging out
newgrp docker

# 3. Build the image (~10-20 min, several GB: gazebo + nav2 dominate)
cd docker && ./run.sh build
```

## Daily use

```bash
cd docker
./run.sh shell      # start container (if needed) and open a shell
./run.sh down       # stop it
```

Inside the container:

| alias    | does                                              |
|----------|---------------------------------------------------|
| `rdep`   | `rosdep install` deps for everything in `src/`    |
| `rbuild` | `colcon build --symlink-install`                  |
| `rsource`| source `install/setup.bash`                       |
| `rtest`  | `colcon test` + show results                      |
| `rclean` | delete `build/ install/ log/`                     |

## Verify it works

```bash
# talker/listener in two shells -> confirms DDS
ros2 run demo_nodes_cpp talker
ros2 run demo_nodes_py listener

# GUI + GL
rviz2
glxinfo | grep "OpenGL renderer"
```

## Notes

- **Same UID/GID as you (1000).** Files you create in the mounted workspace stay
  owned by `dogux` on the host — no root-owned build artifacts.
- **No roscore.** ROS 2 discovers peers over DDS. Anything that should talk to
  this container needs the same `ROS_DOMAIN_ID` (see `.env`). Set
  `ROS_LOCALHOST_ONLY=1` to keep traffic off the LAN.
- **GUI apps** use the host X server (Xwayland) via `/tmp/.X11-unix`. `run.sh`
  refreshes `/tmp/.docker.xauth` each time because mutter renames its
  Xauthority file every session.
- **If rviz2/gazebo render black or crash**, set `LIBGL_ALWAYS_SOFTWARE=1` in
  `.env` and restart — falls back to llvmpipe.
- **Foxy is EOL** (May 2023). Packages are still served from
  packages.ros.org, but the image's apt key expired, so the Dockerfile
  replaces it. `rosdep` needs `--include-eol-distros`, which `rdep` handles.
- **Serial/USB hardware:** uncomment the `devices:` and `group_add:` block in
  `docker-compose.yml`.
- `legacy-ros1-backup/` holds your previous catkin-based files.

## Why the old files were replaced

The previous Dockerfile was a ROS 1 setup pointed at a Foxy image and could not
build: `osrf/ros:foxy-desktop-full` is not a published tag, `ros-foxy-catkin`
does not exist (ROS 2 uses colcon/ament), `python-catkin-tools` / `python-pip` /
`python-rospkg` are Python 2 packages absent from focal, `ros-foxy-amcl` and
`ros-foxy-map-server` are named `nav2-amcl` / `nav2-map-server` in ROS 2,
`ros-foxy-stage` / `mbf-*` / `move-base-msgs` / `libg2o` were never released for
Foxy, and `chown /home/rgt/catkin_ws` referenced a directory that was never
created. `ROS_MASTER_URI` / `ROS_IP` are ROS 1 concepts with no effect here.
