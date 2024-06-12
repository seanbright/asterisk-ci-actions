#!/usr/bin/bash

set -x

ulimit -a

sysctl kernel.core_pattern

cat <<EOF > ~/.pgpass
*:*:*:postgres:postgres
*:*:*:asterisk:asterisk
EOF

chmod go-rwx ~/.pgpass
export PGPASSFILE=~/.pgpass
createuser -h postgres -w --username=postgres -RDIElS asterisk
createdb -h postgres -w --username=postgres -E UTF-8 -O asterisk asterisk
psql -U postgres -h postgres -w -l

exit 0
