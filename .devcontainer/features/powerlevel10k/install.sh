#!/bin/bash

set -e

CONFIG=${CONFIG}
VERSION=${VERSION:-'latest'}
DELETE_PREINSTALL_THEMES=${DELETEPREINSTALLEDTHEMES:-false}
DEBUG=${DEBUG:-false}

debug() {
  if [[ ${DEBUG} == true ]]; then
    echo "$1" >> /tmp/powerlevel10k.log
  fi
}

if [[ -n ${_REMOTE_USER_HOME} ]]; then
  USER_HOME="${_REMOTE_USER_HOME}"
elif [[ ${_REMOTE_USER} == "root" ]]; then
  USER_HOME="/root"
# Check if user already has a home directory other than /home/${USERNAME}
elif [[ "/home/${_REMOTE_USER}" != $(getent passwd "${_REMOTE_USER}" | cut -d: -f6) ]]; then
  USER_HOME=$(getent passwd "${_REMOTE_USER}" | cut -d: -f6)
else
  USER_HOME="/home/${_REMOTE_USER}"
fi

if [[ ${VERSION} == "latest" ]]; then
  VERSION=$(curl --silent "https://api.github.com/repos/romkatv/powerlevel10k/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
fi

debug "==============================="
debug "VERSION: ${VERSION}"
debug "CONFIG: ${CONFIG}"
debug "REMOTE_USER: ${_REMOTE_USER}"
debug "USER_HOME: ${USER_HOME}"
debug "==============================="

if [[ ${DELETE_PREINSTALL_THEMES} == true ]]; then
  debug "Deleting other themes"
  rm -rf "${USER_HOME}"/.oh-my-zsh/themes/*
fi

curl -L https://github.com/romkatv/powerlevel10k/archive/refs/tags/v"${VERSION}".zip -o /tmp/powerlevel10k.zip
unzip /tmp/powerlevel10k.zip -d /tmp
cp -r /tmp/powerlevel10k-"${VERSION}" "${USER_HOME}"/.oh-my-zsh/custom/themes/powerlevel10k
rm -rf /tmp/powerlevel10k.zip /tmp/powerlevel10k-"${VERSION}"
sed -i 's/ZSH_THEME=".*"/ZSH_THEME="powerlevel10k\/powerlevel10k"/g' "${USER_HOME}/.zshrc"
echo 'source ~/.oh-my-zsh/custom/themes/powerlevel10k/powerlevel10k.zsh-theme' >> "${USER_HOME}/.zshrc"
echo '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh' >> "${USER_HOME}/.zshrc"

if [[ -z "${CONFIG}" ]]; then
  cat > "${USER_HOME}/.p10k.zsh" << 'P10K_ZSH'
'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob
  unset -m '(POWERLEVEL9K_*|DEFAULT_USER)~POWERLEVEL9K_GITSTATUS_DIR'
  # Zsh >= 5.1 is required.
  [[ $ZSH_VERSION == (5.<1->*|<6->.*) ]] || return
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir vcs)
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=()
  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_last
  typeset -g POWERLEVEL9K_DISABLE_HOT_RELOAD=true
  (( ! $+functions[p10k] )) || p10k reload
}
typeset -g POWERLEVEL9K_CONFIG_FILE=${${(%):-%x}:a}
(( ${#p10k_config_opts} )) && setopt ${p10k_config_opts[@]}
'builtin' 'unset' 'p10k_config_opts'
P10K_ZSH
else
  curl -L "${CONFIG}" -o "${USER_HOME}/.p10k.zsh"
fi
