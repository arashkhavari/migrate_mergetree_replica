#!/bin/bash

OUTDIR=.
db_url=source.database.url
dest_url=destination.database.url
db_pass=source.password
cluster=cluster.name
clickhouse-client -h $db_url --password $db_pass -q "SHOW DATABASES" | while read -r db ; do
  clickhouse-client -h $db_url --password $db_pass -q "SHOW TABLES FROM $db" | while read -r table ; do
  repl_path="ReplicatedMergeTree(zookeeper.path)"
  if [ "$db" == "system" ]; then
     continue 2;
  fi
  if [[ "$table" == ".inner."* ]]; then
     continue;
  fi
  clickhouse-client -h $db_url --password $db_pass -q "SHOW CREATE TABLE ${db}.${table}" > "${OUTDIR}/${db}_${table}_schema.sql"
  clickhouse-client -h $db_url --password $db_pass -q "SELECT * FROM ${db}.${table} FORMAT Native" > "${OUTDIR}/${db}_${table}_data"
  clickhouse-client -h $dest_url -q "CREATE DATABASE IF NOT EXISTS ${db} ON CLUSTER ${cluster}"
  sed -i 's/'"${db}.${table}"'/'"${db}.${table} ON CLUSTER ${cluster}"'/g' "${OUTDIR}/${db}_${table}_schema.sql"
  sed -i 's|MergeTree|'"${repl_path}"'|g' "${OUTDIR}/${db}_${table}_schema.sql"
  clickhouse-client -h $dest_url < "${OUTDIR}/${db}_${table}_schema.sql"
  clickhouse-client -h $dest_url -q "CREATE TABLE ${db}.${table}_cluster ON CLUSTER ${cluster} AS ${db}.${table} ENGINE = Distributed(${cluster},${db},${table},rand())"
  clickhouse-client -h $dest_url -q "INSERT INTO ${db}.${table}_cluster FORMAT Native" < "${OUTDIR}/${db}_${table}_data"
  done
done

