#!/bin/sh
# Copyright (c) NexusPIPE. Licensed under the GPL License.

# exit on error
set -e

# output commands
set -x

# defaults
export DRY=${DRY:-false}
export RULES_FILE=${RULES_FILE:-""}

# execute stuff
date=$(date +%Y-%m-%d);
curl -o "nexus-${date}.sh" https://docs.nexuspipe.com/apply-rules/iptables.sh;
sh "nexus-${date}.sh" $@;
rm "nexus-${date}.sh";
