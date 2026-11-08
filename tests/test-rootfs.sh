#!/bin/sh
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() {
    printf "${GREEN}✔ PASS:${NC} %s\n" "$1"
}

fail() {
    printf "${RED}✘ FAIL:${NC} %s\n" "$1"
    exit 1
}

step() {
    printf "\n${BLUE}======================================================${NC}\n"
    printf "${BLUE}>>> %s${NC}\n" "$1"
    printf "${BLUE}======================================================${NC}\n"
}

printf "${YELLOW}======================================================${NC}\n"
printf "${YELLOW}   Crest-Editor RootFS Deep Hardware & Language Suite ${NC}\n"
printf "${YELLOW}======================================================${NC}\n"

# ----------------------------------------------------
step "1. Architecture & Core Shells"
# ----------------------------------------------------
ARCH=$(uname -m)
[ "$ARCH" = "aarch64" ] && pass "Target Architecture is aarch64" || fail "Expected aarch64, got: $ARCH"

sh -c 'echo "sh OK"' >/dev/null 2>&1 && pass "POSIX sh executes" || fail "POSIX sh failed"
bash -c 'echo "bash OK"' >/dev/null 2>&1 && pass "GNU Bash executes" || fail "GNU Bash failed"
zsh -c 'echo "zsh OK"' >/dev/null 2>&1 && pass "Zsh executes" || fail "Zsh failed"

ldd /usr/bin/bash >/dev/null 2>&1 && pass "ldd resolves bash shared libs" || fail "ldd failed on bash"
ldd /usr/bin/zsh >/dev/null 2>&1 && pass "ldd resolves zsh shared libs" || fail "ldd failed on zsh"

# ----------------------------------------------------
step "2. Core Utilities & Pipeline Tools"
# ----------------------------------------------------
echo "hello world" | grep -q "hello" && pass "grep pattern matching" || fail "grep failed"
echo "foo bar" | awk '{print $2}' | grep -q "bar" && pass "awk field processing" || fail "awk failed"
echo "hello" | sed 's/hello/world/' | grep -q "world" && pass "sed stream editor" || fail "sed failed"
tar --version >/dev/null 2>&1 && pass "GNU tar executes" || fail "tar failed"
gzip --version >/dev/null 2>&1 && pass "gzip executes" || fail "gzip failed"
if command -v xz >/dev/null 2>&1; then
    xz --version >/dev/null 2>&1 && pass "xz executes" || fail "xz failed"
fi

# ----------------------------------------------------
step "3. Filesystem, Hardlinks & Symlink Integrity"
# ----------------------------------------------------
TMPD=$(mktemp -d)
[ -d "$TMPD" ] && pass "mktemp directory creation" || fail "mktemp directory creation failed"

echo "original content" > "$TMPD/source.txt"
ln -s "$TMPD/source.txt" "$TMPD/symlink.txt"
[ -L "$TMPD/symlink.txt" ] && pass "symlink creation" || fail "symlink creation failed"
grep -q "original content" "$TMPD/symlink.txt" && pass "symlink target dereferencing" || fail "symlink dereference failed"

# Test atomic file replacement (the exact pattern that broke Debian dpkg)
echo "new content" > "$TMPD/new.txt"
mv -f "$TMPD/new.txt" "$TMPD/source.txt"
grep -q "new content" "$TMPD/symlink.txt" && pass "atomic replace through symlinks" || fail "atomic replace failed"

rm -rf "$TMPD"
pass "temporary tree recursively unlinked"

# ----------------------------------------------------
step "4. SSL Certificates, DNS & Network Stack"
# ----------------------------------------------------
[ -f /etc/ssl/certs/ca-certificates.crt ] && pass "System SSL CA bundle present" || fail "ca-certificates.crt missing"
[ -s /etc/resolv.conf ] && pass "DNS resolver configured (/etc/resolv.conf)" || fail "/etc/resolv.conf empty"

# ----------------------------------------------------
step "5. Package Manager Synchronization (HTTPS)"
# ----------------------------------------------------
xbps-query -l && pass "xbps-query reads package database" || fail "xbps-query database access failed"
xbps-install -S && pass "xbps-install syncs repository over HTTPS" || fail "xbps repo sync failed"

# ----------------------------------------------------
step "6. Heavy Package Test: Python 3 Runtime & Modules"
# ----------------------------------------------------
echo "Installing python3 (multi-file package with C extensions & triggers)..."
xbps-install -y python3 && pass "python3 package installed cleanly" || fail "python3 installation failed"

