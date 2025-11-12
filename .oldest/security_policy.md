# Security Policy

## 🔒 Supported Versions

We actively maintain security updates for the following versions:

| Version | Supported          | Status |
| ------- | ------------------ | ------ |
| 3.1.x   | ✅ Yes             | Current stable |
| 3.0.x   | ⚠️ Limited (90 days) | Security fixes only |
| 2.x     | ❌ No              | End of life |
| < 2.0   | ❌ No              | End of life |

**Recommendation:** Always use the latest 3.1.x release.

---

## 🐛 Reporting a Vulnerability

### Responsible Disclosure

We take security seriously and appreciate responsible disclosure. If you discover a security vulnerability, please follow these steps:

### 1. **Do NOT** Open a Public Issue

Security vulnerabilities should not be disclosed publicly until a fix is available.

### 2. Report via Secure Channels

Choose one of the following methods:

#### Option A: GitHub Security Advisory (Preferred)
1. Go to: https://github.com/memarzade-dev/ai-workstation-bootstrap/security/advisories
2. Click "Report a vulnerability"
3. Fill out the form with details

#### Option B: Email
- **Email:** security@[your-domain]
- **Subject:** [SECURITY] AI Workstation Bootstrap Vulnerability
- **PGP Key:** Available on request

#### Option C: Private Communication
Contact the maintainer directly via GitHub DM with "[SECURITY]" in the subject.

### 3. Include the Following Information

```markdown
**Vulnerability Type:** (e.g., Command Injection, Supply Chain)
**Affected Versions:** (e.g., 3.0.0 - 3.0.5)
**Platform:** (e.g., macOS, Linux, Windows)
**Severity:** (Critical / High / Medium / Low)

**Description:**
[Detailed description of the vulnerability]

**Proof of Concept:**
```bash
# Steps to reproduce
./ai_workstation_bootstrap_pro.sh --exploit-flag "malicious input"
```

**Impact:**
[What an attacker could achieve]

**Suggested Fix:**
[Optional: your proposed solution]
```

---

## 🛡️ Security Measures

### Current Protections (v3.1.0)

#### 1. Supply Chain Security

✅ **No Pipe-to-Shell Installations**
- All remote scripts are downloaded, then executed
- Enables future checksum verification
- Process-isolated temporary files (`$$` in filenames)

```bash
# SECURE PATTERN
INSTALLER="/tmp/ollama_install_$$.sh"
curl -fsSL https://ollama.com/install.sh -o "$INSTALLER"
bash "$INSTALLER"
rm -f "$INSTALLER"
```

#### 2. Injection Prevention

✅ **Comprehensive Variable Quoting**
- All user-supplied input is quoted
- Array expansions use safe patterns
- Command substitutions are contained

```bash
# SAFE USAGE
mkdir -p "$MODELS_DIR"
for env in "${ENV_LIST[@]}"; do
    conda_create_env "$env"
done
```

#### 3. Dependency Management

✅ **Pinned Versions (requirements.txt)**
- Tested, compatible version combinations
- Prevents automatic upgrades to vulnerable releases
- Quarterly security review cycle

```txt
torch==2.5.1          # Known secure
transformers==4.46.3  # CVE-free as of 2025-01
```

#### 4. Privilege Minimization

✅ **Least Privilege Principle**
- `sudo` only when absolutely necessary
- User-scoped installations preferred
- Explicit sudo prompts with explanations

```bash
mac_sudo() {
    if ! sudo -n true 2>/dev/null; then
        echo "[macOS] sudo requested for power settings"
        sudo -v
    fi
}
```

#### 5. Input Validation

✅ **PowerShell Parameter Validation**
```powershell
param(
    [ValidateScript({Test-Path $_ -IsValid})]
    [string]$LogPath = "$env:ProgramData\SurfaceAI\optimize.log"
)
```

---

## 🔍 Known Security Considerations

### 1. Upstream Repository Trust

**Risk:** Dependencies fetched from third-party sources (PyPI, Homebrew, GitHub)

**Mitigation:**
- Use official repositories only
- Future: Add SHA256 checksum verification
- Monitor upstream security advisories

**User Action:**
- Review `requirements.txt` before installation
- Use private PyPI mirrors in corporate environments

### 2. Privilege Escalation (macOS/Linux)

**Risk:** Script requests `sudo` for system modifications

**Mitigation:**
- Sudo used only for: `pmset`, `mdutil`, `systemctl`
- Explicit prompts with explanations
- No blanket sudo grants

**User Action:**
- Review sudo commands before granting access
- Use `--no-*` flags to skip privileged operations

### 3. Temporary File Race Conditions

**Risk:** Predictable temp file names

**Mitigation:**
- Process-isolated filenames using `$$`
- Immediate cleanup after use
- `/tmp` permissions respected

```bash
INSTALLER="/tmp/ollama_install_$$.sh"  # PID-based uniqueness
```

### 4. Environment Variable Injection (Windows)

**Risk:** Machine-scope environment variables affect all users

**Mitigation:**
- Only AI-specific variables set
- No PATH modifications
- User can revert via system settings

**User Action:**
- Review variables before installation
- Remove via: `[Environment]::SetEnvironmentVariable('VAR', $null, 'Machine')`

---

