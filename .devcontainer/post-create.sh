#!/bin/sh

# Configure git to use vscode as default editor
configure_git_editor() {
  git config --global --unset-all core.editor || true
  git config --global core.editor "code --wait"
}

# Configure iTerm2 shell integration for Zsh to fix vscode ai-agent prompt issues
configure_iterm2_zsh() {
  ZSHRC_FILE="$HOME/.zshrc"
  ITERM_FILE="$HOME/.iterm2_shell_integration.zsh"

  curl -L https://iterm2.com/shell_integration/zsh -o "$ITERM_FILE" || true

  # Append integration only if not already present
  if ! grep -q 'iterm2_shell_integration.zsh' "$ZSHRC_FILE" 2>/dev/null; then
    cat >>"$ZSHRC_FILE" <<'EOF'
  PROMPT_EOL_MARK=""
  test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
  precmd() { print -Pn "\e]133;D;%?\a" }
  preexec() { print -Pn "\e]133;C;\a" }
EOF
  fi

  # Reload zsh rc in an interactive shell to apply changes
  zsh -i -c "source ~/.zshrc" || true
}

install_tools(){
  npm i -g husky
  husky
  bash scripts/install-tools.sh dev

  KUBESEAL_VERSION=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/tags | jq -r '.[0].name' | cut -c 2-)
  KUBESEAL_TGZ="/tmp/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
  KUBESEAL_URL="https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"

  # Download to /tmp, follow redirects, and wtmprite to the specified file
  curl -L -o "$KUBESEAL_TGZ" "$KUBESEAL_URL"

  # Extract the kubeseal binary from the archive into /tmp, install and cleanup
  (cd /tmp && tar -xvzf "$KUBESEAL_TGZ" kubeseal && sudo install -m 755 kubeseal /usr/local/bin/kubeseal)
  rm -f "$KUBESEAL_TGZ" /tmp/kubeseal || true
}

configure_git_editor
configure_iterm2_zsh
install_tools
