#!/bin/bash

#
# Copyright (c) 2023 psabhishek26
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

println_msg() {
    echo
    echo -e "\e[1;32m$*\e[0m"
}

print_msg() {
    echo -e "\e[1;32m$*\e[0m"
}

read_msg() {
    echo -en "\e[1;34m$*\e[0m"
}

warn_msg() {
    echo
    echo -e "\e[1;33m$*\e[0m"
}

err_msg() {
    echo -e "\e[1;41m$*\e[0m"
    exit 1
}

confirm() {
    read -r -p ": " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then true; else false; fi
}

setup_env() {
    #TODO: Differentiate package manager depending upon distro
    println_msg "[#] Setting up build environment"
    sleep 2
    sudo apt-get install libncurses-dev gawk flex bison openssl libssl-dev dkms libelf-dev \
                        libudev-dev libpci-dev libiberty-dev autoconf llvm jq tar neofetch -y
    clear
    neofetch
}

install_kernel() {
    println_msg "[#] Do you want to install this build (deafult=Y)"
    if confirm;
    then
        print_msg "[#] Installing new build"
        sudo make modules_install
        sudo make install
    fi
}

compile() {
    if [ -f arch/x86/boot/bzImage ];
    then
        warn_msg "[!] Previous build remainings found"
        read_msg "[$] Do you want to do clean build (default=N) (y/n)"
        if confirm; then make clean && make mrproper; fi
    fi
    println_msg "[#] Kernel Compilation started"
    read_msg "[#] Do you want to show compilation log (default=N) (y/n)"
    if confirm; then make -j$(nproc --all); else make -j$(nproc --all) > /dev/null; fi
    if [ -f arch/x86/boot/bzImage ];
    then
        println_msg "[#] Kernel Compilation successful"
        install_kernel
    else
        err_msg "[!] Kernel Compilation failed"
    fi
}

setup_config() {
    if [ -f .config ];
    then
        println_msg "[#] Config found"
    else 
        warn_msg "[!] No config found, using default config"
        cp /boot/config-$(uname -r) .config
        make olddefconfig
    fi
    if [ -f /etc/debian_version ];
    then
        warn_msg "[!] Debian based distro detected, disabling trusted keys"
        scripts/config --disable SYSTEM_TRUSTED_KEYS
        scripts/config --disable SYSTEM_REVOCATION_KEYS
    fi
    read_msg "[$] Do you want to change kernel version name (default=N) (y/n)"
    if confirm;
    then
        read_msg "[$] Enter your version name: "
        read version_name
        sed -i "s/^\(CONFIG_LOCALVERSION=\"\)/\1${version_name}/" .config
    fi
    read_msg "[$] Do you want to modify anything further (default=N) (y/n)"
    if confirm;
    then
        warn_msg "[!] Proceed with caution if uncertain"
        sleep 3
        make menuconfig > /dev/null
    fi
    compile 
}

download() {
    if ! [ -f .config ];
    then
        println_msg "[#] Downloading latest kernel: v${latest_tag}"
        link="https://cdn.kernel.org/pub/linux/kernel/$(echo $latest_tag | sed 's/^\([0-9]\)\..*/v\1.x/')/linux-${latest_tag}.tar.xz"
        wget -c -q --show-progress $link
        print_msg "[#] Extracting kernel tar file"
        tar xf linux-${latest_tag}.tar.xz --strip-components=1
        rm -rf linux-${latest_tag}.tar.xz
    fi
    setup_config
}

init() {
    println_msg "[#] Installed kernel version: $(uname -r)"
    latest_tag=$(curl --silent "https://www.kernel.org/releases.json" | jq -r '.latest_stable.version')
    print_msg "[#] Latest stable kernel version: ${latest_tag}"
    read_msg "[$] Do you want to continue (default=Y) (y/n)"
    if confirm; then download; else exit; fi
}

setup_env
init
