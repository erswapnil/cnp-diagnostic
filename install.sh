#!/bin/sh
set -e

# Repository Configuration
OWNER="erswapnil"
REPO="cnp-diagnostic"
# This MUST start with kubectl- to be recognized as a plugin
BINARY="kubectl-edbdiag"
INSTALL_PATH="/usr/local/bin"

echo "Installing $BINARY from $OWNER/$REPO..."

# 1. Download the tool (Ensure the file on GitHub is named kubectl-edbdiag)
curl -sSfL "https://raw.githubusercontent.com/$OWNER/$REPO/main/$BINARY" -o "$BINARY"

# 2. Make it executable
chmod +x "$BINARY"

# 3. Move to system path
if [ -w "$INSTALL_PATH" ]; then
    mv "$BINARY" "$INSTALL_PATH/"
else
    sudo mv "$BINARY" "$INSTALL_PATH/"
fi

# 4. Make sure $INSTALL_PATH is actually on PATH so both `kubectl edbdiag`
#    (plugin form) and a bare `kubectl-edbdiag` (direct form) work without
#    typing the full /usr/local/bin path.
#
#    This script is typically run as `curl ... | sudo sh`, which means $HOME
#    would resolve to root's home, not the real user's - so resolve the
#    invoking user explicitly via $SUDO_USER when present.
TARGET_USER="${SUDO_USER:-$(whoami)}"
TARGET_HOME=$(eval echo "~${TARGET_USER}")

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
            [ "$(id -u)" = "0" ] && [ -n "${SUDO_USER:-}" ] && chown "$SUDO_USER" "$SHELL_RC" 2>/dev/null || true
            echo "Added ${INSTALL_PATH} to PATH in ${SHELL_RC}."
            echo "Restart your terminal or run: source ${SHELL_RC}"
        fi
        ;;
esac

echo "Installation successful! Run it using: kubectl edbdiag  (or just: kubectl-edbdiag)"
