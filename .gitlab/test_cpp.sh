#!/bin/sh
# SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# shellcheck disable=SC1091
. "$(dirname "$0")/../.ci/scripts/common.sh"

set -e
set -x
TEXT_YELLOW="\033[1;33m"
TEXT_CLEAR="\033[0m"

# Parse commandline arguments with first argument being the install directory.
INSTALL_DIR=$1

if [ -z "$INSTALL_DIR" ]; then
    echo "Usage: $0 <install_dir>"
    exit 1
fi

ARCH=$(uname -m)
[ "$ARCH" = "arm64" ] && ARCH="aarch64"

export LD_LIBRARY_PATH=${INSTALL_DIR}/lib:${INSTALL_DIR}/lib/$ARCH-linux-gnu:${INSTALL_DIR}/lib/$ARCH-linux-gnu/plugins:/usr/local/lib:$LD_LIBRARY_PATH

export CPATH=${INSTALL_DIR}/include:$CPATH
export PATH=${INSTALL_DIR}/bin:$PATH
export PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig:$PKG_CONFIG_PATH
export NIXL_PLUGIN_DIR=${INSTALL_DIR}/lib/$ARCH-linux-gnu/plugins

echo "==== Show system info ===="
env
nvidia-smi topo -m || true
ibv_devinfo || true
uname -a || true

echo "==== Running ETCD server ===="
etcd_port=$(get_next_tcp_port)
etcd_peer_port=$(get_next_tcp_port)
export NIXL_ETCD_ENDPOINTS="http://127.0.0.1:${etcd_port}"
export NIXL_ETCD_PEER_URLS="http://127.0.0.1:${etcd_peer_port}"
etcd --listen-client-urls ${NIXL_ETCD_ENDPOINTS} --advertise-client-urls ${NIXL_ETCD_ENDPOINTS} \
     --listen-peer-urls ${NIXL_ETCD_PEER_URLS} --initial-advertise-peer-urls ${NIXL_ETCD_PEER_URLS} \
     --initial-cluster default=${NIXL_ETCD_PEER_URLS} &
sleep 5

echo "==== Running C++ tests ===="
cd ${INSTALL_DIR}
./bin/gtest -- --min-tcp-port="$min_gtest_port" --max-tcp-port="$max_gtest_port"
pkill etcd
