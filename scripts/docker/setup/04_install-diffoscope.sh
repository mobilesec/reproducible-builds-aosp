
# Install temporarily to pull in all runtime dependencies
apt-get --assume-yes install diffoscope
apt-get --assume-yes remove diffoscope

# Install more current version via pip
pip3 install diffoscope
export PATH="$HOME/.local/bin:$PATH"
