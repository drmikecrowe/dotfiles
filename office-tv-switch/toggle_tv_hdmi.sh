#!/bin/bash
# Switch office monitor HDMI input via Home Assistant webhook.
# Invoked by udev through systemd-run, detached from the udev cgroup.
#
# The placeholder below is substituted by install.sh from the machine-local
# chezmoi data key .officeTv.webhook. The real URL must never be committed:
# this repo is public and an HA webhook ID is an unauthenticated credential.
INPUT=$1

CODE=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" \
     -X POST -H "Content-Type: application/json" \
     -d "{\"input\":\"$INPUT\"}" \
     @WEBHOOK_URL@)

# Goes to the transient unit's journal so we can verify it reached HA.
echo "tv-hdmi: input=$INPUT http=$CODE curl_exit=$?"
