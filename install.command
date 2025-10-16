#!/bin/bash
cd "$(dirname "$0")"

# Remove quarantine from subs2.command
xattr -d com.apple.quarantine subs2.command 2>/dev/null
chmod +x subs2.command

echo "✓ Setup complete!"
echo "You can now double-click subs2.command to run it."
read -p "Press Enter to close..."