# Source from ~/.bashrc (`demo install` adds the line): defines the `demo`
# command with tab completion. It is a shell function so that `demo shell` can
# set up the current terminal (prompt, cd into the clone).
_DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

demo() {
  if [ "${1:-}" = shell ]; then
    # shellcheck source=demo-shell.sh
    . "$_DEMO_DIR/demo-shell.sh"
  else
    "$_DEMO_DIR/demo" "$@"
  fi
}

_demo_complete() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  if [ "$COMP_CWORD" -eq 1 ]; then
    local cmds="next status preflight goto reset fresh refresh-catalog shell install help stage1 stage2 stage2-red stage3 stage3-red stage4 stage5 stage5-red"
    # Recording helpers are local-only, not part of the repo.
    [ -x "$_DEMO_DIR/rehearse.sh" ] && cmds="$cmds rehearse"
    [ -x "$_DEMO_DIR/video.sh" ] && cmds="$cmds cards trim speed concat"
    COMPREPLY=($(compgen -W "$cmds" -- "$cur"))
    return
  fi
  case "${COMP_WORDS[1]}" in
    goto)  [ "$COMP_CWORD" -eq 2 ] && COMPREPLY=($(compgen -W "1 2 2-red 3 3-red 4 5 5-red end" -- "$cur")) ;;
    fresh) [ "$COMP_CWORD" -eq 2 ] && COMPREPLY=($(compgen -W "--yes" -- "$cur")) ;;
    cards|trim|speed|concat) COMPREPLY=($(compgen -f -- "$cur")) ;;
  esac
}
complete -o filenames -F _demo_complete demo
