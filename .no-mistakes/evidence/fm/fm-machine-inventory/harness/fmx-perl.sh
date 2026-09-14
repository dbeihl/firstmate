#!/usr/bin/env bash
WT=/Users/davidbeihl/.no-mistakes/worktrees/b5ea5ab83d56/01M2E9V4VAWMY14EX6EQKVK2RN
shim=$(mktemp -d /tmp/fmx-perl.XXXXXX)
ln -s /opt/homebrew/bin/docker "$shim/docker"
STOCK="$shim:/usr/bin:/bin:/usr/sbin:/sbin"   # stock macOS PATH: no coreutils timeout/gtimeout
now() { perl -MTime::HiRes=time -e 'printf "%.1f", time'; }
echo "== perl fallback of bin/fm-timeout-lib.sh fm_run_timed (the one-line shared-library change)"
PATH=$STOCK bash -c '
  . '"$WT"'/bin/fm-timeout-lib.sh
  echo "mechanism: $(fm_timeout_mechanism)"
  out=$(fm_run_timed 5 printf "%s" passthrough); echo "stdout passthrough: $out (rc $?)"
  fm_run_timed 5 sh -c "exit 3"; echo "child exit status preserved: rc $?"
  s=$(perl -MTime::HiRes=time -e "printf q(%.1f), time"); fm_run_timed 1 sleep 30; rc=$?
  printf "bound enforced: rc %s after %.1fs\n" "$rc" "$(echo "$(perl -MTime::HiRes=time -e "printf q(%.1f), time") - $s" | bc)"
'
echo; echo "== full inventory on the real host under the perl fallback"
t0=$(now)
PATH=$STOCK "$WT/bin/fm-machine-inventory.sh" > "$shim/out"; rc=$?
printf '[exit %s after %.1fs]\n' "$rc" "$(echo "$(now) - $t0" | bc)"
grep -v '^LISTENER' "$shim/out"; echo "[$(grep -c '^LISTENER' "$shim/out") LISTENER lines omitted]"
rm -rf "$shim"
