# Fast Retro

This is a privacy-hardened self-hosting fork of [JangoCG/fastretro](https://github.com/JangoCG/fastretro), a tool for team retrospectives.

## Private self-hosting defaults

- No third-party analytics, including in production.
- Local uploads and SQLite databases in `storage/` by default.
- Remote GIF links remain links; CSP blocks remote images, fonts and media unless explicitly allowed.
- Feedback/support is disabled unless `SITE_FEEDBACK_EMAIL` is configured for the instance operator.
- Production email requires explicit `APP_HOST`, `MAILER_FROM_ADDRESS` and `SMTP_ADDRESS` settings; no upstream mail destinations are used.
- Stripe endpoints/pricing and Sentry initialization are disabled outside SaaS mode.

See [Private self-hosting](docs/private-self-hosting.md) for configuration, remaining outbound capabilities and validation.


## Running your own Fast Retro instance

If you want to run your own Fast Retro instance, you can use Docker or deploy with Kamal.

### Docker

For a single-box deployment with a local login-email inbox, use the included
`compose.yaml` and [Compose deployment guide](docs/compose-deployment.md).

For trusted VPN/LAN use, opt into [name-only signup and recovery tokens](docs/name-only-authentication.md)
with `NAME_ONLY_AUTH=true`. Email authentication remains the default.

Build this fork from source with `docker build -t bspar-fastretro:local .`. The upstream `ghcr.io/jangocg/fastretro` image does **not** contain these patches. See the [Docker deployment guide](docs/docker-deployment.md).

### Kamal

The [Kamal deployment guide](docs/kamal-deployment.md) is retained as an upstream reference. This checkout does not include `config/deploy.yml`; prepare your own private-host configuration rather than assuming that guide is ready to run.


## Development

Please see our [Development guide](docs/development.md) for how to get Fast Retro set up for local development.


## Contributing

We welcome contributions!


## License

Fast Retro is released under the [O'Saasy License](LICENSE.md).
