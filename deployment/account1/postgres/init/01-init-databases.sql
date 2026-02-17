-- PostgreSQL init script for Account 1 primary
-- Creates databases for all active-active services
-- Runs automatically on first container start

-- Vaultwarden
CREATE DATABASE vaultwarden;
GRANT ALL PRIVILEGES ON DATABASE vaultwarden TO atn;

-- Nextcloud
CREATE DATABASE nextcloud;
GRANT ALL PRIVILEGES ON DATABASE nextcloud TO atn;

-- Immich (needs pgvecto.rs extension)
CREATE DATABASE immich;
GRANT ALL PRIVILEGES ON DATABASE immich TO atn;
\c immich
CREATE EXTENSION IF NOT EXISTS vectors;
CREATE EXTENSION IF NOT EXISTS earthdistance CASCADE;

-- Paperless
CREATE DATABASE paperless;
GRANT ALL PRIVILEGES ON DATABASE paperless TO atn;

-- Linkwarden
CREATE DATABASE linkwarden;
GRANT ALL PRIVILEGES ON DATABASE linkwarden TO atn;

-- Replication user (for Accounts 2+3 streaming replicas)
CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD 'CHANGE_ME_REPLICATOR_PASSWORD';
