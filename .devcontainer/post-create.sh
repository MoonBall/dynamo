#!/bin/bash

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

set -e

# Create and activate Python virtual environment
python3 -m venv venv
. ./venv/bin/activate

pip config set global.index-url https://mirrors.ivolces.com/pypi/simple/

# Build Rust components first
# cargo build --release

# Install Dynamo with all dependencies
# pip install -e .[all]

# Install development tools
pip install pytest isort mypy pylint pre-commit

# 启动时会报错 No module named 'distro'
pip install distro

# 为了 debug
pip install debugpy

# README 里需要的
sudo apt-get install -y build-essential libhwloc-dev libudev-dev \
pkg-config libssl-dev libclang-dev protobuf-compiler python3-dev cmake

# git 经常报错
sudo apt-get install --only-upgrade git
git config --global http.postBuffer 1048576000
# curl 56 GnuTLS recv error (-9): Error decoding the received TLS packet.
git config --global http.compression 0
git config --global 'url.git@github.com:.insteadOf' https://github.com/

git config --global core.editor vim

# 其他常用工具
sudo apt-get install -y lsof vim

tee -a ~/.bashrc <<EOF

export RUSTUP_DIST_SERVER="https://rsproxy.cn"
export RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"
EOF
source ~/.bashrc

mkdir -p ~/.cargo && \
    cat > ~/.cargo/config <<EOF
[source.crates-io]
replace-with = 'rsproxy-sparse'
[source.rsproxy]
registry = "https://rsproxy.cn/crates.io-index"
[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"
[registries.rsproxy]
index = "https://rsproxy.cn/crates.io-index"
[net]
git-fetch-with-cli = true
EOF


pwd
# host 环境不需要 ss 和 privoxy
# [ -f /workspaces/dynamo/.devcontainer/.proxy-ss-privoxy.sh ] && bash /workspaces/dynamo/.devcontainer/.proxy-ss-privoxy.sh
# [ -f /workspaces/dynamo/.devcontainer/.proxy-config.sh ] && bash /workspaces/dynamo/.devcontainer/.proxy-config.sh


# 不安装的话，rust 某些源码找不到
rustup component add rust-src

tee -a ~/.bashrc <<EOF

function dyn-kill() {
    sudo lsof -ti :8000 | xargs -r sudo kill -9
    sudo lsof -ti :3000 | xargs -r sudo kill -9
    sudo lsof -ti :5678-5698 -c python3 | xargs -r sudo kill -9
    nvidia-smi --query-compute-apps=pid --format=csv,noheader | xargs -r kill -9
    rm -rf /workspaces/models/__dyn_dev_continue_debug__ /data00/chengang.07/models/__dyn_dev_continue_debug__
}
EOF

tee -a ~/.bashrc <<EOF

function dyn-build() {
    cd /workspaces/dynamo
    cargo build 
    mkdir -p /workspaces/dynamo/deploy/dynamo/sdk/src/dynamo/sdk/cli/bin
    cp /workspaces/dynamo/target/debug/http /workspaces/dynamo/deploy/dynamo/sdk/src/dynamo/sdk/cli/bin
    cp /workspaces/dynamo/target/debug/llmctl /workspaces/dynamo/deploy/dynamo/sdk/src/dynamo/sdk/cli/bin
    cp /workspaces/dynamo/target/debug/dynamo-run /workspaces/dynamo/deploy/dynamo/sdk/src/dynamo/sdk/cli/bin
}
EOF

tee -a ~/.bashrc <<EOF

function dyn-run() {
    cd /workspaces/dynamo/examples/llm
    dynamo serve graphs.agg:Frontend -f ./configs/agg.yaml
}

function dyn-debug() {
    cd /workspaces/dynamo/examples/llm
    RS_DEBUG_START_UP=1 dynamo serve graphs.agg:Frontend -f ./configs/agg.yaml
}

function dyn-curl() {
    curl http://0.0.0.0:8000/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d '{
            "model": "DeepSeek-R1-Distill-Llama-70B",
            "messages": [{"role": "user", "content": "How to learn swimming"}],
            "max_tokens": 128,
            "temperature": 0
        }'
}
EOF

echo "Development environment setup complete!"