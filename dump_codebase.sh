#!/bin/bash

# dump_codebase.sh
# Script to dump the entire codebase into a single organized file

OUTPUT_FILE="codebase_dump.md"

echo "# PortRoyal Codebase Dump" > $OUTPUT_FILE
echo "Generated: $(date)" >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# Function to add a file to the output
add_file() {
  local file=$1
  local rel_path=${file#"$(pwd)/"}
  
  echo "## $rel_path" >> $OUTPUT_FILE
  echo '```lua' >> $OUTPUT_FILE
  cat "$file" >> $OUTPUT_FILE
  echo '```' >> $OUTPUT_FILE
  echo "" >> $OUTPUT_FILE
}

# Function to add documentation files (markdown)
add_doc_file() {
  local file=$1
  local rel_path=${file#"$(pwd)/"}
  
  echo "## $rel_path" >> $OUTPUT_FILE
  echo "$(cat "$file")" >> $OUTPUT_FILE
  echo "" >> $OUTPUT_FILE
}

echo "# Source Code" >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# Add Lua source files
for file in $(find src -name "*.lua" -type f | sort); do
  add_file "$file"
done

echo "# Documentation" >> $OUTPUT_FILE
echo "" >> $OUTPUT_FILE

# Add documentation files
for file in $(find docs -name "*.md" -type f | sort); do
  add_doc_file "$file"
done

# Add design documents
for file in $(find . -maxdepth 1 -name "*.md" -type f | sort); do
  add_doc_file "$file"
done

# Add tickets
for file in $(find Tickets -name "*.md" -type f | sort); do
  add_doc_file "$file"
done

echo "Codebase successfully dumped to $OUTPUT_FILE"