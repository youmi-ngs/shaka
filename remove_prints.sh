#!/bin/bash

# Create backup
echo "Creating backup..."
cp -r /Users/youmi/Desktop/Shaka/Shaka /Users/youmi/Desktop/Shaka/Shaka_backup_$(date +%Y%m%d_%H%M%S)

# Remove all print statements from Swift files
echo "Removing print statements..."
find /Users/youmi/Desktop/Shaka/Shaka -name "*.swift" -exec sed -i '' '/^[[:space:]]*print(/d' {} \;

echo "Done! All print statements have been removed."
echo "Backup created in Shaka_backup_* directory"