# SSRS Development Project - Session Context

This file maintains context across AI assistant sessions. Update it as the project evolves.

---

## Project Overview

**Purpose:** SQL Server 2025 + Power BI Report Server (PBIRS) development environment in Windows containers, supporting an ASP.NET VB.NET application.

**Original Goal:** Implement a containerized version of SSRS for development purposes.

**Started:** August 2026

---

## Critical Context: SSRS in Containers is NOT Officially Supported

**Microsoft does NOT provide official Docker images for SSRS/PBIRS.** This is important context:

- No official `mcr.microsoft.com` image exists for SSRS
- All available images are community-maintained
- Most community images are outdated, massive (~8GB+), and fragile
- **This setup is explicitly NOT recommended for production use**

We proceeded anyway for **development/testing purposes only**.

---

## Architecture & Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Container platform | Docker (Windows containers) | Required for SSRS/PBIRS - Linux not supported |
| Base image | `mcr.microsoft.com/windows/servercore:ltsc2022` | Most compatible Windows base |
| SQL Server version | 2025 (Evaluation) | Latest features, downloaded during build |
| Report Server | Power BI Report Server 2025 | Modern SSRS replacement, downloaded via `aka.ms/pbireportserverexe` |
| Memory allocation | 6GB minimum | Required for PBIRS + SQL Server to run together |
| Image source | `ipierre1/ssrs-powerbi` (fork of SaViGnAnO/SSRS-Docker) | Most maintained community option found |

---

## Current State

- [x] Container built (image: `ssrs-local:latest`)
- [x] Container created (name: `ssrs-dev`)
- [ ] Container running and healthy
- [ ] SQL Server accessible on port 1433
- [ ] PBIRS accessible on port 80 (http://localhost/reports)
- [ ] Reports deployed
- [ ] ASP.NET VB.NET app connected

**Last verified:** 2026-08-28 (structure review only)

---

## Session Log

### Session 1: 2026-08-24 (Initial Setup - PAINFUL)

**Goal:** Containerize SSRS for development environment

**What happened:**
- This was a long, difficult session with many failed attempts
- Tried multiple community Docker images - most were outdated and failed
- Images were massive in size (~8GB+)
- Encountered encoding/language issues (French characters - the Dockerfile contains French comments like "Configuration de SQL Server...", "SQL Server démarré avec succès")
- Special character handling problems noted

**Images/approaches tried:**
1. Various community SSRS images (failed - too old)
2. Eventually settled on `ipierre1/ssrs-powerbi` - a fork of SaViGnAnO/SSRS-Docker
3. Cloned/customized the build in `ssrs-build/` directory

**Outcome:**
- Got a working container, but **not exactly what was originally envisioned**
- The solution works but has compromises
- Build process takes 30-60 minutes
- Image is ~8GB

**Key learnings:**
- SSRS containerization is unsupported territory
- Community images are hit-or-miss
- Windows containers are resource-heavy
- French locale in the source image may cause encoding issues

### Session 2: 2026-08-28

- No memory of Session 1 (new AI session)
- Created `AGENTS.md` to preserve context across sessions
- Documented Session 1 based on user recollection and file analysis
- User has a new goal for today (to be discussed)

<!-- Add new sessions above this line -->

---

## Frequently Used Commands

```powershell
# Start container
docker start ssrs-dev

# Stop container
docker stop ssrs-dev

# View logs
docker logs ssrs-dev

# Check container status
docker ps -a | Select-String ssrs

# Test SQL connection
docker exec ssrs-dev powershell -Command "Invoke-Sqlcmd -Query 'SELECT @@VERSION' -ServerInstance 'localhost' -Username 'sa' -Password 'MyStr0ng!Pass#2024'"

# Interactive shell into container
docker exec -it ssrs-dev powershell

# Rebuild from scratch (30-60 min)
cd C:\ssrs-dev\ssrs-build
docker build -t ssrs-local:latest .
```

---

## Known Issues & Workarounds

| Issue | Workaround | Status |
|-------|------------|--------|
| No official Microsoft SSRS image | Using community fork `ipierre1/ssrs-powerbi` | Accepted limitation |
| Image size ~8GB | None - inherent to Windows containers + SQL + PBIRS | Accepted |
| Build time 30-60 min | Pre-built image, avoid rebuilding | Accepted |
| French encoding in Dockerfile | May cause special character issues in logs/output | Needs monitoring |
| Not production-ready | Development/testing use only | By design |

---

## Credentials

| Service | Username | Password |
|---------|----------|----------|
| SQL Server SA | `sa` | `MyStr0ng!Pass#2024` |
| PBIRS Admin | `pbirsAdmin` | `DefaultPass123!` (or as set via env var) |

---

## Access URLs (when container is running)

| Service | URL |
|---------|-----|
| Report Manager | http://localhost/reports |
| Report Server Web Service | http://localhost/reportserver |
| SQL Server | `localhost,1433` |

---

## Next Steps / TODOs

- [ ] Verify container is currently running and healthy
- [ ] Address encoding/French character issues if they cause problems
- [ ] New goal from Session 2 (TBD)

---

## Related Files

| File | Purpose |
|------|---------|
| `README.md` | Quick start guide and credentials |
| `ssrs-build/Dockerfile` | Container build definition (contains French comments) |
| `ssrs-build/scripts/` | PowerShell scripts for SQL/PBIRS setup |
| `install-ssrs.ps1` | Helper script for local SSRS installation (alternative approach) |
| `docker-compose.yml` | Linux SQL Server only (separate from SSRS container) |

---

## Notes for Future Sessions

1. **The user's original vision was not fully achieved** - the current solution is a compromise
2. **Encoding issues** - watch for problems with French characters/special characters
3. **This is development-only** - never suggest using this for production
4. **Session 1 was painful** - avoid suggesting "just rebuild" casually; builds take 30-60 min
5. **The user has an ASP.NET VB.NET application** that needs to connect to this environment

