#!/bin/bash

echo "🎨 Installing AI Art Gallery with Analytics..."
echo "=============================================="

# Update system
sudo apt update && sudo apt upgrade -y

# Install Python and dependencies
sudo apt install -y python3.10 python3.10-venv python3-pip python3-dev
sudo apt install -y ffmpeg git wget curl build-essential
sudo apt install -y libsndfile1 portaudio19-dev

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


# Create project directory
mkdir -p ~/art_gallery_ubuntu/backend
cd ~/art_gallery_ubuntu/backend

# Create virtual environment
python3.10 -m venv venv
source venv/bin/activate

# Install Python packages
pip install --upgrade pip
pip install -r requirements.txt

# Download Whisper model
python3 -c "import whisper; whisper.load_model('base')"

# Create directories
mkdir -p uploads audio_responses logs analytics_cache vector_cache

# Create sample artworks if not exists
if [ ! -f "artworks.json" ]; then
    cat > artworks.json << 'EOF'
[
  {
    "id": 1,
    "title": "Starry Night",
    "artist": "Vincent van Gogh",
    "year": 1889,
    "style": "Post-Impressionism",
    "description": "A famous painting of a night sky with swirling stars...",
    "gallery_location": "Gallery A, Wall 1"
  },
  {
    "id": 2,
    "title": "Mona Lisa",
    "artist": "Leonardo da Vinci",
    "year": 1503,
    "style": "Renaissance",
    "description": "The famous portrait with a mysterious smile...",
    "gallery_location": "Gallery B, Wall 2"
  }
]
EOF
fi

echo "✅ Installation complete!"
echo ""
echo "To start the system:"
echo "1. Terminal 1: ollama serve"
echo "2. Terminal 2: cd ~/art_gallery_ubuntu/backend && ./start_services.sh"
echo "3. Open browser: http://localhost:5000"
echo "4. Open Unity project and connect"
