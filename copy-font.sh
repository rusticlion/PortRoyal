#\!/bin/bash
if [ \! -d ~/.local/share/love/PortRoyal/fonts ]; then
  mkdir -p ~/.local/share/love/PortRoyal/fonts
fi

# Copy the font to LÖVE's save directory
cp /Users/russell/PortRoyal/assets/fonts/alagard.ttf ~/.local/share/love/PortRoyal/fonts/

echo "Font copied to LÖVE save directory."
