#!/bin/sh
set -e

# Repository Configuration
OWNER="erswapnil"
REPO="kubectl-cnp-diagnostic"
# This MUST start with kubectl- to be recognized as a plugin
BINARY="kubectl-edbdiag"

# No-sudo by design: on many corporate-managed Macs, invoking `sudo` triggers
# an MDM/endpoint-security elevation prompt (e.g. a GUI "Launch with elevated
# privileges" dialog) that never surfaces properly through a piped
# `curl | sudo sh` install, leaving the install permanently stuck with no
# output and no visible prompt. To avoid that entirely, this script never
# calls sudo. It installs into the current user's own bin directory instead
# of a system path that requires root.
TARGET_USER="$(whoami)"
TARGET_HOME=$(eval echo "~${TARGET_USER}")
INSTALL_PATH="${TARGET_HOME}/.local/bin"
mkdir -p "$INSTALL_PATH"

echo "Installing $BINARY from $OWNER/$REPO..."

# 1. Fetch the tool via `git clone` rather than curl-ing
#    raw.githubusercontent.com directly. Some corporate SSL-inspecting
#    proxies (e.g. Netskope) block or silently hang on direct
#    raw.githubusercontent.com requests - with or without HTTP/2 - while
#    git's smart-HTTP protocol against github.com itself goes through fine.
#    --depth 1 keeps this fast and avoids pulling full history.
if ! command -v git >/dev/null 2>&1; then
    echo "git is required to install this plugin. Please install git and re-run." >&2
    exit 1
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

git clone --depth 1 --quiet "https://github.com/$OWNER/$REPO.git" "$TMP_DIR/$REPO"

if [ ! -f "$TMP_DIR/$REPO/$BINARY" ]; then
    echo "Could not find $BINARY in the cloned repository." >&2
    exit 1
fi

cp "$TMP_DIR/$REPO/$BINARY" "./$BINARY"

# 2. Make it executable
chmod +x "$BINARY"

# 3. Move into the user's own bin directory - no sudo, no elevation prompt.
mv "$BINARY" "$INSTALL_PATH/"

# 4. Make sure $INSTALL_PATH is actually on PATH so both `kubectl edbdiag`
#    (plugin form) and a bare `kubectl-edbdiag` (direct form) work without
#    typing the full path.

case ":${PATH}:" in
    *":${INSTALL_PATH}:"*)
        # Already on PATH for this session - nothing to do.
        ;;
    *)
        USER_SHELL_NAME=$(basename "${SHELL:-/bin/bash}")
        case "$USER_SHELL_NAME" in
            zsh)  SHELL_RC="${TARGET_HOME}/.zshrc" ;;
            bash)
                if [ -f "${TARGET_HOME}/.bash_profile" ]; then
                    SHELL_RC="${TARGET_HOME}/.bash_profile"
                else
                    SHELL_RC="${TARGET_HOME}/.bashrc"
                fi
                ;;
            *) SHELL_RC="${TARGET_HOME}/.profile" ;;
        esac

        if [ -f "$SHELL_RC" ] && grep -qs "$INSTALL_PATH" "$SHELL_RC" 2>/dev/null; then
            : # already configured previously
        else
            echo "export PATH=\"${INSTALL_PATH}:\$PATH\"" >> "$SHELL_RC"
            echo "Added ${INSTALL_PATH} to PATH in ${SHELL_RC}."
            echo "Restart your terminal or run: source ${SHELL_RC}"
        fi
        ;;
esac

echo "Installation successful! Run it using: kubectl edbdiag  (or just: kubectl-edbdiag)"
