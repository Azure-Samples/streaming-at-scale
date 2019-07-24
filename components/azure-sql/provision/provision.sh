#!/bin/bash

set -euo pipefail

function run_sqlcmd {
  /opt/mssql-tools/bin/sqlcmd -b -h-1 -S "$SQL_SERVER_NAME.database.windows.net" -d "$SQL_DATABASE_NAME" -U serveradmin -P "$SQL_ADMIN_PASS" "$@"
}

run_sqlcmd -e -Q "IF OBJECT_ID(N'sqlprovision', N'U') IS NULL CREATE TABLE sqlprovision(script nvarchar(4000))"
for provisioning_script in /sqlprovision/*.sql; do
  echo -n "[$provisioning_script] "
  script_name=$(basename $provisioning_script)
  already_run=$(run_sqlcmd -Q "SET NOCOUNT ON SELECT count(*) FROM sqlprovision WHERE script='$script_name'")
    echo "runout: [$already_run]"
  if [ "$already_run" -eq "0" ]; then
    echo "running sqlcmd"
    run_sqlcmd -e -i /sqlprovision/provision.sql
    run_sqlcmd -e -Q "INSERT INTO sqlprovision VALUES ('$script_name')"
  else
    echo "already run"
  fi
done
