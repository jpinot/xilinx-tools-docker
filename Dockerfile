# Use Ubuntu 20.04 as base image
FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive

# Configure a local Ubuntu mirror for package sources
RUN sed -i -re 's|(http://)([^/]+.*)/|\1linux.mirrors.es.net/ubuntu|g' /etc/apt/sources.list

# Install essential packages for Vivado installer
RUN ln -fs /usr/share/zoneinfo/UTC /etc/localtime && \
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
        libx11-dev && \
    apt-get autoclean && \
    apt-get autoremove && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

# Set Vivado version and installers
ENV VIVADO_VERSION=2018.3
ARG VIVADO_INSTALLER="Xilinx_Vivado_SDK_2018.3_1207_2324.tar.gz"
ARG VIVADO_UPDATE="Xilinx_Vivado_SDx_Update_2018.3.1_0326_0329.tar.gz"
ARG VIVADO_INSTALLER_CONFIG="/vivado-installer/install_config_main.txt"
ARG VIVADO_UPDATE_CONFIG="/vivado-installer/install_config_up1.txt"

# Copy Vivado installer files
COPY ./vivado-installer/ /vivado-installer/
RUN mkdir -p /vivado-installer/install

# Unpack and set up Vivado installer
RUN if [ -e /vivado-installer/$VIVADO_INSTALLER ]; then \
      echo "Vivado already downloaded" && \
      tar --strip-components=1 -xf /vivado-installer/$VIVADO_INSTALLER -C /vivado-installer/install; \
    else \
      echo "Downloading Vivado install from AMD" && \
      echo "https://account.amd.com/en/forms/downloads/xef-vivado.html?filename=Xilinx_Vivado_SDK_2018.3_1207_2324.tar.gz" && \
      exit 1; \
    fi

# Generate default installer configuration if not provided
RUN if [ ! -e ${VIVADO_INSTALLER_CONFIG} ]; then \
      /vivado-installer/install/xsetup -x -b ConfigGen && \
      echo "No installer configuration file was provided. Generating a default one for you to modify." && \
      exit 1; \
    fi

# Install Vivado and update
RUN /vivado-installer/install/xsetup \
      --agree 3rdPartyEULA,WebTalkTerms,XilinxEULA \
      --batch Install \
      --config ${VIVADO_INSTALLER_CONFIG} && \
    rm -r /vivado-installer/install && \
    mkdir -p /vivado-installer/update && \
    if [ -n "$VIVADO_UPDATE" ]; then \
      if [ -e /vivado-installer/$VIVADO_UPDATE ]; then \
        tar --strip-components=1 -xf /vivado-installer/$VIVADO_UPDATE -C /vivado-installer/update; \
      else \
        echo "Downloading Vivado UPDATE from AMD" && \
        echo "https://account.amd.com/en/forms/downloads/xef-vivado.html?filename=Xilinx_Vivado_SDx_Update_2018.3.1_0326_0329.tar.gz" && \
        exit 1; \
      fi && \
      /vivado-installer/update/xsetup \
        --agree 3rdPartyEULA,WebTalkTerms,XilinxEULA \
        --batch Install \
        --config ${VIVADO_UPDATE_CONFIG} && \
      rm -r /vivado-installer/update && \
      rm -rf /vivado-installer; \
    else \
      echo "You can download SDx to have the latest update from:" && \
      echo "https://account.amd.com/en/forms/downloads/xef-vivado.html?filename=Xilinx_Vivado_SDx_Update_2018.3.1_0326_0329.tar.gz"; \
    fi

# Install additional packages required by esnet-smartnic build
RUN apt-get update -y && \
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
        zstd && \
    pip3 install pyyaml-include yq && \
    apt-get autoclean && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

# Add entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set entrypoint and command
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash", "-c", "source /opt/Xilinx/Vivado/${VIVADO_VERSION}/settings64.sh; /bin/bash -l"]
