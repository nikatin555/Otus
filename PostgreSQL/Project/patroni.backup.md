
#### Для spbsql1 (192.168.10.204):
```bash
sudo tee /etc/patroni.yml << 'EOF'
scope: postgres-cluster
namespace: /db/
name: spbsql1

log:
  level: INFO
  dir: /var/log/patroni

restapi:
  listen: 0.0.0.0:8008
  connect_address: 192.168.10.204:8008

etcd:
  hosts: 192.168.10.209:2379,192.168.10.211:2379,192.168.10.181:2379

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 33554432
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        max_connections: 100
        shared_buffers: 128MB
        wal_level: logical
        hot_standby: on
        wal_keep_size: 128MB
        max_wal_senders: 10
        max_replication_slots: 10
        password_encryption: scram-sha-256

  initdb:
  - encoding: UTF8
  - data-checksums

  pg_hba:
  - host replication replicator 192.168.10.0/24 scram-sha-256
  - host all all 192.168.10.0/24 scram-sha-256

  users:
    admindbps:
      password: "Keyjkbrbq64!"
      options:
        - createrole
        - createdb
        - login

postgresql:
  listen: 0.0.0.0:5432
  connect_address: 192.168.10.204:5432
  data_dir: /data/patroni
  bin_dir: /usr/pgsql-17/bin
  pgpass: /tmp/pgpass
  authentication:
    superuser:
      username: psqladmines
      password: "Keyjkbrbq99!"
    replication:
      username: spbrepadmines
      password: "Keyjkbrbq04!"

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: true
  nosync: false
EOF
```

#### Для spbsql2 (192.168.10.207) - аналогично, поменяйте IP и name.
```bash
sudo tee /etc/patroni.yml << 'EOF'
scope: postgres-cluster
namespace: /db/
name: spbsql1

log:
  level: INFO
  dir: /var/log/patroni

restapi:
  listen: 0.0.0.0:8008
  connect_address: 192.168.10.207:8008

etcd:
  hosts: 192.168.10.209:2379,192.168.10.211:2379,192.168.10.181:2379

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 33554432
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        max_connections: 100
        shared_buffers: 128MB
        wal_level: logical
        hot_standby: on
        wal_keep_size: 128MB
        max_wal_senders: 10
        max_replication_slots: 10
        password_encryption: scram-sha-256

  initdb:
  - encoding: UTF8
  - data-checksums

  pg_hba:
  - host replication replicator 192.168.10.0/24 scram-sha-256
  - host all all 192.168.10.0/24 scram-sha-256

  users:
    admin:
      password: "AdminPassword123!"
      options:
        - createrole
        - createdb

postgresql:
  listen: 0.0.0.0:5432
  connect_address: 192.168.10.204:5432
  data_dir: /data/patroni
  bin_dir: /usr/pgsql-17/bin
  pgpass: /tmp/pgpass
  authentication:
    superuser:
      username: psqladmines
      password: "Keyjkbrbq99!"
    replication:
      username: replicator
      password: "ReplicationPassword123!"

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: true
  nosync: false
EOF
```