# SSRS Dev Sandbox — VirtualBox VM Setup

Fresh install of Windows Server 2022 Eval + SQL Server 2022 Developer + SSRS 2022 in VirtualBox on Ubuntu 22.04.

## Why this approach

Microsoft retired the pre-built Windows dev VM images (the old `developer.microsoft.com/windows/downloads/virtual-machines/` page now redirects). We install from an official Eval ISO:

- **Windows Server 2022 Evaluation** — 180 days, no TPM 2.0 requirement (unlike Win11), matches likely production topology.
- **SQL Server 2022 Developer** — free, full feature parity with Enterprise, non-prod use only.
- **SQL Server 2022 Reporting Services** — free standalone installer (this is "SSRS").

Everything below uses **official Microsoft installers**. No community images.

---

## 0. Host prerequisites (already verified)

- Ubuntu 22.04, VirtualBox 7.1.18
- VT-x enabled
- 8+ GB free RAM, 100+ GB free disk

## 1. Download the ISO

<https://www.microsoft.com/en-us/evalcenter/download-windows-server-2022>
Choose **ISO downloads → English (US)**. Save as `~/VMs/iso/WindowsServer2022.iso` (~5 GB).

## 2. Create the VM

From the repo root:

```bash
./scripts/create-vm.sh ~/VMs/iso/WindowsServer2022.iso
VBoxManage startvm ssrs-dev-vm --type gui
```

The script provisions:

| Setting | Value |
|---|---|
| CPU | 4 vCPU |
| RAM | 8 GB |
| Disk | 80 GB dynamic VDI |
| Firmware | UEFI |
| Network | NAT with port forwards |
| RDP | host `:3389` → guest `:3389` |
| SSRS | host `http://localhost:8080` → guest `:80` |
| SQL | host `localhost,11433` → guest `:1433` |

## 3. Install Windows Server 2022

