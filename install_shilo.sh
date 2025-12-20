
# update ubuntu operating system
sudo apt update && sudo apt upgrade -y

# install unity hub
wget -qO - https://hub.unity3d.com/linux/keys/public | gpg --dearmor | sudo tee /usr/share/keyrings/Unity_Technologies_ApS.gpg > /dev/null
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/Unity_Technologies_ApS.gpg] https://hub.unity3d.com/linux/repos/deb stable main" > /etc/apt/sources.list.d/unityhub.list'

sudo apt update
sudo apt install -y unityhub

sudo apt install -y ffmpeg python3 python3-venv python3-pip
python -m venv whisper_env
source whisper_env/bin/activate
pip install -U openai-whisper
