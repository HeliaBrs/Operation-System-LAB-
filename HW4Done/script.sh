#!/bin/bash

PASS_FILE="$1"
UNZIP_DIR="unzipped_files"
mkdir -p "$UNZIP_DIR"

extract_password() {
  local line="$1"
  echo "$line" | grep -oP "(?<=<).{8,20}(?=>)"
}
while IFS= read -r line; do
  # Extract the filename prefix
  filename=$(echo "$line" | grep -oP "^test[123]")

  if [[ -n "$filename" ]]; then
    # Extract the password part (between < >)
    password=$(extract_password "$line")

    if [[ -n "$password" ]]; then
      echo "Processing file: $filename.zip with password: $password"

      if [[ -f "$filename.zip" ]]; then
        # Unzip the file using the extracted password
        unzip -P "$password" "$filename.zip" -d "$UNZIP_DIR/$filename"
      else
        echo "Zip file does not exist: $filename.zip"
      fi
    fi
  fi
done < "$PASS_FILE"


delete non txt files 
find "$UNZIP_DIR" -type f ! -name "*.txt" -delete

Step 5: Categorize txt Files
for txt_file in $(find "$UNZIP_DIR" -type f -name "*.txt"); do
  first_letter=$(basename "$txt_file" | cut -c1 | tr '[:upper:]' '[:lower:]')
  dest_dir="$UNZIP_DIR/$first_letter"
  mkdir -p "$dest_dir"
  mv "$txt_file" "$dest_dir"
done

