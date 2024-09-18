#
# micromamba
#
# touch a '.envrc' file in your project directory and insert the following code in it:
# layout micromamba <your-environment-name>

layout_micromamba() {
  # adjust the target to your installation of the BINARY micromamba
  export MAMBA_EXE="${HOME}/.local/bin/micromamba"
  # adjust the target to the installation prefix
  export MAMBA_ROOT_PREFIX="${HOME}/micromamba"
  # find the shell in use
  local my_shell=$(basename ${SHELL})
  local env_name="$1"
  __mamba_setup="$("${MAMBA_EXE}" shell hook --shell "${my_shell}" --root-prefix "${MAMBA_ROOT_PREFIX}" 2> /dev/null)"

  eval " ${__mamba_setup}"

  if [ -n "$1" ]; then
    # Explicit environment name from layout command
    # DO NOT USE $MAMBA_EXE , instead the shell function 'micromamba' which got generated after '__mamba_setup'.
    micromamba activate ${env_name}

  elif (grep -q name: environment.yml); then
    # Detect environment name from `environment.yml` file in `.envrc` directory
    micromamba activate $(grep name: environment.yml | sed -e 's/name: //')

  else
    (>&2 echo No environment specified);
    exit 1;

  fi;

  unset __mamba_setup

}
