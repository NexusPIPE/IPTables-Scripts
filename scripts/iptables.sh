#!/bin/bash
# Copyright (c) NexusPIPE. Licensed under the GPL License.

# ANSI Escape Code
ESCAPE='\033';
PREFIX="${ESCAPE}[0;33mNexus${ESCAPE}[0;1;33mPIPE ${ESCAPE}[0;37mIPTables: ${ESCAPE}[0m";

# Logs
error() {
  echo -e "${PREFIX}${ESCAPE}[0;31m$@${ESCAPE}[0m"
}
info() {
  echo -e "${PREFIX}${ESCAPE}[0;34m$@${ESCAPE}[0m"
}
success() {
  echo -e "${PREFIX}${ESCAPE}[0;32m$@${ESCAPE}[0m"
}

# handle rules file
if [[ "$RULES_FILE" != "" ]]; then
  rm -f "$RULES_FILE";
  echo -e "#!/bin/sh\n# Copyright (c) NexusPIPE. Licensed under the GPL License.\n# Generated on $(date)\nset -e\nset -x" >> "$RULES_FILE";
fi;

# IPTables Wrapper
ipt() {
  echo -e "${PREFIX}${ESCAPE}[0;35mapply rule: $@";
  if [[ "$RULES_FILE" != "" ]]; then
    echo iptables $@ >> "$RULES_FILE";
  elif [[ "$DRY" == "false" ]]; then
    sudo iptables $@;
  fi;
}

# Proc Start/Stop
start() {
  info "Start \"$@\""
}
finish() {
  finish_quiet $@;
  success "Completed \"$@\""
}
finish_quiet() {
  if [[ "$?" != "0" ]]; then
    error "Failed \"$@\"";
    exit 1;
  fi
}

# Drop all rules
dropRules() {
  start Drop IPTables Rules;
  ipt -F;
  finish Drop IPTables Rules;
}

# Add whitelist rules
applyIps() {
  start Whitelist Nexus IPs
  # Fetch the file
  wget -qO- https://cf-ent-cache.nexuspipe.com/static/EDGE-IPS.txt | while read -r ip; do
    # Add the iptables rule for each IP
    ip=$(echo "$ip" | sed -e 's/[[:space:]]*$//')
    ipt -A INPUT -s "${ip}" -j ACCEPT
    finish_quiet Add IPTables Rule for "$ip";
  done
  if [[ "$NO_SET_LOCALHOST" == "" ]]; then
    ipt -A INPUT -s "127.0.0.1" -j ACCEPT
  fi;
  finish Whitelist Nexus IPs
}

# Specify conntrack rules
specifyConntrack() {
  ipt -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT;
  finish Set Conntrack Rule;
}

specifyAccept() {
  ipt -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT;
  ipt -A OUTPUT -m state --state NEW -j ACCEPT;
  finish Set Accept rules;
}

specifyPorts() {
  for arg in "$@"; do
    ipt -A INPUT -p tcp --dport "$arg" -j DROP;
  done
}

# execute
if [[ "$RULES_FILE" != "" && "$DRY" != "false" ]]; then >&2 echo -e "${PREFIX}WARN: Running in dry mode. No changes will be applied."; fi
set -e
if [[ "$NO_DROP_RULES" != "true" ]]; then
  dropRules;
fi;
applyIps;
specifyConntrack;
specifyAccept;
if [[ "$@" != "" ]]; then specifyPorts "$@"; else specifyPorts 80 443 8080 3000; fi;
set +e
if [[ "$RULES_FILE" != "" ]]; then >&2 echo -e "${PREFIX}WARN: This ran in file mode. No changes were actually applied.\n${PREFIX}WARN: When running this file, you MUST run as root, and MUST save rules after they're applied, e.g. via iptables-save | tee /etc/iptables.conf"
elif [[ "$DRY" != "false" ]]; then >&2 echo -e "${PREFIX}WARN: This ran in dry mode. No changes were actually applied.\n${PREFIX}WARN: To apply rules, pass DRY=true to env\n${PREFIX}WARN: Alternatively specify a RULES_FILE alongside DRY=false to instead write rules as commands to that file.";
else >&2 echo -e "${PREFIX}It is STRONGLY recommended to run something like 'iptables-save | tee /etc/iptables.conf' to save the rules permanently. This command can vary based on distribution."; fi;
