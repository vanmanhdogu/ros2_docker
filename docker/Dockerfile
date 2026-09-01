# ROS 2 Foxy (Ubuntu 20.04 focal) development container.
#
# Foxy is EOL, which means two things this file has to work around:
#   1. The published image ships an apt signing key that expired in 2025,
#      so any `apt-get update` inside it fails until the key is replaced.
#   2. `rosdep update` needs --include-eol-distros to see foxy at all.
FROM osrf/ros:foxy-desktop

ARG ROS_DISTRO=foxy
ARG USERNAME=dogux
ARG UID=1000
ARG GID=1000
ARG WS_DIR=/home/dogux/ros2_foxy_ws
# Host GIDs for GPU access, so /dev/dri is usable from inside the container.
ARG VIDEO_GID=44
ARG RENDER_GID=992

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# The base image and the focal apt line below both pin this to foxy. Fail here
# rather than two minutes later on an "Unable to locate package" from apt.
RUN [ "${ROS_DISTRO}" = "foxy" ] || { \
      echo "ERROR: this image only builds for foxy, got ROS_DISTRO='${ROS_DISTRO}'." >&2; \
      echo "A ROS_DISTRO in the build environment overrides docker/.env." >&2; \
      exit 1; \
    }

# --- 1. Repair the EOL apt state -------------------------------------------
# Drop the stale ROS list first so the Ubuntu archives (whose key is still
# valid) can be used to install curl, then re-add ROS with a current key.
RUN rm -f /etc/apt/sources.list.d/ros2*.list /etc/apt/sources.list.d/ros*.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
 && curl -fsSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
      -o /usr/share/keyrings/ros-archive-keyring.gpg \
 && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu focal main" \
      > /etc/apt/sources.list.d/ros2.list \
 && apt-get update \
 && rm -rf /var/lib/apt/lists/*

# --- 2. Development toolchain ----------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential cmake git \
      python3-pip python3-venv python3-dev \
      python3-colcon-common-extensions \
      python3-colcon-mixin \
      python3-rosdep python3-vcstool python3-argcomplete \
      nano vim tmux htop less tree \
      openssh-client iputils-ping net-tools iproute2 usbutils \
      libgl1-mesa-dri libgl1-mesa-glx libglu1-mesa mesa-utils \
      sudo bash-completion \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# --- 3. ROS 2 packages -----------------------------------------------------
# Trim this layer if you don't need simulation/navigation; gazebo + nav2 are
# the bulk of the image size.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ros-${ROS_DISTRO}-rviz2 \
      ros-${ROS_DISTRO}-rqt-common-plugins \
      ros-${ROS_DISTRO}-rqt-graph \
      ros-${ROS_DISTRO}-rqt-tf-tree \
      ros-${ROS_DISTRO}-xacro \
      ros-${ROS_DISTRO}-joint-state-publisher-gui \
      ros-${ROS_DISTRO}-tf2-tools \
      ros-${ROS_DISTRO}-tf2-sensor-msgs \
      ros-${ROS_DISTRO}-teleop-twist-keyboard \
      ros-${ROS_DISTRO}-serial-driver \
      ros-${ROS_DISTRO}-cv-bridge \
      ros-${ROS_DISTRO}-image-transport \
      ros-${ROS_DISTRO}-diagnostic-updater \
      ros-${ROS_DISTRO}-demo-nodes-cpp \
      ros-${ROS_DISTRO}-demo-nodes-py \
      ros-${ROS_DISTRO}-gazebo-ros-pkgs \
      ros-${ROS_DISTRO}-navigation2 \
      ros-${ROS_DISTRO}-nav2-bringup \
      ros-${ROS_DISTRO}-slam-toolbox \
      ros-${ROS_DISTRO}-robot-localization \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --no-cache-dir --upgrade pip \
 && python3 -m pip install --no-cache-dir setuptools==58.2.0 wheel

# --- 4. Non-root user matching the host UID/GID ----------------------------
# Matching UID/GID is what keeps files written in the mounted workspace owned
# by you on the host instead of by root.
RUN if getent group ${GID} >/dev/null; then \
        existing=$(getent group ${GID} | cut -d: -f1); \
        [ "$existing" = "${USERNAME}" ] || groupmod -n ${USERNAME} "$existing"; \
    else \
        groupadd -g ${GID} ${USERNAME}; \
    fi \
 && if getent passwd ${UID} >/dev/null; then \
        existing=$(getent passwd ${UID} | cut -d: -f1); \
        [ "$existing" = "${USERNAME}" ] || usermod -l ${USERNAME} -d /home/${USERNAME} -m "$existing"; \
    else \
        useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USERNAME}; \
    fi \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
 && chmod 0440 /etc/sudoers.d/${USERNAME}

# GPU device groups (created only if the host GIDs aren't taken already).
RUN getent group ${VIDEO_GID}  >/dev/null || groupadd -g ${VIDEO_GID}  hostvideo \
 && getent group ${RENDER_GID} >/dev/null || groupadd -g ${RENDER_GID} hostrender \
 && usermod -aG "$(getent group ${VIDEO_GID}  | cut -d: -f1)" ${USERNAME} \
 && usermod -aG "$(getent group ${RENDER_GID} | cut -d: -f1)" ${USERNAME}

RUN mkdir -p ${WS_DIR}/src /home/${USERNAME}/.ros \
 && chown -R ${UID}:${GID} ${WS_DIR} /home/${USERNAME}

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

USER ${USERNAME}
WORKDIR ${WS_DIR}

ENV ROS_DISTRO=${ROS_DISTRO} \
    WS_DIR=${WS_DIR} \
    USERNAME=${USERNAME}

# rosdep needs the EOL flag or it will not know foxy exists.
RUN rosdep update --include-eol-distros --rosdistro ${ROS_DISTRO} || true

RUN { \
      echo ''; \
      echo '# --- ROS 2 environment ---'; \
      echo "source /opt/ros/${ROS_DISTRO}/setup.bash"; \
      echo "[ -f ${WS_DIR}/install/setup.bash ] && source ${WS_DIR}/install/setup.bash"; \
      echo 'source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash 2>/dev/null'; \
      echo ''; \
      echo '# --- workspace shortcuts ---'; \
      echo "alias rbuild='(cd ${WS_DIR} && colcon build --symlink-install)'"; \
      echo "alias rtest='(cd ${WS_DIR} && colcon test && colcon test-result --verbose)'"; \
      echo "alias rsource='source ${WS_DIR}/install/setup.bash'"; \
      echo "alias rclean='(cd ${WS_DIR} && rm -rf build install log)'"; \
      echo "alias rdep='(cd ${WS_DIR} && rosdep install --from-paths src --ignore-src -r -y)'"; \
    } >> /home/${USERNAME}/.bashrc

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
