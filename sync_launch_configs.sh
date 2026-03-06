#!/bin/bash

# --- Path Configuration ---
# Directory containing IntelliJ/Golan .run.xml files
XML_DIR="$HOME/development/urbancompass/src/go/compass.com/lead_common/leads-platform/project_configuration"
# Target path for the VS Code launch configuration
LAUNCH_FILE="$HOME/development/urbancompass/.vscode/launch.local.json"

# Ensure the .vscode directory exists
mkdir -p "$(dirname "$LAUNCH_FILE")"

# Create a temporary file for JSON array construction
TEMP_JSON=$(mktemp)
echo "[" > "$TEMP_JSON"

count=0
for xml_file in "$XML_DIR"/*.run.xml; do
    # Skip if no .run.xml files are found
    [ -e "$xml_file" ] || continue
    
    # Add a comma and newline if this is not the first configuration block
    if [ "$count" -gt 0 ]; then
        echo "," >> "$TEMP_JSON"
    fi

    # 1. Extract the 'name' attribute from the <configuration> tag
    # Logic: Find lines containing <configuration, then extract text between name=" and the next quote
    NAME=$(sed -n '/<configuration /s/.*name="\([^"]*\)".*/\1/p' "$xml_file" | head -1)

    # 2. Extract the Blaze Target and convert it to a local relative path
    # Logic: Strip leading // and the trailing :target_name
    RAW_TARGET=$(sed -n 's/.*<blaze-target>\([^<]*\)<\/blaze-target>.*/\1/p' "$xml_file")
    PROGRAM="./$(echo "$RAW_TARGET" | sed 's|^//||; s|:[^:]*$||')/"

    # 3. Extract execution flags (Args) and format them for a JSON array
    # Logic: Indent each flag and add a comma, then strip the comma from the last item
    ARGS_BLOCK=$(sed -n 's/.*<blaze-user-exe-flag>\([^<]*\)<\/blaze-user-exe-flag>.*/        "\1",/p' "$xml_file" | sed '$s/,$//')

    # Use printf to output the JSON block with strict formatting
    printf '    {
      "name": "%s",
      "type": "go",
      "request": "launch",
      "mode": "auto",
      "program": "%s",
      "args": [
%s
      ],
      "env": {}
    }' "$NAME" "$PROGRAM" "$ARGS_BLOCK" >> "$TEMP_JSON"

    ((count++))
    echo "Parsed: $NAME"
done

# Close the JSON array
echo "" >> "$TEMP_JSON"
echo "]" >> "$TEMP_JSON"

# Generate the final launch.local.json file
cat <<EOF > "$LAUNCH_FILE"
{
  "version": "0.2.0",
  "configurations": $(cat "$TEMP_JSON")
}
EOF

# Clean up the temporary file
rm "$TEMP_JSON"

echo "-----------------------------------------------"
echo "Success! $count configurations written to $LAUNCH_FILE"
echo "-----------------------------------------------"
