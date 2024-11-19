FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive

# Configure local ubuntu mirror as package source
RUN \
  sed -i -re 's|(http://)([^/]+.*)/|\1linux.mirrors.es.net/ubuntu|g' /etc/apt/sources.list

# Install packages required for running the vivado installer
RUN \
  ln -fs /usr/share/zoneinfo/UTC /etc/localtime && \
  apt-get update -y && \
  apt-get upgrade -y && \
  apt-get install -y --no-install-recommends \
    vim \
    ca-certificates \
    libtinfo5 \
    locales \
    lsb-release \
    net-tools \
    patch \
    pigz \
    unzip \
    wget \
    libx11-dev \
    && \
  apt-get autoclean && \
  apt-get autoremove && \
  locale-gen en_US.UTF-8 && \
  update-locale LANG=en_US.UTF-8 && \
  rm -rf /var/lib/apt/lists/*

# Set up the base address for where installer binaries are stored within ESnet's private network
#
# NOTE: This URL is NOT REACHABLE outside of ESnet's private network.  Non-ESnet users must follow
#       the instructions in the README.md file and download their own copies of the installers
#       directly from the AMD/Xilinx website and drop them into the vivado-installer directory
#
ARG DISPENSE_BASE_URL="https://dispense.es.net/Linux/xilinx"

# Install the Xilinx Vivado tools and updates in headless mode
# ENV var to help users to find the version of vivado that has been installed in this container
# ENV VIVADO_VERSION=2023.2
ENV VIVADO_VERSION=2018.3
# Xilinx installer tar file originally from: https://www.xilinx.com/support/download.html
# ARG VIVADO_INSTALLER="FPGAs_AdaptiveSoCs_Unified_${VIVADO_VERSION}_1013_2256.tar.gz"
ARG VIVADO_INSTALLER="Xilinx_Vivado_SDK_2018.3_1207_2324.tar.gz"
ARG VIVADO_UPDATE="Xilinx_Vivado_SDx_Update_2018.3.1_0326_0329.tar.gz"
# Installer config file
ARG VIVADO_INSTALLER_CONFIG="/vivado-installer/install_config_main.txt"
ARG VIVADO_UPDATE_CONFIG="/vivado-installer/install_config_up1.txt"

COPY ./vivado-installer/ /vivado-installer/
RUN \
  mkdir -p /vivado-installer/install
## RUN install SDK
RUN \
    if [ -e /vivado-installer/$VIVADO_INSTALLER ] ; then \
      echo "Vivado alrady downloaded" && \
      tar --strip-components=1 -xf /vivado-installer/$VIVADO_INSTALLER -C /vivado-installer/install ; \
    else \
      echo "Downloading Vivado install from AMD" && \
      echo "https://account.amd.com/en/forms/downloads/xef-vivado.html?filename=Xilinx_Vivado_SDK_2018.3_1207_2324.tar.gz" && \
      exit 1 ; \
    fi
# Create installer config
# Fails to select ERROR: Please enter a number corresponding to the edition you would like to install.
RUN \
  if [ ! -e ${VIVADO_INSTALLER_CONFIG} ] ; then \
    /vivado-installer/install/xsetup \
      -x \
      -b ConfigGen && \
    echo "No installer configuration file was provided.  Generating a default one for you to modify." && \
    echo "-------------" && \
    exit 1 ; \
  fi ;
# install Vivado and Update
RUN \
  /vivado-installer/install/xsetup \
    --agree 3rdPartyEULA,WebTalkTerms,XilinxEULA \
    --batch Install \
    --config ${VIVADO_INSTALLER_CONFIG} && \
  rm -r /vivado-installer/install && \
  mkdir -p /vivado-installer/update && \
  if [ ! -z "$VIVADO_UPDATE" ] ; then \
    ( \
      if [ -e /vivado-installer/$VIVADO_UPDATE ] ; then \
        tar --strip-components=1 -xf /vivado-installer/$VIVADO_UPDATE -C /vivado-installer/update ; \
      else \
        echo "Downloading Vivado UPDATE from AMD" && \
        echo "https://account.amd.com/en/forms/downloads/xef-vivado.html?filename=Xilinx_Vivado_SDx_Update_2018.3.1_0326_0329.tar.gz" && \
        exit 1 ; \
      fi \
    ) && \
    /vivado-installer/update/xsetup \
    --agree 3rdPartyEULA,WebTalkTerms,XilinxEULA \
    --batch Install \
    --config ${VIVADO_UPDATE_CONFIG} && \
    rm -r /vivado-installer/update && \
    rm -rf /vivado-installer ; \
    else \
      echo "You can download SDx to have latest update from:" && \
      echo "https://account.amd.com/en/forms/downloads/xef-vivado.html?filename=Xilinx_Vivado_SDx_Update_2018.3.1_0326_0329.tar.gz" && \
    fi

# Install specific packages required by esnet-smartnic build
RUN \
  apt-get update -y && \
  apt-get upgrade -y && \
  apt-get install -y --no-install-recommends \
    build-essential \
    git \
    jq \
    less \
    libconfig-dev \
    libpci-dev \
    libsmbios-c2 \
    make \
    pax-utils \
    python3-click \
    python3-jinja2 \
    python3-libsmbios \
    python3-pip \
    python3-scapy \
    python3-yaml \
    rsync \
    tcpdump \
    tshark \
    vim-tiny \
    wireshark-common \
    zip \
    zstd \
    && \
  pip3 install pyyaml-include && \
  pip3 install yq && \
  apt-get autoclean && \
  apt-get autoremove && \
  rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash", "-c", "source /opt/Xilinx/Vivado/${VIVADO_VERSION}/settings64.sh;/bin/bash -l"]
