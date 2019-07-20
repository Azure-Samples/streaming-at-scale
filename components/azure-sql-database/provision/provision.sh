#!/bin/bash
/opt/mssql-tools/bin/sqlcmd -S "$SQL_SERVER_NAME.database.windows.net" -d "$SQL_DATABASE_NAME" -U serveradmin -P "$SQL_ADMIN_PASS" -i /sqlprovision/provision.sql
