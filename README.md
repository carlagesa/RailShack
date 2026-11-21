<!--
  RailShack · 50 Microservices Project by DevOps Shack
  Copyright (c) 2026 DevOps Shack (Aditya Jaiswal) · https://devopsshack.com · https://www.youtube.com/@devopsshack
  SPDX-License-Identifier: Apache-2.0
-->

<p align="center">
  <a href="https://www.youtube.com/@devopsshack">
    <img src=".github/assets/banner.svg" alt="50 Microservices Project by DevOps Shack" width="100%" />
  </a>
</p>

<p align="center">
  <a href="https://www.youtube.com/@devopsshack"><img alt="YouTube" src="https://img.shields.io/badge/YouTube-DevOps%20Shack-FF0000?style=for-the-badge&logo=youtube&logoColor=white"></a>
  <a href="https://devopsshack.com"><img alt="Website" src="https://img.shields.io/badge/devopsshack.com-Learn%20DevOps-00FFA3?style=for-the-badge&logo=googlechrome&logoColor=black"></a>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/License-Apache%202.0-0A0D16?style=for-the-badge&logoColor=white"></a>
</p>

<p align="center">
  <img alt="Microservices" src="https://img.shields.io/badge/microservices-50-00E5FF">
  <img alt="Go" src="https://img.shields.io/badge/Go-22_services-00ADD8?logo=go&logoColor=white">
  <img alt="Node.js" src="https://img.shields.io/badge/Node.js-18_services-5FA04E?logo=nodedotjs&logoColor=white">
  <img alt="Python" src="https://img.shields.io/badge/Python-6_services-3776AB?logo=python&logoColor=white">
  <img alt="Java" src="https://img.shields.io/badge/Java-4_services-ED8B00?logo=openjdk&logoColor=white">
  <img alt="PostgreSQL" src="https://img.shields.io/badge/PostgreSQL-16-4169E1?logo=postgresql&logoColor=white">
  <img alt="Redis" src="https://img.shields.io/badge/Redis-cache-DC382D?logo=redis&logoColor=white">
</p>

<h3 align="center">A train-booking application made from 50 cooperating microservices.</h3>

RailShack lets users search trains, book tickets, check PNR status, view trips,
and cancel bookings. This checkout is intentionally focused on the application:
service source, shared libraries, local execution, and application tests. Cloud
deployment and Kubernetes packaging have been removed.

## What is in the application?

| Area | Services |
|---|---|
| Users & Auth | 6: auth, user-profile, passengers, KYC, notifications, preferences |
| Trains & Search | 8: stations, trains, routes, schedules, search, seat-map, fares, quota |
| Booking | 10: booking, PNR, seat-allocation, waitlist, RAC, Tatkal, cancellation, refunds, booking-history, ticket-PDF |
| Payments | 6: payment-gateway, wallet, UPI, invoices, offers, settlements |
| Travel Extras | 8: live-status, platform-info, food-ordering, retiring-rooms, tourism, cab-booking, insurance, chart-preparation |
| Platform | 12: API gateway, config, rate-limiter, audit-log, analytics, search-indexer, email, SMS, scheduler, feedback, admin, frontend |

`services.json` is the service catalog. It assigns each service a language,
business domain, and local port from 9001 to 9050. The frontend is on 9050 and
the API gateway is on 9039.

The browser talks to the frontend. The frontend sends API requests through the
gateway, which calls the appropriate service over HTTP. Services use the
language-specific shared kits in `libs/` for health checks, logging, metrics,
and downstream calls.

![RailShack service call map](docs/architecture/call-map.png)

PostgreSQL is the shared durable store when `DATABASE_URL` is set. Redis is an
optional cache configured with `REDIS_ADDR`. Some services fall back to
in-memory state if these dependencies are not configured; that data disappears
when the processes stop.

## Run locally

The app runs directly from source; the runner starts all 50 services without
building application containers. Use Git Bash or WSL on Windows (or another
Bash shell). Required runtimes are Go 1.24, Node.js 22, Python 3.13, and JDK
21, plus Python 3 and curl.

For persistent database and cache behavior, start local PostgreSQL 16 and Redis
7 (installed natively or in local-only containers). Create a `railshack`
database, then set the connection variables in the same Bash shell:

```bash
export DATABASE_URL='postgres://railshack:railshack-local@127.0.0.1:5432/railshack?sslmode=disable'
export REDIS_ADDR='127.0.0.1:6379'
```

From the repository root, start the services and run the end-to-end smoke test:

```bash
bash scripts/start-services.sh
bash scripts/smoke-test.sh http://localhost:9050
```

The runner compiles Go and Java services, starts each service on its catalog
port, and checks all `/healthz` endpoints. Logs and process IDs are stored under
`.run/`. If `DATABASE_URL` and `REDIS_ADDR` are unset, the application uses its
in-memory paths where supported.

The smoke test exercises sign-up/sign-in, train search, booking, PNR lookup,
trip history, and cancellation. The test-only GitHub Actions workflow runs the
same checks against PostgreSQL and Redis; it does not publish images or deploy
the application.

## Repository map

| Path | Purpose |
|---|---|
| `services/` | The 50 application services and their runtime source |
| `libs/` | Shared Go, Node.js, Python, and Java support libraries |
| `services.json` | Service names, languages, domains, and local ports |
| `scripts/start-services.sh` | Build and start the application from source |
| `scripts/smoke-test.sh` / `scripts/smoke-test.ps1` | End-to-end application smoke tests |
| `.github/workflows/ci.yml` | Syntax, Go vet, and end-to-end application tests |
| `docs/architecture/` | Service call-map and service-to-service edges |

For a staged guide to rebuilding the removed deployment locally, see
[the local development and deployment rebuild plan](docs/local-development-and-rebuild-plan.md).
It targets AWS Emulator v1.0.322 for local AWS API exercises and kind for the
actual Kubernetes cluster running application pods; the emulator's EKS API
does not by itself provide a connected RailShack cluster.

## See it in action

<table>
  <tr>
    <td width="50%"><img src=".github/assets/screenshot-home.png" alt="RailShack home page" /><p align="center"><b>Home</b> — search trains across 20 stations</p></td>
    <td width="50%"><img src=".github/assets/screenshot-mesh.png" alt="Live microservice mesh" /><p align="center"><b>Live mesh</b> — one booking lights up services it touches</p></td>
  </tr>
  <tr>
    <td width="50%"><img src=".github/assets/screenshot-search.png" alt="Search results" /><p align="center"><b>Search</b> — live availability and fares</p></td>
    <td width="50%"><img src=".github/assets/screenshot-ticket.png" alt="Booking and e-ticket" /><p align="center"><b>Book</b> — PNR, e-ticket and invoice</p></td>
  </tr>
</table>

## Learn with DevOps Shack

This project was created by [DevOps Shack](https://devopsshack.com). Watch
the project and related learning material on
[YouTube](https://www.youtube.com/@devopsshack).

## License and attribution

RailShack is © 2026 **DevOps Shack (Aditya Jaiswal)** and licensed under the
[Apache License 2.0](LICENSE).

Original project and attribution: [RailShack by DevOps Shack](https://github.com/jaiswaladi246/50-MicroServices-Project-By-DevOpsShack),
created by **DevOps Shack (Aditya Jaiswal)**. If you redistribute this project
or a derivative work, retain copyright and license notices, source headers,
and mark changed files. Credit shared work as **RailShack by DevOps Shack**.
