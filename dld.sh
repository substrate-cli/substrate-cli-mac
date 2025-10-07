#!/bin/bash

# Use first argument as target directory, default to ./gen if not provided
BASE_DIR="${1:-./gen}"
mkdir -p "$BASE_DIR"

# Get the list of projects inside the container
PROJECTS=$(docker exec consumer-service ls /apps/substrate-home)

for project in $PROJECTS; do
  SRC="/apps/substrate-home/$project"
  DEST="$BASE_DIR/$project"

  # If a folder with the same name exists, append a number to avoid overwriting
  count=1
  while [ -d "$DEST" ]; do
    DEST="$BASE_DIR/${project}_$count"
    count=$((count + 1))
  done

  # Copy the project
  docker cp "consumer-service:$SRC" "$DEST"
  echo "Copied $project to $DEST"
done
