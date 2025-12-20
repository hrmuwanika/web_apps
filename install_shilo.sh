#!/bin/bash

# update ubuntu operating system
sudo apt update && sudo apt upgrade -y

sudo apt install software-properties-common -y
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt update -y

sudo apt install -y python3 python3-venv python3-pip ffmpeg

mkdir whisper_env
python -m venv whisper_env
source whisper_env/bin/activate
pip install -U openai-whisper

# install unity hub
wget -qO - https://hub.unity3d.com/linux/keys/public | gpg --dearmor | sudo tee /usr/share/keyrings/Unity_Technologies_ApS.gpg > /dev/null
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/Unity_Technologies_ApS.gpg] https://hub.unity3d.com/linux/repos/deb stable main" > /etc/apt/sources.list.d/unityhub.list'

sudo apt update
sudo apt install -y unityhub

# Install ollama
curl -fsSL https://ollama.com/install.sh | sudo sh
sudo systemctl enable ollama
sudo systemctl status ollama

ollama pull gemma2:2b
ollama pull DeepseekV2
ollama pull embeddinggemma
ollama run gemma2:2b