1. Boot VM → press any key at "Press any key to boot from CD".
2. Language: English (US) → **Install now**.
3. Choose **Windows Server 2022 Standard Evaluation (Desktop Experience)** — the "Desktop Experience" variant is required for the SSRS Config Manager GUI.
4. Accept license → **Custom: Install Windows only**.
5. Select the 80 GB unallocated disk → Next. Install takes ~15–20 min, reboots automatically.
6. Set **Administrator** password (write it down; you'll need it forever).
7. First login: Ctrl+Alt+Del is `Right Ctrl + Delete` in VirtualBox (or Input menu → Keyboard → Insert Ctrl-Alt-Del).

### Install VirtualBox Guest Additions

Devices menu → **Insert Guest Additions CD image** → run installer inside guest → reboot. Enables clipboard, better display, shared folders.

### Enable Remote Desktop (optional but recommended)

Server Manager → Local Server → **Remote Desktop: Enable**. You can then RDP from your Ubuntu host with `xfreerdp /u:Administrator /v:localhost:3389`.

### Disable IE Enhanced Security Config

Server Manager → Local Server → IE Enhanced Security → **Off** for Administrators. Otherwise you'll fight download prompts.

## 4. Install SQL Server 2022 Developer

Inside the VM, open Edge/IE and download:

- **SQL Server 2022 Developer**: <https://www.microsoft.com/en-us/sql-server/sql-server-downloads> → "Developer" → Download.

Run `SQL2022-SSEI-Dev.exe`:

1. Choose **Basic** (fastest) or **Custom** if you want to pick features.
2. Accept license, default install path.
3. When done, note the **instance name** (default `MSSQLSERVER`) and the **connection string** shown on the final screen.

Verify from PowerShell inside the VM:

```powershell
sqlcmd -S localhost -E -Q "SELECT @@VERSION"
```

## 5. Install SQL Server Management Studio (SSMS)

- <https://learn.microsoft.com/sql/ssms/download-sql-server-management-studio-ssms>
- Run installer, reboot when prompted.

## 6. Install SQL Server 2022 Reporting Services (SSRS)

This is the piece that used to be bundled — since SQL 2017 it's a **separate free download**.

- <https://www.microsoft.com/en-us/download/details.aspx?id=104502>
- File: `SQLServerReportingServices.exe`

Steps:

1. Run installer → **Install Reporting Services**.
2. Edition: **Developer** (free, non-prod).
3. Accept license, install (~5 min).
4. Click **Configure Report Server** at the end (launches Report Server Configuration Manager).

## 7. Configure Report Server

In **Report Server Configuration Manager**:

1. **Connect** to `<hostname>\SSRS` (default).
2. **Service Account** → keep default `NT Service\SQLServerReportingServices`.
3. **Web Service URL** → click **Apply** (creates `http://<host>:80/ReportServer`).
4. **Database** → **Change Database** → Create new → Server: `localhost` → auth: Current User → DB name: `ReportServer` → Next → Finish.
5. **Web Portal URL** → **Apply** (creates `http://<host>:80/Reports`).
6. **Exit**.

Verify inside the VM:

- Report Portal: <http://localhost/Reports>
- Web Service:  <http://localhost/ReportServer>

Verify from Ubuntu host (via NAT forward):

- Report Portal: <http://localhost:8080/Reports>
- Web Service:  <http://localhost:8080/ReportServer>

## 8. Install Report Builder (report authoring)

- <https://www.microsoft.com/en-us/download/details.aspx?id=105942>
- Or use Visual Studio + "Microsoft Reporting Services Projects" extension for `.rdl` project development.

## 9. Snapshot before doing anything else

From the Ubuntu host:

```bash
VBoxManage controlvm ssrs-dev-vm acpipowerbutton   # graceful shutdown
# ...wait for it to power off...
VBoxManage snapshot ssrs-dev-vm take "clean-ssrs-installed" --description "Fresh Win2022 + SQL2022 Dev + SSRS 2022 configured"
```

Restore later with:
```bash
VBoxManage snapshot ssrs-dev-vm restore "clean-ssrs-installed"
```

## 10. Enable SQL for remote connections (for your ASP.NET app)

Inside the VM, open **SQL Server Configuration Manager**:

1. SQL Server Network Configuration → Protocols for MSSQLSERVER → **TCP/IP: Enabled**.
2. TCP/IP → Properties → IP Addresses → IPAll → **TCP Port: 1433**, clear "TCP Dynamic Ports".
3. Restart **SQL Server (MSSQLSERVER)** service.
4. Open Windows Firewall: allow inbound TCP 1433 and TCP 80.

Enable **SQL auth** (mixed mode) if your legacy app uses SQL logins:

- SSMS → right-click server → Properties → Security → **SQL Server and Windows Authentication mode** → OK → restart SQL service.
- Create a login (e.g., `appuser`) with a strong password.

Test from Ubuntu host:

```bash
# Requires mssql-tools or sqlcmd on host
sqlcmd -S localhost,11433 -U appuser -P '<pass>' -Q "SELECT @@VERSION"
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| VM stuck at "boot from CD" | Devices → Optical → verify ISO attached; check boot order in VM settings |
| Report Portal shows 500 | Config Manager → Database → recreate `ReportServer` DB |
| Cannot reach `:8080` from host | Check `VBoxManage showvminfo ssrs-dev-vm \| grep -i forward`; verify guest firewall allows :80 |
| SQL connection times out from host | Enable TCP/IP protocol + firewall rule (see §10) |
| Server activation warning | Fine — 180-day eval. Re-arm with `slmgr /rearm` (up to 5x = ~3 years) |

## Credentials (record yours here)

| Service | Login | Password |
|---|---|---|
| Windows Administrator | `Administrator` | *(set during install)* |
| SQL sysadmin | Windows auth via `Administrator` | n/a |
| SSRS admin | Windows auth via `Administrator` | n/a |
| SQL app login (if created) | `appuser` | *(you choose)* |
