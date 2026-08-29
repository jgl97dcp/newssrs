# SSRS Dev Sandbox

A private sandbox to run **SQL Server + SSRS** for reverse-engineering an inherited ASP.NET / VB.NET / ASMX / MSSQL / SSRS application, without touching any real DEV/UAT/PROD environments.

**Host:** Ubuntu 22.04 · **Hypervisor:** VirtualBox 7.1.18 · **Guest:** Windows Server 2022 Eval

---

## Current status (as of 2026-08-29)

| Component | Status |
|---|---|
| VirtualBox VM `ssrs-dev-vm` created | ✅ |
| Windows Server 2022 installed | ✅ |
| SQL Server 2022 Developer installed | ✅ |
| SSMS installed | ✅ |
| SSRS 2022 installed + configured (Web Service URL, DB, Web Portal URL) | ✅ |
| Guest firewall opened for ports 80 / 443 / 1433 | ✅ |
| SSRS reachable from Ubuntu host: `http://localhost:8080/Reports` (NTLM) | ✅ |
| Report Builder installed | ⬜ optional |
| SQL TCP/IP protocol enabled + fixed to port 1433 | ⬜ **next** |
| Mixed-mode auth + `appuser` SQL login | ⬜ **next** |
| SQL reachable from Ubuntu: `sqlcmd -S localhost,11433` | ⬜ **next** |
| VM snapshot taken | ⬜ **do right after SQL works** |
| Legacy app DBs restored into VM | ⬜ future |
| Legacy `.rdl` reports deployed to this SSRS | ⬜ future |
| ASP.NET/VB.NET app pointed at this sandbox | ⬜ future |

---

## Resume here (next session)

You're picking up right after confirming SSRS answers `HTTP 401 NTLM` from Ubuntu curl. **The environment build is ~80% done.** Remaining:

### 1. Enable SQL Server for remote connections (~10 min)

Follow **`docs/ssrs-vm-setup.md` §10** for the exact steps. TL;DR:

**Inside the VM (elevated PowerShell):**
```powershell
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SqlWmiManagement') | Out-Null
$wmi = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer
$tcp = $wmi.ServerInstances['MSSQLSERVER'].ServerProtocols['Tcp']
$tcp.IsEnabled = $true; $tcp.Alter()
$ipAll = $tcp.IPAddresses['IPAll']
$ipAll.IPAddressProperties['TcpPort'].Value = '1433'
$ipAll.IPAddressProperties['TcpDynamicPorts'].Value = ''
$tcp.Alter()
Restart-Service -Name 'MSSQLSERVER' -Force
```

**Inside SSMS (connect to `localhost` with Windows auth):**
```sql
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE',
  N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 2;

CREATE LOGIN appuser WITH PASSWORD = 'AppUser!Strong#2026', CHECK_POLICY = ON;
ALTER SERVER ROLE sysadmin ADD MEMBER appuser;  -- tighten later
```

Then restart the SQL service again (PowerShell): `Restart-Service MSSQLSERVER -Force`

### 2. Verify from Ubuntu (~1 min)

```bash
/opt/mssql-tools/bin/sqlcmd -S localhost,11433 -U appuser -P 'AppUser!Strong#2026' \
  -Q "SELECT @@VERSION, SUSER_SNAME()"
```

Expected: SQL Server 2022 banner + `appuser`.

### 3. Snapshot the VM (~2 min)

```bash
VBoxManage controlvm ssrs-dev-vm acpipowerbutton         # graceful shutdown
sleep 30
VBoxManage snapshot ssrs-dev-vm take "clean-sandbox" \
  --description "Fresh Win2022 + SQL2022 Dev + SSRS 2022, firewall + SQL remote configured"
VBoxManage startvm ssrs-dev-vm --type gui                # boot back up
```

### 4. (Then) Bring the legacy app in

