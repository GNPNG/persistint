# Tiered forge: development tier on srv, archive tier on the NAS

Why: on 2026-10-24 the NAS Gitea (Docker, Synology, Atom CPU, 4 GB) stalled every push for over an
hour during a Btrfs scrub while reads kept answering. Active repositories move to a Gitea running
natively in an LXD container on srv; the NAS instance stays as the backup tier and receives a push
mirror from srv; the public GitHub mirror is pushed from srv directly so the NAS is never in the
critical path.

Pieces:

- `provision.sh`: run on srv. Launches the `gitea` LXD container, installs the pinned Gitea binary
  (sha256-verified), writes `/etc/gitea/app.ini` for PostgreSQL on the existing database server,
  enables the systemd unit, adds LXD proxy devices for HTTP and the built-in SSH port, creates the
  admin and service accounts (passwords printed once). Re-runnable.
- `nginx-forge.conf`: the HTTPS front on the NAS nginx (certificates stay on the NAS; the container
  is plain HTTP on the LAN), with the body-size and timeout settings git needs.
- `migrate-repo.sh`: mirror-clone from the NAS, mirror-push to srv (branches, tags, `refs/dolt/*`
  for beads), verify ref lists, print the remote, beads and mirror follow-ups.

The author supplies: the PostgreSQL host and a `gitea` role (`CREATE ROLE gitea LOGIN PASSWORD '...';
CREATE DATABASE gitea OWNER gitea ENCODING 'UTF8' TEMPLATE template0;` plus a `pg_hba.conf` line for
the container's address), the DNS name for the new tier (default `forge.gnomatix.com`; on the LAN the wildcard already lands on
the NAS proxy, which forwards to srv), and the proxy rule from `nginx-forge.conf`. LAN side is trusted
by design: HTTP between proxy and container, private networks allowed for migrations, mirrors and
webhooks, database connection without TLS.
Database and configuration backups: `gitea dump` nightly to a NAS share (cron inside the container).
