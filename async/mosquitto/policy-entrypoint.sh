#!/bin/sh
# Starts Mosquitto with the dynamic security plugin and the demo accounts.
# Accounts only: what each account may do comes from the broker policy that
# broker-policy-deployer applies (until then, every topic is denied).
set -e

ADMIN="${BROKER_ADMIN_USER:-policy-admin}"
ADMIN_PW="${BROKER_ADMIN_PASSWORD:-policy-admin-pw}"
DYNSEC=/mosquitto/data/dynamic-security.json
# (stderr dropped: mosquitto_ctrl warns about plain MQTT on every call)
ctrl() { mosquitto_ctrl -u "$ADMIN" -P "$ADMIN_PW" dynsec "$@" 2>/dev/null; }

FRESH=false
if [ ! -f "$DYNSEC" ]; then
  mosquitto_ctrl dynsec init "$DYNSEC" "$ADMIN" "$ADMIN_PW" >/dev/null
  chown mosquitto:mosquitto "$DYNSEC"
  chmod 0700 "$DYNSEC"
  FRESH=true
fi

mosquitto -c /mosquitto/config/mosquitto.conf &
PID=$!
trap 'kill -TERM $PID; wait $PID; exit 0' TERM INT

if [ "$FRESH" = true ]; then
  until ctrl listClients >/dev/null 2>&1; do sleep 0.5; done
  # Deny by default: no publishing, no subscribing without a policy grant.
  ctrl setDefaultACLAccess publishClientSend deny
  ctrl setDefaultACLAccess subscribe deny
  ctrl setDefaultACLAccess publishClientReceive allow
  ctrl setDefaultACLAccess unsubscribe allow
  # Demo accounts (user:password), named after catalog components.
  grep -v '^#' /mosquitto/config/users.txt | grep ':' | while IFS=: read -r user pw; do
    ctrl createClient "$user" -p "$pw" >/dev/null && echo "account $user created"
  done
fi

wait "$PID"
