cmd_version() {
  echo 'v0.1'
}

cmd_description() {
  cat << _EOF
=================================================================
= pass-keybase: Re-encrypt and decrypt pass entries via keybase =
=                                                               =
=                           v0.1                                =
=                                                               =
=           https://github.com/mbauhardt/pass-keybase           =
=================================================================
_EOF
}

cmd_help() {
  cmd_description
  echo
  cat << _EOF
Usage:
  pass keybase help
    Show this help text
  pass keybase version
    Show the version
  pass keybase encrypt pass-name
    Decrypt the give pass-name via gpg and encrypt it with keybase under the same path but with extension '.keybase'
_EOF
}

set_keybase_recipients() {
  KEYBASE_RECIPIENTS=( )
  local kbid="$PREFIX/.extensions/keybase-id"
  if [[ ! -f $kbid ]]; then
    cat << _EOF
      Error: You must run '$PROGRAM keybase init keybase-id...' before you want to use the password store keybase extension.
_EOF
      exit 1
  fi
  local keybase_user
  while read -r keybase_user; do
      KEYBASE_RECIPIENTS+=( "$keybase_user" )
  done < "$kbid"
}

cmd_encrypt() {
  set_keybase_recipients
  local path="$1"
  local passfile="$PREFIX/$path.gpg"
  local keybasefile="$PREFIX/$path.keybase"
  check_sneaky_paths "$path"

  if [[ -f $passfile ]]; then
    $GPG -d "${GPG_OPTS[@]}" "$passfile" | keybase encrypt ${KEYBASE_RECIPIENTS[@]} -o $keybasefile
    set_git "$keybasefile"
    git_add_file "$keybasefile" "Encrypt $path via keybase"
  elif [[ -z $path ]]; then
    die ""
  else
    die "Error: $path is not in the password store."
fi
}

case "$1" in
  help)
    cmd_help
    ;;
  version)
    cmd_version
    ;;
  encrypt)
    shift;
    cmd_encrypt "$@"
    ;;
  *)
    cmd_help
    ;;
esac
exit 0