#!/bin/sh

set -e

echo "##### Installing crimechase cli dependencies #####"
sudo apt-get update
sudo apt-get install libssl-dev

echo "##### Installing aptos cli #####"
if ! command -v aptos &>/dev/null; then
    echo "aptos could not be found"
    echo "installing it..."
    TARGET=Ubuntu-x86_64
    VERSION=2.4.0
    wget -qO- "https://aptos.dev/scripts/install_cli.py" | python3
else
    echo "aptos already installed"
fi

echo "##### Info #####"
./aptos info
