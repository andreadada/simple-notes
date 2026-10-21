# Simple Notes

Self-hosted task and note manager for **Windows 11** and **Android**.

**P0 IN CORSO — NOT PRODUCTION READY**

- [Roadmap, checklist, do/don't rules and Edit Timespan](project.md)
- [Flutter client](apps/flutter/README.md) — local prototype, no sync yet
- [Backend API](docs/api.md) — Google ID-token exchange and owner-scoped tasks
- [Architecture](docs/architecture.md)
- [Coolify infrastructure](infra/README.md)

## Start locally

Backend: copy `.env.example` to `.env`, set strong credentials and Google client IDs, then use:

```bash
docker compose --env-file .env -f infra/compose.yaml up --build
```

Flutter: follow [apps/flutter/README.md](apps/flutter/README.md).

Security: never commit secrets. The backend API is preliminary (no refresh/revocation or rate limits); do not expose publicly yet.
