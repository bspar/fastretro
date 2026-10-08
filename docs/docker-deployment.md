## Deploying with Docker

Build this privacy-hardened fork from source:

```sh
docker build -t bspar-fastretro:local .
```

Do not use the upstream `ghcr.io/jangocg/fastretro` image: it lacks this fork's privacy patches. Read [Private self-hosting](private-self-hosting.md) before deployment. To run the app, you need Docker, persistent storage and explicit private hostname/mail settings.

### Mounting a storage volume

This fork defaults to local uploads and keeps its SQLite databases and uploads inside `/rails/storage`. Selecting `ACTIVE_STORAGE_SERVICE=s3` explicitly moves attachments to the configured object-storage service; those need separate backups.
By default Docker containers don't persist storage between runs, so you'll want to mount a persistent volume into that location.

The simplest way to do this is with the `--volume` flag with `docker run`. For example:

```sh
docker run --volume fastretro:/rails/storage bspar-fastretro:local
```

That will create a named volume (called `fastretro`) and mount it into the correct path.
Docker will manage where that volume is actually stored on your server.

You can also specify the data location yourself, mount a network drive, and more.
Check the Docker documentation to find out more about what's available.

### Configuring with environment variables

To configure your Fast Retro installation, you can use environment variables.
Fast Retro has several of them.
At a minimum configure `SECRET_KEY_BASE`, `APP_HOST`, `MAILER_FROM_ADDRESS` and `SMTP_ADDRESS`. Set `SAAS=false` explicitly and use an internal SMTP server if email must stay private. `SITE_FEEDBACK_EMAIL` optionally enables feedback to your own support mailbox.

#### Secret Key Base

Various features inside Fast Retro rely on cryptography to work (such as secure links).
To set this up, you need to provide a secret value that will be used as the basis of those secrets.
This value can be anything, but it should be unguessable, and specific to your instance.

You can use any long random string for this, or you can have the Fast Retro codebase generate one for you by running:

```sh
bin/rails secret
```

Once you have one, set it in the `SECRET_KEY_BASE` environment variable:

```sh
docker run --env SECRET_KEY_BASE=abcdefabcdef ...
```

#### SSL

If you want the Fast Retro container to handle its own SSL automatically, you just need to specify the domain name that you're running it on.
Automatic TLS contacts a public ACME service. For VPN-only hosting, prefer a private TLS-terminating proxy and leave `TLS_DOMAIN` unset.
You can do that with the `TLS_DOMAIN` environment variable.
Note that if you're using SSL, you'll want to allow traffic on ports 80 and 443.
So if you were running on `retro.example.com` you could enable SSL like this:

```sh
docker run --publish 80:80 --publish 443:443 --env TLS_DOMAIN=retro.example.com ...
```

If you are terminating SSL in some other proxy in front of Fast Retro, then you don't need to set `TLS_DOMAIN`, and can just publish port 80:

```sh
docker run --publish 127.0.0.1:8080:80 ...
```

If you aren't using SSL at all (for example, if you want to run it locally on your laptop) then you should specify `DISABLE_SSL=true` instead:

```sh
docker run --publish 127.0.0.1:8080:80 --env DISABLE_SSL=true ...
```

#### SMTP Email

Fast Retro needs to be able to send email for its magic link sign in flow.
Use an internal SMTP server for private hosting. A third-party email provider receives recipients, login codes and message bodies. Configure the selected server with:

- `MAILER_FROM_ADDRESS` - the "from" address that Fast Retro should use to send email
- `SMTP_ADDRESS` - the address of the SMTP server you'll send through
- `SMTP_PORT` - the port number (defaults to 465 when `SMTP_TLS` is set, 587 otherwise)
- `SMTP_USERNAME`/`SMTP_PASSWORD` - the credentials for logging in to the SMTP server

Less commonly, you might also need to set some of the following:

- `SMTP_TLS` - set to `true` only for servers requiring implicit TLS (SMTPS on port 465); STARTTLS is used automatically by default so most servers don't need this
- `SMTP_DOMAIN` - the domain name advertised to the server when connecting
- `SMTP_AUTHENTICATION` - if you need an authentication method other than the default `plain` (e.g., `login` for AWS SES)
- `SMTP_SSL_VERIFY_MODE` - set to `none` to skip certificate verification (for self-signed certs)

You can find out more about all these settings in the [Rails Action Mailer documentation](https://guides.rubyonrails.org/action_mailer_basics.html#action-mailer-configuration).

##### Example: AWS SES

If you're using AWS SES, your configuration would look like this:

```sh
SMTP_ADDRESS=email-smtp.eu-central-1.amazonaws.com
SMTP_USERNAME=<your-ses-smtp-username>
SMTP_PASSWORD=<your-ses-smtp-password>
SMTP_AUTHENTICATION=login
MAILER_FROM_ADDRESS=support@yourdomain.com
```

**Important:** AWS SES SMTP credentials are different from your IAM access keys. You need to generate them separately in the AWS SES Console under "SMTP Settings" > "Create SMTP Credentials".

#### Multi-tenant mode

By default, when you run the Fast Retro Docker image you'll be limited to creating a single account (although that account can have as many users as you like).
This is for convenience: typically when you self-host you'll be running a single account, so in this mode new account signups are automatically disabled as soon as you've created your first account.

If you do want to allow multiple accounts to be created in your instance, set `MULTI_TENANT=true`.

#### Background jobs

Fast Retro uses Solid Queue for background job processing. By default, jobs run in the same process as the web server. You can control this with:

- `SOLID_QUEUE_IN_PUMA` - set to `true` to run background jobs in the app container (recommended for simple deployments)

## Example

Here's an example of a `docker-compose.yml` that you could use to run Fast Retro via `docker compose up`:

```yaml
services:
  web:
    build: .
    image: bspar-fastretro:local
    restart: unless-stopped
    ports:
      - "127.0.0.1:8080:80"
    environment:
      - SECRET_KEY_BASE=your-secret-key-base
      - SAAS=false
      - SKIP_TELEMETRY=true
      - APP_HOST=retro.internal.example
      - MAILER_FROM_ADDRESS=retro@internal.example
      - SMTP_ADDRESS=mail.internal.example
      - SMTP_USERNAME=your-smtp-username
      - SMTP_PASSWORD=your-smtp-password
      - SOLID_QUEUE_IN_PUMA=true
    volumes:
      - fastretro:/rails/storage

volumes:
  fastretro:
```

Replace the placeholder values with your actual configuration before running.
Run this example from the repository root, behind a private TLS-terminating proxy. Back up the storage volume and preserve `SECRET_KEY_BASE` before upgrades. This example does not install an egress firewall; enforce permitted destinations separately.
