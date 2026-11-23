# Recording terminal setup. Source it in the terminal you record:
#   demo shell   (or: source ~/projekty/devops-api-governance/scripts/demo/demo-shell.sh)
# Short prompt with the current branch, so viewers always see where you are,
# and a pager that only kicks in for output longer than the screen.
# DEMO_SHELL_REPO=kafka puts you in the Kafka clone instead (the Kafka steps).
if [ -f /usr/share/git-core/contrib/completion/git-prompt.sh ]; then
  . /usr/share/git-core/contrib/completion/git-prompt.sh
elif [ -f /usr/lib/git-core/git-sh-prompt ]; then
  . /usr/lib/git-core/git-sh-prompt
fi
_demo_name=orders
[ "${DEMO_SHELL_REPO:-}" = kafka ] && _demo_name=order-events-kafka
if type __git_ps1 >/dev/null 2>&1; then
  PS1='\[\e[1;36m\]'"$_demo_name"'\[\e[0m\]$(__git_ps1 " \[\e[1;33m\](%s)\[\e[0m\]") \$ '
else
  PS1='\[\e[1;36m\]'"$_demo_name"'\[\e[0m\] \$ '
fi
export GIT_PAGER='less -FRX'
if [ "${DEMO_SHELL_REPO:-}" = kafka ]; then
  cd "${DEMO_KAFKA_CLONE:-$HOME/demo/order-events-kafka-api}" 2>/dev/null || echo "Kafka demo clone not found; run: demo goto kafka"
else
  cd "${DEMO_CLONE:-$HOME/demo/orders-api}" 2>/dev/null || echo "demo clone not found; run: demo goto 1"
fi
unset _demo_name
clear