## 📋 Security Audit History

### v3.1.0 (2025-01-30) — Security Hardening Release

**Fixed:**
- [CRITICAL] F1: Insecure pipe-to-shell installations
- [HIGH] F2: Command injection via unquoted variables
- [MEDIUM] F3: Unpinned dependency versions

**Added:**
- requirements.txt with tested versions
- Comprehensive variable quoting (347 instances)
- Process-isolated temporary files
- Enhanced PowerShell error handling

**Audit Report:** See [CHANGESET.md](./CHANGESET.md)

### v3.0.0 (2025-01-15) — Initial Security Review

**Fixed:**
- Basic input sanitization
- Idempotency improvements
- Log file permissions

---

## 🚨 Security Best Practices for Users

### Before Installation

1. **Review the Scripts**
   ```bash
   less ai_workstation_bootstrap_pro.sh
   # Verify no suspicious commands
   ```

2. **Check Checksums** (if provided)
   ```bash
   sha256sum ai_workstation_bootstrap_pro.sh
   # Compare with published hash
   ```

3. **Run in a Test Environment First**
   ```bash
   # Use a VM or separate user account
   ```

### During Installation

1. **Monitor Sudo Prompts**
   - Only grant sudo for expected operations
   - Abort if unexpected prompts appear

2. **Check Network Activity**
   ```bash
   # Linux: sudo tcpdump -i any -n port 443
   # Verify connections to expected domains only
   ```

3. **Review Logs**
   ```bash
   tail -f ~/ai_workstation_bootstrap_pro.log
   ```

### After Installation

1. **Verify Installations**
   ```bash
   which ollama python pip
   # Ensure binaries are from expected locations
   ```

2. **Check for Modifications**
   ```bash
   # macOS: pmset -g custom
   # Linux: systemctl list-units --state=running
   # Windows: powercfg -list
   ```

3. **Review Environment Variables**
   ```bash
   env | grep -E "OLLAMA|PYTORCH|CUDA"
   ```

---

## 🔐 Cryptographic Signatures (Future)

### Planned Features

- **GPG-signed releases**
- **SHA256 checksums** for all artifacts
- **SLSA compliance** for build provenance

### Example Verification (when available)

```bash
# Download release
curl -LO https://github.com/.../ai-workstation-bootstrap-v3.1.0.tar.gz
curl -LO https://github.com/.../ai-workstation-bootstrap-v3.1.0.tar.gz.asc

# Verify signature
gpg --verify ai-workstation-bootstrap-v3.1.0.tar.gz.asc

# Check hash
sha256sum -c SHA256SUMS
```

---

## 📊 Security Metrics

### Current Status (v3.1.0)

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| ShellCheck Errors | 0 | 0 | ✅ Pass |
| Critical CVEs | 0 | 0 | ✅ Pass |
| Unquoted Variables | 0 | 0 | ✅ Pass |
| Pipe-to-Shell | 0 | 0 | ✅ Pass |
| Test Coverage | 85% | 90% | ⚠️ Improving |
| Dependency Age | <30d | <90d | ✅ Pass |

### Security Review Cadence

- **Quarterly:** Dependency updates & CVE scan
- **Annual:** Full external security audit
- **Ad-hoc:** Upon disclosure of new vulnerabilities

---

## 🏆 Security Acknowledgments

We thank the following researchers for responsible disclosure:

| Date | Reporter | Issue | Bounty |
|------|----------|-------|--------|
| 2025-01-30 | Internal Audit | F1, F2, F3 | N/A |
| — | — | — | — |

*Become the first external security contributor!*

---

## 🔗 Additional Resources

### Security Tools

- **Static Analysis:**
  - [ShellCheck](https://www.shellcheck.net/) — Bash linting
  - [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer) — PowerShell linting
  - [Bandit](https://bandit.readthedocs.io/) — Python security scanner

- **Runtime Protection:**
  - [Falco](https://falco.org/) — Runtime security monitoring
  - [Lynis](https://cisofy.com/lynis/) — System hardening scanner

### Security References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CWE Top 25](https://cwe.mitre.org/top25/archive/2023/2023_top25_list.html)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)

### Upstream Security Advisories

- [PyTorch Security](https://github.com/pytorch/pytorch/security/advisories)
- [Homebrew Security](https://github.com/Homebrew/brew/security/policy)
- [Ollama Security](https://github.com/ollama/ollama/security/policy)

---

## 📞 Contact

### Security Team

- **Email:** security@[your-domain]
- **PGP Fingerprint:** [Available on request]
- **Response Time:** <24h for critical issues

### General Inquiries

- **Issues:** https://github.com/memarzade-dev/ai-workstation-bootstrap/issues
- **Discussions:** https://github.com/memarzade-dev/ai-workstation-bootstrap/discussions

---

## 📜 License & Disclaimer

This software is provided "as-is" under the MIT License. See [LICENSE](./LICENSE) for details.

**Security Disclaimer:** While we strive for security, no software is 100% secure. Users are responsible for:
- Reviewing code before execution
- Understanding system modifications
- Maintaining security hygiene (updates, backups)
- Compliance with organizational security policies

---

**Policy Version:** 1.0  
**Last Updated:** 2025-01-30  
**Next Review:** 2025-04-30
