#!/usr/bin/env bash
WT=/Users/davidbeihl/.no-mistakes/worktrees/b5ea5ab83d56/01M2E9V4VAWMY14EX6EQKVK2RN
now() { perl -MTime::HiRes=time -e 'printf "%.2f", time'; }
descendants() {  # <pid> -> pid list of all descendants
  local kids k
  kids=$(pgrep -P "$1")
  for k in $kids; do printf '%s\n' "$k"; descendants "$k"; done
}
drive() {  # <signal> <delay> <target: group|pid>
  local sig=$1 delay=$2 target=$3 out inv tree pids sent done_t sub left
  out=$(mktemp /tmp/fmx-int.XXXXXX)
  # inventory gets its own process group (as a foreground job would); the $(...) consumer stays outside it
  ( out_text=$(perl -e '$SIG{INT}="DEFAULT"; setpgrp(0,0); exec @ARGV' "$WT/bin/fm-machine-inventory.sh"); rc=$?; printf '%s\n[inventory exit %s]\n' "$out_text" "$rc" > "$out" ) &
  sub=$!
  sleep "$delay"
  inv=$(pgrep -f "^bash $WT/bin/fm-machine-inventory.sh|$WT/bin/fm-machine-inventory.sh$" | head -1)
  pids=$(descendants "$inv" | tr '\n' ' ')
  tree=$(for p in $pids; do ps -o pid=,pgid=,command= -p "$p" 2>/dev/null | cut -c1-90; done)
  if [ "$target" = group ]; then kill -"$sig" -- "-$inv"; else kill -"$sig" "$inv"; fi
  sent=$(now)
  wait "$sub"
  done_t=$(now)
  sleep 2
  left=$(for p in $pids; do ps -o pid=,command= -p "$p" 2>/dev/null | cut -c1-90; done)
  printf '$ SIG%s sent to inventory %s (pid/pgid %s) after %ss\n' "$sig" "$target" "$inv" "$delay"
  printf '[inventory descendants at signal (pid pgid command):]\n%s\n[output:]\n' "$tree"
  cat "$out"
  printf '[consumer $(...) saw EOF %.2fs after the signal]\n' "$(echo "$done_t - $sent" | bc)"
  printf '[those descendants still alive 2s later: %s]\n\n' "${left:-none}"
  rm -f "$out"
}
drive TERM 1 pid
drive INT 1.5 group
drive INT 6 group
drive TERM 0.5 group
drive HUP 8 group
