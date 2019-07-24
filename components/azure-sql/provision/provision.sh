#!/bin/bash
function run_sqlcmd {
  /opt/mssql-tools/bin/sqlcmd -e -b -S "$SQL_SERVER_NAME.database.windows.net" -d "$SQL_DATABASE_NAME" -U serveradmin -P "$SQL_ADMIN_PASS" "$@"
}

run_sqlcmd -Q "CREATE TABLE IF NOT EXISTS sqlprovision(script nvarchar(4000))"
for provisioning_script in /sqlprovision/*.sql; do
  echo -n "[$provisioning_script] "
  already_run=$(run_sqlcmd -Q "SELECT count(*) FROM sqlprovision WHERE script='$(basename $provisioning_script)'")
  if [ "$already_run" == "0" ]; then
    echo "running sqlcmd"
    run_sqlcmd -i /sqlprovision/provision.sql
  else
    echo "already run"
  fi
done
