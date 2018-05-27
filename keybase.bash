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
  pass init keybase-id...
    Setup pass-keybase and creates a config file (.extensions/keybase-id) with keybase usernames.
    The parameter 'keybase-id...' is a space separated list of keybase usernames.
  pass keybase encrypt pass-name
    Decrypt the give pass-name via gpg and encrypt it with keybase under the same path but with extension '.keybase'
  pass decrypt pass-name
    Decrypt the given pass-name with keybase.
  pass clip pass-name
    Decrypt the given pass-name with keybase and put it on the clipboard.
    The clipboard will be cleared in $CLIP_TIME seconds.
  pass keybase remove pass-name
    Remove the given pass-name from the store.
  pass keybase remove-all
    Remove all pass-names from the store.
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
    git_add_file "$keybasefile" "Encrypt $path via keybase for user: ${KEYBASE_RECIPIENTS[@]}"
  elif [[ -z $path ]]; then
    die ""
  else
    die "Error: $path is not in the password store."
  fi
}

cmd_init() {
  printf "%s\n" "$@" > $PREFIX/.extensions/keybase-id
}

cmd_remove() {
  local path="$1"
  local passfile="$PREFIX/$path.keybase"
  check_sneaky_paths "$path"

  if [[ -f $passfile ]]; then
    set_git "$passfile"
    rm "$passfile"
    git -C "$INNER_GIT_DIR" rm -qr "$passfile"
    set_git "$passfile"
    git_commit "Remove $path from store."
  elif [[ -z $path ]]; then
    die ""
  else
    die "Error: $path is not in the password store."
  fi
}

cmd_remove_all() {
  while read -r -d "" passfile; do
    git -C "$INNER_GIT_DIR" rm -qr "$passfile"
    set_git "$passfile"
  done < <(find $PREFIX -iname '*.keybase' -print0)
  git_commit "Remove all keybase files from store."
}

cmd_decrypt() {
  local path="$1"
  local passfile="$PREFIX/$path.keybase"
  check_sneaky_paths "$path"

  if [[ -f $passfile ]]; then
    keybase decrypt -i "$passfile" 
  elif [[ -z $path ]]; then
    die ""
  else
    die "Error: $path is not in the password store."
  fi
}

cmd_clip() {
  local path="$1"
  local passfile="$PREFIX/$path.keybase"
  check_sneaky_paths "$path"

  if [[ -f $passfile ]]; then
      local pass="$(keybase decrypt -i "$passfile" 2>/dev/null | head -n 1)"
      clip "$pass" "$path"
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
  init)
    shift;
    cmd_init "$@"
    ;;
  encrypt)
    shift;
    cmd_encrypt "$@"
    ;;
  decrypt)
    shift;
    cmd_decrypt "$@"
    ;;
  clip)
    shift;
    cmd_clip "$@"
    ;;
  remove)
    shift;
    cmd_remove "$@"
    ;;
  remove-all)
    cmd_remove_all
    ;;
  *)
    cmd_help
    ;;
esac
exit 0