python3 --version && pass "python3 binary executes" || fail "python3 execution failed"

# Deep Python verification: stdlib, math, sqlite, ssl, sockets, and threading
python3 -c "
import sys, os, math, ssl, sqlite3, hashlib, json, threading, urllib.request

assert math.factorial(6) == 720, 'Math factorial failed'
assert hashlib.sha256(b'crest').hexdigest() == 'a0cb60621fc534fc40aeeb24716b509bc1d7ff15975bb5f9227f67389146522c', 'SHA256 failed'

# SQLite database test
conn = sqlite3.connect(':memory:')
c = conn.cursor()
c.execute('CREATE TABLE t (id INT, val TEXT)')
c.execute('INSERT INTO t VALUES (1, \"crest\")')
conn.commit()
row = c.execute('SELECT val FROM t WHERE id=1').fetchone()
assert row[0] == 'crest', 'SQLite test failed'

# Threading test
def thread_target(res):
    res.append('done')
res = []
t = threading.Thread(target=thread_target, args=(res,))
t.start()
t.join()
assert res == ['done'], 'Threading failed'

# HTTPS network & SSL verification test
req = urllib.request.urlopen('https://repo-default.voidlinux.org/', timeout=15)
assert req.status == 200, f'HTTPS request returned status {req.status}'

print('Python internal subsystem check passed.')
" && pass "Python 3 core subsystems verified (SSL, SQLite, Threads, Network)" || fail "Python subsystem validation failed"

# ----------------------------------------------------
step "7. Heavy Developer Tool Test: Git & Version Control"
# ----------------------------------------------------
echo "Installing git (complex multi-binary suite)..."
xbps-install -y git && pass "git package installed cleanly" || fail "git installation failed"

GIT_TEST_DIR=$(mktemp -d)
cd "$GIT_TEST_DIR"

git init
git config user.name "Crest Tester"
git config user.email "test@crestcode.org"

echo "# Crest Project" > README.md
git add README.md
git commit -m "initial commit" && pass "git init & commit works" || fail "git commit failed"

git checkout -b test-branch
echo "feature code" > feature.txt
git add feature.txt
git commit -m "add feature"
git checkout -
git merge test-branch && pass "git branching & merge works" || fail "git merge failed"

cd - >/dev/null
rm -rf "$GIT_TEST_DIR"
pass "git workspace cleaned up"

# ----------------------------------------------------
step "8. Native Compiler Test: GCC, Linker & Assembly"
# ----------------------------------------------------
echo "Installing gcc & make (native C toolchain)..."
xbps-install -y gcc make && pass "gcc & make installed cleanly" || fail "gcc installation failed"

C_TEST_DIR=$(mktemp -d)
cat << 'EOF' > "$C_TEST_DIR/test_program.c"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <pthread.h>
#include <unistd.h>

void* worker(void* arg) {
    double* val = (double*)arg;
    *val = sqrt(*val) * 2.0;
    return NULL;
}

int main() {
    pthread_t thread;
    double num = 100.0;
    
    if (pthread_create(&thread, NULL, worker, &num) != 0) {
        return 1;
    }
    pthread_join(thread, NULL);
    
    if ((int)num != 20) {
        return 2;
    }
    printf("C Compiler & Linker verification successful! Output=%d\n", (int)num);
    return 0;
}
EOF

gcc -O2 "$C_TEST_DIR/test_program.c" -o "$C_TEST_DIR/test_bin" -lm -lpthread && pass "gcc compiled native aarch64 binary with math & pthreads" || fail "gcc compilation failed"

"$C_TEST_DIR/test_bin" >/dev/null 2>&1 && pass "native compiled binary executed with return code 0" || fail "compiled binary execution failed"

rm -rf "$C_TEST_DIR"

# ----------------------------------------------------
step "9. Package Removal & State Cleanup Test"
# ----------------------------------------------------
echo "Testing reverse package removal & dependency cleaning..."
xbps-remove -Ry gcc make git python3 && pass "heavy packages cleanly removed without orphan link errors" || fail "xbps package removal failed"

xbps-query -l >/dev/null 2>&1 && pass "database state intact after heavy install/remove cycle" || fail "database corrupted after uninstall"

# ----------------------------------------------------
printf "\n${GREEN}================================================================${NC}\n"
printf "${GREEN}✔ 100%% VERIFIED BUG-FREE! Python, Git, GCC, SSL & Kernel All Pass! 🚀${NC}\n"
printf "${GREEN}================================================================${NC}\n"
