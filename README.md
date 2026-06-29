# doas-enum

> Fast doas permission enumerator — find every command you can run with or without a password.

---

## Features

- ⚡ **Lightning fast** — tests all `$PATH` executables concurrently
- 🎯 **Accurate detection** — distinguishes between `nopass` and password-required rules
- 🎨 **Color-coded output** — green for no password, yellow for password required
- 🔧 **Zero dependencies** — pure POSIX shell, no external tools required
- 👤 **User targeting** — test permissions for any user with `-u`

---

## Installation

```bash
# Clone the repository
git clone https://github.com/yanxinwu946/doas-enum
cd doas-enum

# Make it executable
chmod +x doas-enum.sh

# Or download directly
curl -O https://raw.githubusercontent.com/yanxinwu946/doas-enum/main/doas-enum.sh
chmod +x doas-enum.sh
```

---

## Usage

```bash
./doas-enum.sh [-u user] [-h]
```

| Option | Description |
|--------|-------------|
| `-u user` | Target user to test (default: current user) |
| `-h` | Show help message |

### Examples

```bash
# Test current user
./doas-enum.sh

# Test another user
./doas-enum.sh -u elena
```

---

## How It Works

1. **Discovery** — finds `doas` binary and parses all configuration files (`/etc/doas.conf`, `/etc/doas.d/*.conf`)

2. **Collection** — enumerates every executable file in your `$PATH`

3. **Concurrent Testing** — launches all tests in parallel:
   ```bash
   doas [-u user] <command> --help
   ```

4. **Classification**:
   - ✅ **No password** — command executes immediately (exit code 0) → `permit nopass`
   - ⚠️ **Password required** — process hangs waiting for password input → `permit` (without nopass)
   - ❌ **Not allowed** — command exits with error → no output

5. **Results** — displays color-coded summary of allowed commands

### Why `--help`?

- Most commands support `--help` and exit immediately — safe and non-destructive
- Allows testing without actually executing potentially dangerous commands
- Exit code 0 confirms the command is permitted

---

## Example Output

```
=== DOAS ENUM ===
Target user: silas

[*] binary
-rwsr-xr-x 1 root root 34824 Oct 11 2024 /usr/bin/doas

[*] configs
[+] /etc/doas.conf
permit silas as root cmd /usr/bin/id
permit nopass silas as root cmd /usr/bin/vi

[*] probing 559 commands...

=== DONE ===

========================================
[!] ALLOWED (no password):
========================================
  doas /usr/bin/vi

========================================
[!] ALLOWED (password required):
========================================
  doas /usr/bin/id
```

---

## Troubleshooting

### Terminal gets messed up after running
The script restores terminal settings automatically. If issues persist, run:
```bash
reset
```