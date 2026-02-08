#!/bin/sh

# Ensure we are in a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: Not inside a git repository."
    exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
HOOKS_SOURCE_DIR="$REPO_ROOT/.githooks"

# Get the git hooks directory (might be relative or absolute)
GIT_HOOKS_REL=$(git rev-parse --git-path hooks)
mkdir -p "$GIT_HOOKS_REL"

# Resolve to absolute paths using cd and pwd -P (physical path, no symlinks)
GIT_HOOKS_DIR=$(cd "$GIT_HOOKS_REL" && pwd -P)
ABS_HOOKS_SOURCE_DIR=$(cd "$HOOKS_SOURCE_DIR" && pwd -P)

if [ ! -d "$HOOKS_SOURCE_DIR" ]; then
    echo "Error: $HOOKS_SOURCE_DIR directory not found."
    exit 1
fi

echo "Setting up git hooks..."

# Function to compute relative path from $1 (source) to $2 (target)
compute_relative_path() {
    source=$1
    target=$2

    common_part=$source
    back=""

    while [ "${target#$common_part}" = "${target}" ]; do
        common_part=$(dirname "$common_part")
        back="../$back"
    done

    # If common_part is just "/", we need to handle it carefully
    if [ "$common_part" = "/" ]; then
        result=""
    fi

    forward_part="${target#$common_part/}"

    if [ "$forward_part" = "$target" ]; then
        echo "${back}${target#/}"
    else
        echo "${back}${forward_part}"
    fi
}

# Improved function to compute relative path
relpath() {
    source=$1
    target=$2

    common_part=$source
    result=""

    while [ "${target#$common_part/}" = "${target}" ] && [ "$common_part" != "/" ]; do
        common_part=$(dirname "$common_part")
        result="../$result"
    done

    if [ "$common_part" = "/" ]; then
        if [ "${target#/}" = "$target" ]; then
             # No common root
             echo "$target"
             return
        fi
    fi

    forward_part="${target#$common_part/}"
    echo "${result}${forward_part}"
}

REL_PATH=$(relpath "$GIT_HOOKS_DIR" "$ABS_HOOKS_SOURCE_DIR")


# Loop through files in .githooks
for hook_path in "$HOOKS_SOURCE_DIR"/*; do
    # Skip if not a regular file
    [ -f "$hook_path" ] || continue

    hook_name=$(basename "$hook_path")
    target="$GIT_HOOKS_DIR/$hook_name"
    
    # Create relative symlink
    ln -sf "$REL_PATH/$hook_name" "$target"
    
    # Make the source script executable
    chmod +x "$hook_path"
    
    echo "Linked $hook_name -> $target (points to $REL_PATH/$hook_name)"
done

echo "Git hooks set up successfully."
