#!/usr/bin/env bash

PROGRAM_NAME="rbxstudio"
REPOSITORY="horsenuggets/rbxstudio-cli"
INSTALL_DIR="$HOME/.rbxstudio-cli"
BIN_DIR="$INSTALL_DIR/bin"

set -eo pipefail

# Make sure we have all the necessary commands available
dependencies=(
    curl
    uname
    tr
)

for dep in "${dependencies[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "The command \"$dep\" is not installed or available." >&2
        exit 1
    fi
done

# Let the user know their access token was detected, if provided
if [ -n "$GITHUB_PAT" ]; then
    echo "Using the provided GITHUB_PAT for authentication."
fi

# Determine OS and architecture for the current system
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$OS" in
    darwin) OS="macos" ;;
    linux) OS="linux" ;;
    *)
        echo "The operating system \"$OS\" is not supported." >&2
        exit 1 ;;
esac

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64) ARCH="x86_64" ;;
    x86-64) ARCH="x86_64" ;;
    arm64) ARCH="aarch64" ;;
    aarch64) ARCH="aarch64" ;;
    *)
        echo "The architecture \"$ARCH\" is not supported." >&2
        exit 1 ;;
esac

# Determine the API URL based on whether a version was specified
API_URL="https://api.github.com/repos/$REPOSITORY/releases/latest"
if [ -n "$1" ]; then
    API_URL="https://api.github.com/repos/$REPOSITORY/releases/tags/$1"
    printf "\n[1 / 4] Looking for $PROGRAM_NAME release with tag \"$1\".\n"
else
    printf "\n[1 / 4] Looking for the latest $PROGRAM_NAME release.\n"
fi

# Build the binary name pattern
BINARY_NAME="${PROGRAM_NAME}-${OS}-${ARCH}"

# Fetch release data from GitHub API
if [ -n "$GITHUB_PAT" ]; then
    RELEASE_JSON_DATA=$(curl --proto '=https' --tlsv1.2 -sSf "$API_URL" \
        -H "X-GitHub-Api-Version: 2022-11-28" -H "Authorization: token $GITHUB_PAT")
else
    RELEASE_JSON_DATA=$(curl --proto '=https' --tlsv1.2 -sSf "$API_URL" \
        -H "X-GitHub-Api-Version: 2022-11-28")
fi

# Check if the release was fetched successfully
if [ -z "$RELEASE_JSON_DATA" ] || [[ "$RELEASE_JSON_DATA" == *"Not Found"* ]]; then
    echo "The release was not found. Please check your network connection." >&2
    exit 1
fi

# Extract the version tag
VERSION=""
while IFS= read -r current_line; do
    if [[ "$current_line" == *'"tag_name":'* ]]; then
        VERSION="${current_line#*\": \"}"
        VERSION="${VERSION%%\"*}"
        break
    fi
done <<< "$RELEASE_JSON_DATA"

if [ -z "$VERSION" ]; then
    echo "Failed to determine the version from the release." >&2
    exit 1
fi

echo "Found version $VERSION."

# Extract the download URL
DOWNLOAD_URL=""
while IFS= read -r current_line; do
    if [[ "$current_line" == *'"browser_download_url":'* ]]; then
        if [[ "$current_line" == *"$BINARY_NAME"* ]]; then
            DOWNLOAD_URL="${current_line#*\": \"}"
            DOWNLOAD_URL="${DOWNLOAD_URL%%\"*}"
            break
        fi
    fi
done <<< "$RELEASE_JSON_DATA"

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Failed to find the binary \"$BINARY_NAME\" in the release." >&2
    exit 1
fi

# Create installation directory
echo "[2 / 4] Creating installation directory."
mkdir -p "$BIN_DIR"

# Download the binary
echo "[3 / 4] Downloading \"$BINARY_NAME\"."
BIN_DEST="$BIN_DIR/$PROGRAM_NAME"
if [ -n "$GITHUB_PAT" ]; then
    curl --proto '=https' --tlsv1.2 -L -o "$BIN_DEST" -sSf "$DOWNLOAD_URL" \
        -H "Authorization: token $GITHUB_PAT"
else
    curl --proto '=https' --tlsv1.2 -L -o "$BIN_DEST" -sSf "$DOWNLOAD_URL"
fi

if [ ! -f "$BIN_DEST" ] || [ ! -s "$BIN_DEST" ]; then
    echo "Failed to download the binary." >&2
    rm -f "$BIN_DEST"
    exit 1
fi
chmod +x "$BIN_DEST"

# Configure PATH
printf "[4 / 4] Configuring PATH.\n\n"

PATH_EXPORT_COMMENT="# Added by rbxstudio-cli"
PATH_EXPORT_LINE="export PATH=\"$BIN_DIR:\$PATH\""

add_to_path() {
    local config_file="$1"
    local config_path="$HOME/$config_file"

    # Check if already configured
    if [ -f "$config_path" ] && grep -q "$BIN_DIR" "$config_path"; then
        echo "PATH already configured in $config_file."
        return 0
    fi

    # Add to config file
    if [ -f "$config_path" ]; then
        echo "" >> "$config_path"
    fi
    echo "$PATH_EXPORT_COMMENT" >> "$config_path"
    echo "$PATH_EXPORT_LINE" >> "$config_path"
    echo "Added $BIN_DIR to PATH in $config_file."
    return 1
}

PATH_CONFIGURED=false

# Check for xsh
if [ -d "$HOME/.xsh" ]; then
    XSH_PATH_FILE="$HOME/.path"
    if [ -f "$XSH_PATH_FILE" ] && grep -q "$BIN_DIR" "$XSH_PATH_FILE"; then
        echo "PATH already configured in ~/.path."
        PATH_CONFIGURED=true
    else
        echo "$BIN_DIR" >> "$XSH_PATH_FILE"
        echo "Added $BIN_DIR to PATH in ~/.path."
    fi
else
    # Try common shell config files
    for config_file in .zshrc .bashrc .bash_profile; do
        if [ -f "$HOME/$config_file" ]; then
            if add_to_path "$config_file"; then
                PATH_CONFIGURED=true
            fi
            break
        fi
    done

    # If no config file found, create one
    if [ ! -f "$HOME/.zshrc" ] && [ ! -f "$HOME/.bashrc" ] && [ ! -f "$HOME/.bash_profile" ]; then
        if [ "$(uname -s)" = "Darwin" ]; then
            add_to_path ".zshrc"
        else
            add_to_path ".bashrc"
        fi
    fi
fi

# Print success message
echo ""
echo "Installation complete!"
echo ""
echo "Installed version $VERSION."
echo "Binary at $BIN_DEST."

if [ "$PATH_CONFIGURED" = false ]; then
    echo ""
    echo "Restart your terminal or run the following to use rbxstudio:"
    echo "  source ~/.zshrc  # or your shell's config file"
fi
