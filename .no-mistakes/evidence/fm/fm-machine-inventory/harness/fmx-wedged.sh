#!/usr/bin/env bash
# Real inventory, real GNU timeout / lsof / ps / simctl; only `docker` is a shim that hangs like a wedged Docker Desktop.
WT=/Users/davidbeihl/.no-mistakes/worktrees/b5ea5ab83d56/01M2E9V4VAWMY14EX6EQKVK2RN
shim=$(mktemp -d /tmp/fmx-wedged.XXXXXX)
cat > "$shim/docker" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$$" >> "$(dirname "$0")/docker-pids"
exec sleep 600
SH
chmod +x "$shim/docker"
now() { perl -MTime::HiRes=time -e 'printf "%.1f", time'; }
echo "== A: wedged docker ps, run to completion (mechanism: $(bash -c ". $WT/bin/fm-timeout-lib.sh; fm_timeout_mechanism"))"
t0=$(now)
PATH="$shim:$PATH" "$WT/bin/fm-machine-inventory.sh" > "$shim/outA"; rc=$?
printf '[exit %s after %.1fs]\n' "$rc" "$(echo "$(now) - $t0" | bc)"
grep -v '^LISTENER' "$shim/outA"; echo "[$(grep -c '^LISTENER' "$shim/outA") LISTENER lines omitted]"
for p in $(cat "$shim/docker-pids"); do kill -0 "$p" 2>/dev/null && echo "hung docker pid $p STILL ALIVE" || echo "hung docker pid $p stopped by bound"; done
: > "$shim/docker-pids"
echo; echo "== B: wedged docker ps, Ctrl-C (INT to the inventory's process group) while the query hangs"
( out=$(PATH="$shim:$PATH" perl -e '$SIG{INT}="DEFAULT"; setpgrp(0,0); exec @ARGV' "$WT/bin/fm-machine-inventory.sh"); echo "$?" > "$shim/rcB"; printf '%s\n' "$out" > "$shim/outB" ) &
sub=$!
while [ ! -s "$shim/docker-pids" ]; do sleep 0.2; done
sleep 1
dpid=$(head -1 "$shim/docker-pids")
inv=$(pgrep -f "$WT/bin/fm-machine-inventory.sh$" | head -1)
echo "[in-flight query: docker pid $dpid pgid $(ps -o pgid= -p "$dpid"); inventory pgid $inv]"
t0=$(now); kill -INT -- "-$inv"; wait "$sub"
printf '[consumer saw EOF %.1fs after Ctrl-C; exit %s]\n' "$(echo "$(now) - $t0" | bc)" "$(cat "$shim/rcB")"
grep -v '^LISTENER' "$shim/outB"; echo "[$(grep -c '^LISTENER' "$shim/outB") LISTENER lines omitted]"
sleep 2
kill -0 "$dpid" 2>/dev/null && { echo "in-flight docker query STILL ALIVE after interrupt"; kill -KILL "$dpid"; } || echo "in-flight docker query stopped by interrupt cleanup"
rm -rf "$shim"
