# gfx shell status — tells the shell-status shader how the last long command
# ended. Source it from .zshrc; `gfx shell` shows the exact line.
#
# After a command that ran for GFX_STATUS_MIN seconds or more (default 10),
# palette slot 254 becomes rgb(228, 227, 229) on success or rgb(228, 227, 230)
# on failure: one step from its usual #e4e4e4, so nothing on screen changes.
# It stays until the next command starts. Ctrl-C and Ctrl-Z count as neither.

[[ -o interactive ]] || return 0
[[ $TERM_PROGRAM == ghostty || $TERM == xterm-ghostty ]] || return 0

zmodload zsh/datetime 2>/dev/null || return 0
autoload -Uz add-zsh-hook

typeset -g GFX_STATUS_MIN=${GFX_STATUS_MIN:-10}
typeset -g _gfx_status_start=''
typeset -g _gfx_status_set=init   # 'init': clear a stale state at the first prompt

_gfx_status_clear() {
  print -n -- $'\e]104;254\a'
  _gfx_status_set=''
}

_gfx_status_preexec() {
  _gfx_status_start=$EPOCHREALTIME
  [[ -n $_gfx_status_set ]] && _gfx_status_clear
}

_gfx_status_precmd() {
  local code=$?
  local state=0
  if [[ -n $_gfx_status_start ]]; then
    if (( EPOCHREALTIME - _gfx_status_start >= GFX_STATUS_MIN && code != 130 && code != 148 )); then
      state=$(( code == 0 ? 1 : 2 ))
    fi
    _gfx_status_start=''
  fi
  if (( state )); then
    printf '\e]4;254;rgb:e4/e3/%02x\a' $(( 228 + state ))
    _gfx_status_set=1
  elif [[ $_gfx_status_set == init ]]; then
    _gfx_status_clear
  fi
  return $code   # hand the exit status on to the prompt
}

add-zsh-hook preexec _gfx_status_preexec
# first in line, so it reads the command's own exit status
precmd_functions=(_gfx_status_precmd ${precmd_functions:#_gfx_status_precmd})
