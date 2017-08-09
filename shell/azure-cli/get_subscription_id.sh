#!/bin/sh
subscription_name="OSTC Shanghai Dev"
azure account list --json | python -c "import json,sys;obj=json.load(sys.stdin);n=[x for x in obj if x['name']=='$subscription_name'];print n[0]['id'];"
