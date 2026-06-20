# logmon

A self-hosted dashboard for browsing and visualizing [Caddy](https://caddyserver.com/) server logs. Import Caddy access and error logs, then explore them through a searchable, filterable web UI with aggregate stats.

Built with Rails 8, SQLite, Tailwind CSS, and Turbo.

## Features

- **Dashboard** — total requests, error rate, status code breakdown, top hosts / IPs / paths / user agents, browser & OS distribution, requests-per-hour chart.
- **Access logs** — paginated list with search and filters (status, method, host, IP); per-request detail view.
- **Error logs** — same treatment for Caddy's error log stream.
- **Incremental imports** — gzipped rotated logs are imported once; active `.log` files are tailed by byte offset, so re-running the importer only pulls new data.
- **Auth** — sign in with GitHub or Apple, gated by an email allowlist.

## Requirements

- Ruby 3.4.9 (see `.ruby-version`)
- Bundler

## Development setup

```sh
bin/setup            # install gems, prepare DB, clear logs
bin/dev              # start web + Tailwind watch (Procfile.dev)
```

Open http://localhost:3000. You'll be redirected to login — see [Authentication](#authentication) to configure a provider, or the dashboard won't let you in.

## Importing logs

Point the importer at a directory of Caddy logs:

```sh
CADDY_LOGS_DIR=/var/log/caddy bin/rails logs:import
```

The directory should contain Caddy's tab-delimited JSON logs: `*.log.gz` (rotated) and `*.log` (active). Files with `error` in the name are parsed as error logs; everything else as access logs.

Reset all imported data:

```sh
bin/rails logs:reset
```

## Authentication

Logmon requires login. Configure at least one provider via environment variables:

| Variable | Description |
|---|---|
| `EMAIL_ALLOWLIST` | Comma-separated emails or `*@domain.com` patterns allowed to sign in (required) |
| `GITHUB_CLIENT_ID` | GitHub OAuth app client ID |
| `GITHUB_CLIENT_SECRET` | GitHub OAuth app client secret |
| `GITHUB_CALLBACK_URL` | e.g. `https://logmon.example.com/auth/github/callback` |
| `APPLE_CLIENT_ID` | Apple Sign In services ID |
| `APPLE_TEAM_ID` | Apple developer team ID |
| `APPLE_KEY_ID` | Key ID for your Apple Sign In key |
| `APPLE_PRIVATE_KEY` | Inline ES256 private key (or use `APPLE_PRIVATE_KEY_FILE` for a path) |
| `APPLE_CALLBACK_URL` | e.g. `https://logmon.example.com/auth/apple/callback` |
| `APPLE_SCOPES` | Optional; defaults to `name email` |

Without `EMAIL_ALLOWLIST` set, nobody gets in. That's the point.

## Deployment

Two options are included.

### systemd

Unit files and a timer live in `deploy/systemd/`. The import timer runs `rails logs:import` every 5 minutes; the web service runs Puma.

1. Copy `deploy/systemd/logmon.env` to `/etc/logmon/logmon.env` and fill in `CADDY_LOGS_DIR` and auth vars.
2. Install `logmon-web.service`, `logmon-import.service`, and `logmon-import.timer`.
3. Enable `logmon-web` and `logmon-import.timer`.

### Kamal (Docker)

`config/deploy.yml` is configured for Kamal. Set up `.kamal/secrets` with `RAILS_MASTER_KEY` and deploy:

```sh
bin/kamal setup
```

The import task can also be run inside the container:

```sh
bin/kamal app exec --reuse "CADDY_LOGS_DIR=/path bin/rails logs:import"
```

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs on every PR and `main` push:

- **Brakeman** — Rails security static analysis
- **bundler-audit** — known-vulnerable gems
- **RuboCop** — style (Omakase config)

There is no automated test suite yet.
