# Recording terminal setup. Source it in the terminal you record:
#   source ~/projekty/devops-api-governance/scripts/demo/demo-shell.sh
# Short prompt with the current branch, so viewers always see where you are,
# and a pager that only kicks in for output longer than the screen.
if [ -f /usr/share/git-core/contrib/completion/git-prompt.sh ]; then
  . /usr/share/git-core/contrib/completion/git-prompt.sh
fi
if type __git_ps1 >/dev/null 2>&1; then
  PS1='\[\e[1;36m\]orders-api\[\e[0m\]$(__git_ps1 " \[\e[1;33m\](%s)\[\e[0m\]") \$ '
else
  PS1='\[\e[1;36m\]orders-api\[\e[0m\] \$ '
fi
export GIT_PAGER='less -FRX'
cd "${DEMO_CLONE:-$HOME/demo/orders-api}" 2>/dev/null || echo "demo clone not found; run prep-stage.sh goto 1 first"
clear
