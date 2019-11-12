
# Install temporarily to pull in all runtime dependencies
apt install diffoscope
apt remove diffoscope

# Install more current version via pip
pip3 install diffoscope
export PATH="$HOME/.local/bin:$PATH"
