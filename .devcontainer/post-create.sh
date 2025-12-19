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
  if ! grep -q 'iterm2_shell_integration.zsh' "$ZSHRC_FILE" 2> /dev/null; then
    cat >> "$ZSHRC_FILE" << 'EOF'
  PROMPT_EOL_MARK=""
  test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
  precmd() { print -Pn "\e]133;D;%?\a" }
  preexec() { print -Pn "\e]133;C;\a" }
EOF
  fi

  # Reload zsh rc in an interactive shell to apply changes
  zsh -i -c "source ~/.zshrc" || true
}

install_tools() {
  npm i -g husky prettier markdownlint-cli @commitlint/cli @commitlint/config-angular lint-staged
  npx husky
  bash scripts/install-tools.sh dev
}

configure_git_editor
configure_iterm2_zsh
install_tools
chmod +x ./bin/*
