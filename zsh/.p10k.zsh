# Powerlevel10k config scaffold for Monkey.Dots.
# Run `p10k configure` to regenerate this file with your preferences.
# Until then, this is a minimal but usable default that matches the
# "monkey" palette (yellow #F5A524, mauve #C792EA).

# Temporarily change options.
'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob

  # Unset all configuration options.
  unset -m '(POWERLEVEL9K_*|DEFAULT_USER)~POWERLEVEL9K_GITSTATUS_DIR'

  # Zsh >= 5.1 is required.
  autoload -Uz is-at-least && is-at-least 5.1 || return

  # Prompt segments.
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    os_icon
    context
    dir
    vcs
    prompt_char
  )
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
    status
    command_execution_time
    time
    background_jobs
  )

  # Basic style.
  typeset -g POWERLEVEL9K_BACKGROUND=
  typeset -g POWERLEVEL9K_{LEFT,RIGHT}_PROMPT_FIRST_SEGMENT_START_SYMBOL=
  typeset -g POWERLEVEL9K_{LEFT,RIGHT}_PROMPT_LAST_SEGMENT_END_SYMBOL=
  typeset -g POWERLEVEL9K_{LEFT,RIGHT}_PROMPT_SEPARATE_LINE=
  typeset -g POWERLEVEL9K_{LEFT,RIGHT}_PROMPT_LENGTH_MIN=0

  # Monkey palette accents.
  typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND='#7FB4CA'
  typeset -g POWERLEVEL9K_DIR_FOREGROUND='#7FB4CA'
  typeset -g POWERLEVEL9K_VCS_FOREGROUND='#C792EA'
  typeset -g POWERLEVEL9K_TIME_FOREGROUND='#5C6170'
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND='#F5A524'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIINS_FOREGROUND='#B7CC85'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VICMD_FOREGROUND='#E0C15A'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_VIINS_FOREGROUND='#CB7C94'

  function prompt_my_username() {
    p10k segment -f '#7FB4CA' -t "$USERNAME"
  }
  function instant_prompt_my_username() { p10k display -r '' }

  typeset -g POWERLEVEL9K_CONTEXT_{DEFAULT,SUDO}_CONTENT_EXPANSION='%F{#7FB4CA}%n%f'

  # Instant prompt.
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=verbose
  typeset -g POWERLEVEL9K_DISABLE_HOT_RELOAD=true
}

# Tell `p10k configure` to use this file.
(( ! $+functions[p10k] )) || p10k reload
