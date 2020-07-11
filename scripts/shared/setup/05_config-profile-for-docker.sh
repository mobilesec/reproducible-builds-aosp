
# Setup the .profile file to include common local bin paths during startup
# Note that most standard full fledged distributions (e.g. Debian and Ubuntu) already have this in their .profile.
# This is aimed at Docker and other minimal environments which may fail in subsequent steps due to missing tools from $PATH
cat >> "$HOME/.profile" << 'EOF'

# set PATH so it includes user's private bin if it exists
if [ -d "${HOME}/bin" ] ; then
    PATH="${HOME}/bin:${PATH}"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "${HOME}/.local/bin" ] ; then
    PATH="${HOME}/.local/bin:${PATH}"
fi
EOF
