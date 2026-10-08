# Private self-hosting

This fork removes the upstream analytics script in every mode. `ANALYTICS=true`
cannot re-enable it. The existing layout hook intentionally returns no markup.
These patches are defaults and application guards, not a network sandbox or a
complete dependency audit.

## Required production settings

Use fresh secrets and configure your own destinations before deployment:

```dotenv
SAAS=false
SKIP_TELEMETRY=true
APP_HOST=retro.internal.example
MAILER_FROM_ADDRESS=retro@internal.example
SMTP_ADDRESS=mail.internal.example
SMTP_PORT=587
SOLID_QUEUE_IN_PUMA=true
```

Supply a strong `SECRET_KEY_BASE` separately. Production mail fails before
rendering or delivery if the hostname, sender or SMTP address is missing. There
is no fallback to `fastretro.app` or its support mailbox. Keep Sentry and Stripe
credentials unset even though both integrations are gated off in self-hosted
mode. Explicit `SAAS=false` also overrides an inherited `tmp/saas.txt` marker.

Magic-link login still requires email. Use an internal SMTP relay/mail sink and
restrict recipients there if mail must not leave your network. The relay receives
login codes, confirmation tokens and email contents. `SHOW_MAGIC_LINK_CODE` is
not a supported production substitute for mail.

Feedback and support links are disabled until `SITE_FEEDBACK_EMAIL` is set to
your own mailbox. The form shows that actual recipient. Submissions include the
message and the sender's name/email. Removing this setting also rejects direct
form requests. Queued messages have no upstream-recipient fallback.

## Storage and browser resources

The default `ACTIVE_STORAGE_SERVICE=local` stores attachments with the four
SQLite databases under `/rails/storage`. Mount a persistent volume writable by
container UID/GID `1000:1000`. Back up consistent SQLite snapshots (including
WAL state) and uploads; preserve your secrets. The entrypoint runs `db:prepare`
and may apply migrations during an upgrade.

To opt into private S3-compatible storage, set `ACTIVE_STORAGE_SERVICE=s3` and
configure `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_REGION`, `S3_BUCKET` and
`S3_ENDPOINT`. The endpoint must be reachable by both app and browser for direct
uploads, with appropriate CORS. Add **only that endpoint** to `CSP_CONNECT_SRC`
and, if needed for rendering, `CSP_IMG_SRC`/`CSP_MEDIA_SRC`. Back up its contents
separately. Selecting S3 without settings does not fall back to local storage.

GIF URLs remain clickable links, not automatically fetched images. Uploaded GIF
attachments still work. Default CSP permits only same-origin scripts,
connections, images, fonts and media, plus necessary inline `data:`/`blob:`
resources. Do not disable CSP or enable report-only mode. `DISABLE_CSP=false`
keeps enforcement enabled; only `true` disables it. Leave `CSP_REPORT_URI` unset
unless you control its destination.

## Remaining outbound capabilities

- Jira is an explicit per-account integration. Export sends action text, retro
  name, author and date to its configured endpoint. Leave it unconfigured or
  use an approved private Jira instance.
- Enabling SaaS mode can enable configured Stripe and Sentry integrations. It
  deliberately relaxes the self-hosted guards; it is not a privacy mode.
- SMTP and explicitly selected object storage contact operator-configured hosts.
- External links in upstream marketing/legal/blog content remain clickable;
  clicking them or support links is an explicit external interaction. Those
  upstream legal pages are not a deployment-specific privacy policy—replace
  them before presenting this instance to users.
- `TLS_DOMAIN` enables automatic certificate provisioning, which contacts an
  ACME service. Prefer a private proxy/certificate on a VPN and leave it unset.
- Build/update steps fetch Docker images, OS packages, Ruby gems and npm packages.
  This is distinct from runtime retrospective-data traffic.

Build this fork, not the upstream container image, and pin the reviewed commit or
your resulting image digest. Bind published ports to loopback or an intended VPN
interface. Enforce default-deny runtime egress with only approved internal
destinations. A server firewall cannot stop browsers fetching external resources;
the application changes and CSP protect that separate path. Treat logs and any
log forwarding as sensitive even with content/message/name parameter filtering.

## Validation before deployment

Run `bin/ci` and the production configuration check:

```sh
RAILS_ENV=production SAAS=false SECRET_KEY_BASE_DUMMY=1 bin/rails runner script/check_self_hosted_privacy.rb
```

`SECRET_KEY_BASE_DUMMY` is for this isolated check/build only, never a real server.
The check does not send email, start a listener or require S3. Also test actual
login, collaboration and attachment upload/download with browser network tools
and runtime egress logging. Expect only the instance origin and any explicitly
approved private services. This source-level regression coverage is not proof
that all dependencies or a deployment proxy are free of network behavior.
