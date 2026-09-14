#!/usr/bin/env bash
# Real inventory against the real host (real lsof, ps, docker, simctl); only the load and core-count readers are
# replaced so the host reports what the incident host reported: ten online cores, fifteen-minute load 31.
WT=/Users/davidbeihl/.no-mistakes/worktrees/b5ea5ab83d56/01M2E9V4VAWMY14EX6EQKVK2RN
shim=$(mktemp -d /tmp/fmx-load.XXXXXX)
printf '#!/usr/bin/env bash\n[ "${2:-}" = vm.loadavg ] && { echo "{ 29.40 30.12 31.00 }"; exit 0; }\nexec /usr/sbin/sysctl "$@"\n' > "$shim/sysctl"
printf '#!/usr/bin/env bash\n[ "${1:-}" = _NPROCESSORS_ONLN ] && { echo 10; exit 0; }\nexec /usr/bin/getconf "$@"\n' > "$shim/getconf"
chmod +x "$shim"/*
echo '$ bin/fm-machine-inventory.sh   # host reporting 10 online cores, loadavg { 29.40 30.12 31.00 }'
PATH="$shim:$PATH" "$WT/bin/fm-machine-inventory.sh"; echo "[exit $?]"
echo; echo '$ bin/fm-machine-inventory.sh   # boundary: 10 cores, fifteen-minute load exactly 10.00 (not above one per core)'
printf '#!/usr/bin/env bash\n[ "${2:-}" = vm.loadavg ] && { echo "{ 12.00 11.00 10.00 }"; exit 0; }\nexec /usr/sbin/sysctl "$@"\n' > "$shim/sysctl"
PATH="$shim:$PATH" "$WT/bin/fm-machine-inventory.sh" | grep -E '^LOAD|load' || echo "(no LOAD line)"
echo; echo '$ bin/fm-machine-inventory.sh   # load reader broken: sysctl and /proc/loadavg both unavailable'
printf '#!/usr/bin/env bash\n[ "${2:-}" = vm.loadavg ] && exit 1\nexec /usr/sbin/sysctl "$@"\n' > "$shim/sysctl"
PATH="$shim:$PATH" "$WT/bin/fm-machine-inventory.sh" | grep -E '^LOAD|load' || echo "(no load line)"
rm -rf "$shim"
