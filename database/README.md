# Database foundation
PostgreSQL 16. Set POSTGRES_PASSWORD in a private local .env file, then run:
```sh
docker compose -f compose.database.yml up -d
docker compose -f compose.database.yml exec db psql -U krafty -d krafty -c '\dt'
```
The initialization scripts execute on a fresh volume only. Never delete an existing volume to apply migrations. Back up before changes. The database binds to loopback on port 55432; do not expose it publicly.

## Integration contract
- Store song analysis and campaign direction; record trends and timestamped observations.
- Register source footage and its latest rights decision. Only eligible_footage may enter the rendering pipeline; verify platform scope again before publication.
- Store scene time ranges, fingerprints, campaign relevance and creative recipes.
- Claim work transactionally with claim_render_job; workers must renew leases and finalize only their own current lease. A worker implementation is still required.
- Reserve estimated paid API cost before calling a provider with reserve_cost; reconcile actual spend and release unused reservations transactionally. Direct writes must be restricted in production. This is not yet an end-to-end spending guarantee.
- Store reviewed clips, account references (not credentials), publication records and analytics. No automatic publishing is implemented.
- monthly_spend and format_performance provide dashboard queries. Raw footage and outputs stay outside Git.
- Default monthly budget is 2500 pence. The 2500 monthly clip target is a planning target, not a database-enforced quota.

## Status
Schema and SQL operations are initial implementation, not runtime verified. Existing engine.py is not yet wired to PostgreSQL. No server deployment has been performed. Authentication, least-privilege roles, migrations for existing volumes, backups, worker integration and integration tests remain required.
