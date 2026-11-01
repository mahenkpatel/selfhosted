<details>
<summary><b>Samba Auto-Setup Script Documentation</b></summary>

### Overview
A lightweight, idempotent Bash script to install, configure, and verify a Samba (SMB) network share on any Debian/Ubuntu machine.

---

### Features
- **Automated Installation:** Detects if Samba is already installed and skips redundant package installations.
- **Dynamic Share Paths:** Accepts custom directories as arguments or defaults directly to `/home/ubuntu`.
- **Safe Configuration:** Creates timestamped backups of `/etc/samba/smb.conf` prior to modifications and prevents duplicate section definitions.
- **Permission Enforcement:** Sets directory permissions (`0755`) and user ownership for the designated SMB account.
- **Firewall Integration:** Detects active UFW installations and permits Samba traffic automatically.
- **Built-in Self-Testing:** Validates configuration syntax via `testparm`, checks the `smbd` daemon, verifies Samba database presence, and performs a live loopback read/write test over `127.0.0.1`.

---

### Quick Start (One-Liner Execution)

Default Path (`/home/ubuntu`):
```bash
curl -fsSL [https://raw.githubusercontent.com/mahenkpatel/selfhosted/refs/heads/main/smb-setup.sh](https://raw.githubusercontent.com/mahenkpatel/selfhosted/refs/heads/main/smb-setup.sh) | sudo bash
```

Custom Path (e.g., `/mnt/books`):
```bash
curl -fsSL [https://raw.githubusercontent.com/mahenkpatel/selfhosted/refs/heads/main/smb-setup.sh](https://raw.githubusercontent.com/mahenkpatel/selfhosted/refs/heads/main/smb-setup.sh) | sudo bash -s -- /mnt/books
```

Using `wget`:
```bash
wget -qO- [https://raw.githubusercontent.com/mahenkpatel/selfhosted/refs/heads/main/smb-setup.sh](https://raw.githubusercontent.com/mahenkpatel/selfhosted/refs/heads/main/smb-setup.sh) | sudo bash -s -- /mnt/books
```

---

### Default Configuration Values

- **User:** `ubuntu` (Created automatically if absent)
- **Password:** `password` (Configured for both system and Samba)
- **Default Directory:** `/home/ubuntu` (Overridable via the first script argument)
- **Share Name:** Derived base directory name (e.g., `/mnt/books` results in `[books]`)
- **Permissions:** `0755` directory, `0664` file masks; `force user = ubuntu`

---

### Connecting to the Share

- **Windows:** Press `Win + R` and enter:
  ```text
  \\<SERVER_IP>\<SHARE_NAME>
  ```
- **macOS:** In Finder, press `Cmd + K` and enter:
  ```text
  smb://<SERVER_IP>/<SHARE_NAME>
  ```
- **Linux (CLI Mount):**
  ```bash
  sudo mount -t cifs //<SERVER_IP>/<SHARE_NAME> /mnt/share -o username=ubuntu,password=password
  ```

---

### Post-Install Diagnostics

The script executes 4 verification checks automatically upon completion:
1. **Syntax Check:** Runs `testparm -s` against `/etc/samba/smb.conf`.
2. **Daemon Status:** Verifies the `smbd` service is active and enabled.
3. **Database Check:** Validates user existence with `pdbedit -L -u ubuntu`.
4. **Loopback Write Test:** Performs an authenticated SMB file create and delete test via `smbclient`.

</details>