Once the sandbox is snapshotted:
- Grab a `.bak` of each app database from your DEV → copy into VM → restore via SSMS.
- Grab the `.rdl` / `.rdlc` files from the app's source → upload via SSRS Web Portal, or use `rs.exe` for bulk deploy.
- Update the app's `web.config` `<connectionStrings>` to point at `localhost,11433` (from your dev workstation) or `localhost,1433` (from inside the VM).
- If the app runs IIS, decide: run IIS inside the sandbox VM, or run the app on your Windows 11 host pointed at the sandbox VM's SQL/SSRS.

---

## Quick reference

### Access URLs

| Service | From Ubuntu host | From inside VM |
|---|---|---|
| SSRS Web Portal | http://localhost:8080/Reports | http://localhost/Reports |
| SSRS Web Service | http://localhost:8080/ReportServer | http://localhost/ReportServer |
| SQL Server | `localhost,11433` | `localhost,1433` |
| RDP | `xfreerdp /u:Administrator /v:localhost:3389` | n/a |

Browser NTLM setup for SSRS (Firefox): `about:config` → `network.automatic-ntlm-auth.trusted-uris` = `localhost`.

### VM lifecycle

```bash
VBoxManage startvm  ssrs-dev-vm --type gui        # start with window
VBoxManage startvm  ssrs-dev-vm --type headless   # start without window
VBoxManage controlvm ssrs-dev-vm acpipowerbutton  # graceful shutdown
VBoxManage controlvm ssrs-dev-vm poweroff         # hard stop (avoid)
VBoxManage list runningvms
VBoxManage showvminfo ssrs-dev-vm | grep -iE 'State|Forward'

# Snapshots
VBoxManage snapshot ssrs-dev-vm list
VBoxManage snapshot ssrs-dev-vm take    "<name>" --description "..."
VBoxManage snapshot ssrs-dev-vm restore "<name>"       # requires VM powered off
```

### Credentials (fill in your actuals)

| Service | Login | Password |
|---|---|---|
| Windows `Administrator` (guest) | `Administrator` | _(set during install — store in your pw manager)_ |
| SQL sysadmin (Windows auth) | `Administrator` | via Windows auth |
| SQL app login (once §10 done) | `appuser` | `AppUser!Strong#2026` _(change this)_ |

---

## Repo contents

| Path | Purpose |
|---|---|
| `AGENTS.md` | Full session-by-session log for AI assistants (context preservation) |
| `README.md` | This file — human-facing status + resume guide |
| `docs/ssrs-vm-setup.md` | Complete step-by-step VM + SQL + SSRS install/config guide |
| `scripts/create-vm.sh` | One-command VirtualBox VM provisioning |

---

## History (short)

- **Sessions 1–2 (2026-08-24 / 28):** Attempted to containerize SSRS. Painful. Community images are old/broken, ~8 GB, unsupported by Microsoft. Not a viable path. See `AGENTS.md` Session 1.
- **Session 3 (2026-08-28):** Pivoted to VM using official Microsoft installers. Built `scripts/create-vm.sh` + `docs/ssrs-vm-setup.md`.
- **Session 4 (2026-08-29):** Executed the plan. VM up, SQL + SSRS installed and configured, firewall opened, SSRS reachable from host. Stopped before SQL remote connectivity (§10).

## Known gotchas (learned the hard way)

1. **SSRS installer does NOT add a Windows Firewall rule** — port 80 is silently dropped by default. `New-NetFirewallRule -LocalPort 80 -Direction Inbound -Action Allow` is required.
2. **VBox NAT port forward "connects" even when guest firewall drops** — you get a TCP handshake with VBox itself, then timeout. Symptom is deceiving; always suspect guest firewall first.
3. **Container path is dead** — Microsoft does not ship an official SSRS image. Do not go back down that road.
4. **Microsoft retired pre-built Windows dev VMs** (`developer.microsoft.com/windows/downloads/virtual-machines/` now redirects). Only path is fresh install from Eval ISO.
