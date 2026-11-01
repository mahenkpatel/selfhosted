#!/usr/bin/env bash
set -euo pipefail

# Ensure the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
    echo "[-] Error: This script must be run as root or via sudo." >&2
    exit 1
fi

# Color formatting helpers
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_step() { echo -e "\n${BLUE}==>${NC} ${1}"; }
log_info() { echo -e "  [i] ${1}"; }
log_ok()   { echo -e "  [${GREEN}✓${NC}] ${1}"; }
log_warn() { echo -e "  [${YELLOW}!${NC}] ${1}"; }
log_err()  { echo -e "  [${RED}✗${NC}] ${1}"; }

# Configuration variables
SHARE_DIR="${1:-/home/ubuntu}"
SMB_USER="ubuntu"
SMB_PASS="password"
CONF_FILE="/etc/samba/smb.conf"
SHARE_NAME="$(basename "${SHARE_DIR}")"

# Resolve local primary IP address
HOST_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1")"

echo "=========================================="
echo "    Automated Samba Provisioning Script   "
echo "=========================================="
log_info "Target Share Directory: ${SHARE_DIR}"
log_info "Share Definition Name : [${SHARE_NAME}]"
log_info "Configured User       : ${SMB_USER}"

# ---------------------------------------------------------
# Step 1: Package Management
# ---------------------------------------------------------
log_step "Step 1/5: Checking and installing required packages..."
if dpkg -s samba &>/dev/null && command -v smbd &>/dev/null; then
    log_ok "Samba is already installed."
else
    log_info "Updating apt index..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    log_info "Installing samba and smbclient..."
    apt-get install -y -qq samba smbclient
    log_ok "Samba suite installed successfully."
fi

# Ensure smbclient is installed for verification
if ! command -v smbclient &>/dev/null; then
    log_info "Installing smbclient for self-test validation..."
    apt-get install -y -qq smbclient
    log_ok "smbclient installed."
fi

# ---------------------------------------------------------
# Step 2: User and Directory Permissions
# ---------------------------------------------------------
log_step "Step 2/5: Configuring system user and directory..."
if ! id "$SMB_USER" &>/dev/null; then
    log_info "Creating local system user '${SMB_USER}'..."
    useradd -m -s /bin/bash "$SMB_USER"
    echo "${SMB_USER}:${SMB_PASS}" | chpasswd
    log_ok "System user created."
else
    log_ok "System user '${SMB_USER}' already exists."
fi

log_info "Ensuring directory exists: ${SHARE_DIR}"
mkdir -p "$SHARE_DIR"

log_info "Setting directory ownership to ${SMB_USER}:${SMB_USER}..."
chown -R "$SMB_USER":"$SMB_USER" "$SHARE_DIR"

log_info "Applying permissions (755) to allow read/traversal..."
chmod 755 "$SHARE_DIR"
log_ok "Folder permissions established."

# ---------------------------------------------------------
# Step 3: Samba User Credentials
# ---------------------------------------------------------
log_step "Step 3/5: Registering Samba authentication database..."
log_info "Setting SMB password for '${SMB_USER}'..."
(echo "$SMB_PASS"; echo "$SMB_PASS") | smbpasswd -s -a "$SMB_USER" &>/dev/null
smbpasswd -e "$SMB_USER" &>/dev/null
log_ok "Samba account enabled and credentials synced."

# ---------------------------------------------------------
# Step 4: Configuration File
# ---------------------------------------------------------
log_step "Step 4/5: Updating Samba configuration (${CONF_FILE})..."
if [ -f "$CONF_FILE" ]; then
    BACKUP_FILE="${CONF_FILE}.bak.$(date +%F_%H%M%S)"
    cp "$CONF_FILE" "$BACKUP_FILE"
    log_ok "Backup created at ${BACKUP_FILE}"
else
    log_err "Configuration file ${CONF_FILE} not found."
    exit 1
fi

if grep -q "^\[${SHARE_NAME}\]" "$CONF_FILE"; then
    log_warn "Section [${SHARE_NAME}] already exists in ${CONF_FILE}. Keeping current definition."
else
    log_info "Appending [${SHARE_NAME}] share section..."
    cat >> "$CONF_FILE" <<EOF

[${SHARE_NAME}]
    comment = Auto-generated Samba Share
    path = ${SHARE_DIR}
    valid users = ${SMB_USER}
    read only = no
    browsable = yes
    guest ok = no
    create mask = 0664
    directory mask = 0775
    force user = ${SMB_USER}
EOF
    log_ok "Share configuration appended."
fi

# ---------------------------------------------------------
# Step 5: Service Management & Firewall
# ---------------------------------------------------------
log_step "Step 5/5: Reloading Samba services and firewall..."
systemctl restart smbd
systemctl enable smbd &>/dev/null
log_ok "Service 'smbd' active and enabled on boot."

if command -v ufw &>/dev/null && ufw status | grep -qw "active"; then
    log_info "UFW detected active. Adding Samba firewall rules..."
    ufw allow samba &>/dev/null
    log_ok "Firewall rule updated for Samba."
else
    log_info "UFW inactive or not installed. No firewall adjustments needed."
fi

# ---------------------------------------------------------
# Self-Test & Diagnostic Verification
# ---------------------------------------------------------
log_step "Running system verification and self-test..."

TESTS_PASSED=0
TOTAL_TESTS=4

# Test 1: Syntax test with testparm
log_info "1. Verifying Samba configuration syntax..."
if testparm -s "$CONF_FILE" &>/dev/null; then
    log_ok "Configuration syntax valid."
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    log_err "Syntax test failed on ${CONF_FILE}."
fi

# Test 2: Service daemon state
log_info "2. Checking smbd daemon running status..."
if systemctl is-active --quiet smbd; then
    log_ok "Daemon 'smbd' is actively running."
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    log_err "Daemon 'smbd' failed to start."
fi

# Test 3: SMB user query
log_info "3. Verifying SMB user presence in pdbedit..."
if pdbedit -L -u "$SMB_USER" &>/dev/null; then
    log_ok "User '${SMB_USER}' confirmed in Samba database."
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    log_err "User '${SMB_USER}' was not found in the Samba database."
fi

# Test 4: Live loopback connection and write test
log_info "4. Testing loopback SMB authentication and write access..."
TEST_FILE="smb_test_$(date +%s).tmp"
if smbclient "//127.0.0.1/${SHARE_NAME}" -U "${SMB_USER}%${SMB_PASS}" -c "put /dev/null ${TEST_FILE}; rm ${TEST_FILE}; exit" &>/dev/null; then
    log_ok "Loopback connection and write permissions verified."
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    log_err "Loopback authentication or write test failed."
fi

# ---------------------------------------------------------
# Final Summary Output
# ---------------------------------------------------------
echo ""
echo "=========================================="
if [ "$TESTS_PASSED" -eq "$TOTAL_TESTS" ]; then
    echo -e "${GREEN}Provisioning & Verification Successful! (${TESTS_PASSED}/${TOTAL_TESTS})${NC}"
else
    echo -e "${YELLOW}Provisioning finished with issues. (${TESTS_PASSED}/${TOTAL_TESTS} tests passed)${NC}"
fi
echo "=========================================="
echo "Share Name     : ${SHARE_NAME}"
echo "Local Path     : ${SHARE_DIR}"
echo "Windows UNC    : \\\\${HOST_IP}\\${SHARE_NAME}"
echo "macOS / Linux  : smb://${HOST_IP}/${SHARE_NAME}"
echo "Username       : ${SMB_USER}"
echo "Password       : ${SMB_PASS}"
echo "=========================================="
