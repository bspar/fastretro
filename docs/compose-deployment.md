# Single-box private deployment

`compose.yaml` runs FastRetro, a local Mailpit inbox, and an unprivileged Nginx
ingress proxy. No MinIO, PostgreSQL or Redis is needed: uploads, SQLite databases
and mail have persistent named volumes.
The default web binding is loopback. The app and Mailpit share only an internal
Docker network, with no outbound route and no public DNS resolver configured.
The proxy joins a separate ingress bridge so Docker can publish host ports; it
has network egress capability, but its configuration routes only to these two
local backends and has no external integrations. The app and inbox do not join
that bridge. Mailpit update checks, SMTP reverse-DNS lookups, remote CSS/fonts,
and external forwarding are disabled or unconfigured. An additional proxy CSP
also blocks remote images in the inbox. Docker image pulls/builds still require
network access before startup.

## Configure and start

Copy `.env.example` to `.env`, restrict it to your user (`chmod 600 .env`), and
generate a fresh `SECRET_KEY_BASE`, for example with `openssl rand -hex 64`.
Never commit or share `.env`. Set:

- `FASTRETRO_BIND_ADDRESS`: the intended private/VPN interface address; leave
  `127.0.0.1` for SSH-tunnel-only access. Do not use `0.0.0.0` accidentally.
- `FASTRETRO_PORT`: default `8080`.
- `APP_HOST`: the exact browser address including port, such as `10.0.0.2:8080`.
- `MAILER_FROM_ADDRESS`: your local sender address. No mail leaves Mailpit.

```sh
docker compose config --quiet
docker compose up -d --build --wait
docker compose ps
```

This Compose setup intentionally uses HTTP for a trusted private network.
Mail links follow that HTTP setting. Passkeys require a secure browser origin
(HTTPS, or localhost) and will not work at a plain HTTP private IP. Add a private
TLS proxy and change `DISABLE_SSL` to `false` before using this on a less trusted
network. Do not enable public ACME if external certificate requests are forbidden.

## Login through the local inbox

For a trusted-network deployment without email, set `NAME_ONLY_AUTH=true` in
`.env` and follow [name-only authentication](name-only-authentication.md) instead.
Facilitators save a recovery token and invitees enter a display name. Mailpit can
remain running but is not used by name-only authentication.

Mailpit's UI is **only** published at `127.0.0.1:8025`; SMTP is not published.
From your workstation:

```sh
ssh -N -L 8025:127.0.0.1:8025 bspar@YOUR_PRIVATE_HOST
```

Open `http://localhost:8025`, request a sign-in/sign-up code in FastRetro, and read
it in Mailpit. Anyone with inbox access can read all users' codes and messages;
this is a pilot/development-style login setup, not separate private inboxes.
Mail is retained for at most seven days and 500 messages. There is no SMTP
forwarding or relaying. The proxy adds an intersecting CSP to block remote images
that stock Mailpit would otherwise allow; use this published inbox endpoint, not
the backend container directly.

The app uses unauthenticated SMTP on this isolated network. For an authenticated
relay later, set `SMTP_USERNAME`, `SMTP_PASSWORD`, and its required TLS settings;
authentication defaults to `plain` when a username is supplied.

Feedback remains disabled. Jira, Sentry, Stripe, public object storage, automatic
TLS, and CSP remote-source allowances are not enabled by this Compose file.

## Operations and persistence

```sh
docker compose logs --tail 100 web
docker compose stop
docker compose start --wait
```

Logs may contain sensitive operational information. Do not publish unredacted
logs or `docker compose config` output (the latter contains the secret); use
`config --quiet` when validating.

Persistent data is in `fastretro_storage` and `fastretro_mail`. Preserve `.env`
and `SECRET_KEY_BASE` across restarts and upgrades. `docker compose down` preserves
volumes; **do not use `down -v`** unless intentionally destroying the instance.
Back up quiesced volumes, or use SQLite-aware backups that include WAL state.
No backup schedule is installed by this Compose file.

Before upgrades, back up, review the new commit, rebuild, and use
`docker compose up -d --build --wait`. Startup may run database migrations.
