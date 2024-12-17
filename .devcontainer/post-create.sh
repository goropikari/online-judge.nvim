#!/bin/bash

set -e

python3 -m venv ~/venv
~/venv/bin/pip install git+https://github.com/online-judge-tools/oj@v12.0.0
~/venv/bin/pip install debugpy==1.8.11
echo 'source ~/venv/bin/activate' >> ~/.bashrc
