# Known Log and Trace Noise (Sandbox)

When running the demo sandbox, some log entries and traces may appear as errors but are expected or benign.

## Logs

- **chat-postgres** – Checkpoint messages (`checkpoint starting`, `checkpoint complete`) and `role "datadog" already exists` can show with `status:error` due to level mapping. Checkpoints are normal Postgres operation; the role error is handled in backend startup (idempotent DBM user creation).
- **chat-worker** – INFO lines (e.g. "Response published for request", "OpenAI responded") may be tagged `status:error` if the log pipeline maps levels strictly; the worker is operating normally.
- **agent** – RabbitMQ check can log "Read timed out" or "setting aliveness to CRITICAL" when the management API is slow; the check timeout has been increased to 20s to reduce this. "Error stopping check... cannot find a check with ID" is benign scheduler noise.

## Traces

- **chat-backend** – A `postgres.query` span for `CREATE ROLE datadog` may show `status:error` with "role already exists"; the app catches this and continues. No action needed.

## Mitigations in Place

- Frontend API routes use `fetchWithRetry` when calling the backend to reduce ECONNREFUSED errors during backend restarts.
- RabbitMQ Datadog check instance timeout set to 20s in `k8s/rabbitmq.yaml` to reduce false CRITICALs.
