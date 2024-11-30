path_add() {
  local dir=$1
  if [[ -d $dir && ! $PATH =~ (^|:)$dir(:|$) ]]; then
    export PATH=$dir:$PATH
  fi
}