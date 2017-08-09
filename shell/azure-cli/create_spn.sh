#!/bin/sh
subscription="OSTC Shanghai Dev"
# azure login
azure account set "$subscription"
azure account list --json
