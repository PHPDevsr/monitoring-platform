# Tasks
- [x] Handle Loki probe DNS failures using its current shared-network IP with a DNS warning; preserve HTTP readiness, retries, timeout, and container diagnostics
- [x] Fix deployment readiness for Loki without an in-image HTTP client and Promtail without wget; report failing healthcheck details
- [ ] Provision VM
- [ ] Install Docker
- [x] Deploy monitoring stack
- [x] Fix Alertmanager CI validation (amtool check-config passes for both no-creds and with-creds renders)
- [x] Use the official Alertmanager image directly with a mounted configuration renderer; align deployment and CI without custom builds
