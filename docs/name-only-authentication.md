# Name-only authentication on a trusted private network

Set `NAME_ONLY_AUTH=true` to use FastRetro without email verification. This is an
explicit self-hosting opt-in, ignored in SaaS mode. Email login is unchanged when
the setting is unset or false. Restart/rebuild after changing the configuration:

```sh
docker compose up -d --build --wait
```

## Create and join

- The home page offers **Create a new team** and recovery-token sign-in.
- The facilitator enters a display name to create a team. Save the recovery token
  shown immediately afterward, then continue into the app and create a retro.
- Share the retro's ordinary invite link. Each participant enters just a name
  and joins immediately. Team join links also support name-only entry.
- An existing signed-in browser keeps its identity when opening another invite.
  It is not necessary to sign up for a separate team to join a retro.

The normal users, account memberships, retro participants, roles, and signed
session cookies remain in use. New invitees are members/participants, never
automatically administrators. A matching display name does **not** select an
existing identity: names are labels, not passwords, and duplicates are possible.

## Returning users and recovery

The browser retains its signed session cookie. Clearing cookies, signing out,
using private browsing, or changing browsers requires a saved recovery token to
restore the same identity. Without one, participants must rejoin using an invite
and will become a new participant; their prior votes/content remain attributed
to the old identity. Do not create a new team just to rejoin an existing retro.

Facilitators receive a recovery token during team creation. Participants can
optionally generate one using **Profile → Recovery token**. Paste it into the
home page's **Restore an existing identity** form to recover access. Recovery
from an invite returns to that invite afterward.

Treat the token as a password: anyone who has it gains the identity's existing
permissions across all its teams. It is never put in an invite or URL. The server
stores a SHA-256 digest of a cryptographically random token; the plaintext is
shown once on an authenticated, non-cacheable page and is not recoverable later.
Token parameters are filtered from Rails logs. Store the token in your password
manager, not in a retrospective or shared chat.

You can generate a replacement while still signed in. This invalidates the old
token and revokes other browser sessions; the current session remains signed in.
If an owner loses both their cookie and token, there is no email reset or lookup
by name. An instance operator would need to perform a deliberate server-side
recovery. Keep the facilitator's token safe before signing out.

## Email and existing data

Identities receive unique internal `@name-only.invalid` addresses to preserve the
existing database relationships. These are not mailboxes and are hidden from
normal profile/member UI. They cannot receive app email even if name-only mode
is later disabled. Name-only mode suppresses all mail delivery, hides email
changes/feedback, and does not schedule retrospective reminder emails.

Mailpit is not needed for this mode. The supplied Compose stack retains it to
make switching back to email login easy; it remains localhost-only and isolated.

Existing email-based identities and all data are left intact, not converted or
matched by display name. Their existing cookies still work, but email sign-in
is unavailable while this mode is enabled. Disable the flag to use their original
email login. Conversely, name-only identities can use their recovery tokens only
while this mode is enabled; do not disable it without planning their access.

The schema migration adds a boolean identity marker and an indexed recovery-token
digest. Back up persistent data and `.env` before deploying. Keep `SECRET_KEY_BASE`
stable across rebuilds to preserve signed cookies and encrypted session state.

## Trust boundary

This is designed for a trusted VPN/LAN, not a public signup service. Invite links
grant membership to anyone who possesses them; display names do not prove a
person's identity. The VPN does not prevent another authorized user from choosing
a misleading display name. Existing account/retro authorization still applies.
HTTP over the private network also carries cookies and recovery tokens without
application-layer encryption; use a private HTTPS proxy if that is unacceptable.
Passkeys, if used, still require a secure browser origin.
