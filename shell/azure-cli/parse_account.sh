#!/bin/sh

azure account list --json | python -c 'import json,sys;obj=json.load(sys.stdin);print obj[0]["name"]'  ## extract name
n=\"name\"
azure account list --json | python -c "import json,sys;obj=json.load(sys.stdin);print obj[0][$n]"  ## extract name
