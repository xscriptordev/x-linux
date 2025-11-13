#!/usr/bin/env bash
set -euo pipefail

# Dont excecute while building mkarchiso
grep -q "/run/archiso/bootmnt" /proc/mounts 2>/dev/null || { return 0 2>/dev/null || exit 0; }

# Allow deactivate
[ "${XOS_NO_AUTO:-0}" = "1" ] && { echo "[XOs] Autoinicio desactivado (XOS_NO_AUTO=1)."; return 0 2>/dev/null || exit 0; }

# Only on TTY1
[ "$(tty)" = "/dev/tty1" ] || { return 0 2>/dev/null || exit 0; }

echo
echo "──────────────────────────────────────────"
echo "   XOs Live – Archinstall will start in 5s"
echo "   Press Ctrl+C to cancel."
echo "──────────────────────────────────────────"

for i in 5 4 3 2 1; do
  printf "\rStarting archinstall in %s s… (Ctrl+C to cancel) " "$i"
  sleep 1
done
echo
echo "→ Starting archinstall (Automated with config)…"
echo

CONF_PATH="./user_configuration.json"
CREDS_PATH="./user_credentials.json"
[ -f "$CONF_PATH" ] || CONF_PATH="/root/user_configuration.json"
[ -f "$CREDS_PATH" ] || CREDS_PATH="/root/user_credentials.json"

# Usar copia temporal para modificaciones, preservando el JSON original
CONF_RUN="$CONF_PATH"
if [ -f "$CONF_PATH" ]; then
  TMP_CONF=$(mktemp)
  cp "$CONF_PATH" "$TMP_CONF"
  CONF_RUN="$TMP_CONF"
fi

ISO_SRC=$(findmnt -n -o SOURCE /run/archiso/bootmnt 2>/dev/null || true)
ISO_PK=""
[ -n "$ISO_SRC" ] && ISO_PK=$(lsblk -no PKNAME "$ISO_SRC" 2>/dev/null | head -n1)
CANDS=$(lsblk -dn -o NAME,TYPE,RM,RO | awk '$2=="disk" && $3=="0" && $4=="0" && $1 !~ /^sr/{print $1}')
MIN_SIZE=${XOS_MIN_SIZE_BYTES:-34359738368}
BEST_EMPTY=""
BEST_EMPTY_SIZE=0
BEST_ANY=""
BEST_ANY_SIZE=0
for n in $CANDS; do
  [ -n "$ISO_PK" ] && [ "$n" = "$ISO_PK" ] && continue
  SIZE=$(blockdev --getsize64 "/dev/$n" 2>/dev/null || echo 0)
  [ "$SIZE" -lt "$MIN_SIZE" ] && continue
  PARTS=$(lsblk -n "/dev/$n" -o TYPE | grep -c '^part$' || true)
  [ "$SIZE" -gt "$BEST_ANY_SIZE" ] && BEST_ANY="$n" && BEST_ANY_SIZE="$SIZE"
  if [ "$PARTS" -eq 0 ] && [ "$SIZE" -gt "$BEST_EMPTY_SIZE" ]; then
    BEST_EMPTY="$n"
    BEST_EMPTY_SIZE="$SIZE"
  fi
done
TARGET="${BEST_EMPTY:-$BEST_ANY}"
if [ -n "${XOS_TARGET_DEVICE:-}" ]; then
  case "${XOS_TARGET_DEVICE}" in
    /dev/*) TARGET="${XOS_TARGET_DEVICE#/dev/}" ;;
    *) TARGET="${XOS_TARGET_DEVICE}" ;;
  esac
fi
if [ -n "$TARGET" ]; then
  echo "[XOs] Target disk selected: /dev/$TARGET"
else
  echo "[XOs] No suitable target disk found, falling back to interactive Archinstall."
fi
if [ -n "$TARGET" ] && [ -f "$CONF_RUN" ]; then
  DEV="/dev/$TARGET"
  python3 - "$CONF_RUN" "$DEV" << 'PY'
import re,sys
p=sys.argv[1]; dev=sys.argv[2]
t=open(p,'r',encoding='utf-8').read()
t=re.sub(r'("device"\s*:\s*")([^"]+)(")', lambda m: m.group(1)+dev+m.group(3), t, count=1)
open(p,'w',encoding='utf-8').write(t)
PY
fi

if [ -f "$CONF_RUN" ]; then
  python3 - "$CONF_RUN" "$TARGET" "${XOS_ROOT_PERCENT:-}" "${XOS_BOOT_SIZE_MIB:-}" << 'PY'
import re,sys,subprocess
p=sys.argv[1]
target=sys.argv[2]
root_pct=sys.argv[3]
boot_mib_arg=sys.argv[4]
t=open(p,'r',encoding='utf-8').read()
def to_mib(unit,val):
    val=int(val)
    if unit in ('GiB','GIB','GiB'): return val*1024
    if unit in ('MiB','MIB','MiB'): return val
    if unit=='B': return val//1048576
    return val
def from_mib(unit,mib):
    mib=int(mib)
    if unit in ('GiB','GIB','GiB'): return mib//1024
    if unit in ('MiB','MIB','MiB'): return mib
    if unit=='B': return mib*1048576
    return mib
m_boot=re.search(r'("mountpoint"\s*:\s*"/boot"[\s\S]*?"size"\s*:\s*\{[\s\S]*?"unit"\s*:\s*"(?P<unit>[A-Za-z]+)"[\s\S]*?"value"\s*:\s*)(?P<val>\d+)', t)
boot_mib=None
if m_boot:
    u=m_boot.group('unit'); v=int(m_boot.group('val'))
    if boot_mib_arg:
        new_val=str(from_mib(u,int(boot_mib_arg)))
        t=re.sub(r'("mountpoint"\s*:\s*"/boot"[\s\S]*?"size"[\s\S]*?"value"\s*:\s*)(\d+)', lambda m: m.group(1)+new_val, t, count=1)
        boot_mib=int(boot_mib_arg)
    else:
        boot_mib=to_mib(u,v)
m_btr=re.search(r'("fs_type"\s*:\s*"btrfs"[\s\S]*?"start"[\s\S]*?"unit"\s*:\s*"(?P<sunit>[A-Za-z]+)"[\s\S]*?"value"\s*:\s*)(?P<sval>\d+)([\s\S]*?"size"[\s\S]*?"unit"\s*:\s*"(?P<bunit>[A-Za-z]+)"[\s\S]*?"value"\s*:\s*)(?P<bval>\d+)', t)
if m_btr:
    su=m_btr.group('sunit'); sv=int(m_btr.group('sval'))
    bu=m_btr.group('bunit'); bv=int(m_btr.group('bval'))
    if boot_mib is not None:
        new_start_val=str(from_mib(su, boot_mib+1))
        t=re.sub(r'("fs_type"\s*:\s*"btrfs"[\s\S]*?"start"[\s\S]*?"value"\s*:\s*)(\d+)', lambda m: m.group(1)+new_start_val, t, count=1)
    if bu=='Percent':
        if root_pct:
            t=re.sub(r'("fs_type"\s*:\s*"btrfs"[\s\S]*?"size"[\s\S]*?"value"\s*:\s*)(\d+)', lambda m: m.group(1)+str(int(root_pct)), t, count=1)
    else:
        disk_bytes=0
        if target:
            try:
                disk_bytes=int(subprocess.check_output(['blockdev','--getsize64','/dev/'+target], text=True).strip())
            except Exception:
                disk_bytes=0
        if disk_bytes>0:
            if boot_mib is not None:
                start_bytes=(boot_mib+1)*1048576
            else:
                if su in ('MiB','MIB','MiB'): start_bytes=sv*1048576
                elif su in ('GiB','GIB','GiB'): start_bytes=sv*1073741824
                elif su=='B': start_bytes=sv
                else: start_bytes=sv*1048576
            rest_bytes=max(0,disk_bytes-start_bytes)
            if bu in ('MiB','MIB','MiB'): new_size_val=rest_bytes//1048576
            elif bu in ('GiB','GIB','GiB'): new_size_val=rest_bytes//1073741824
            elif bu=='B': new_size_val=rest_bytes
            else: new_size_val=rest_bytes//1048576
            t=re.sub(r'("fs_type"\s*:\s*"btrfs"[\s\S]*?"size"[\s\S]*?"value"\s*:\s*)(\d+)', lambda m: m.group(1)+str(new_size_val), t, count=1)
open(p,'w',encoding='utf-8').write(t)
PY
fi

INSTALL_OK=0
if [ -f "$CONF_RUN" ]; then
  if [ -f "$CREDS_PATH" ]; then
    if archinstall --config "$CONF_RUN" --creds "$CREDS_PATH"; then INSTALL_OK=1; fi
  else
    if archinstall --config "$CONF_RUN"; then INSTALL_OK=1; fi
  fi
else
  if archinstall; then INSTALL_OK=1; fi
fi

# Postinstall (branding xos)
if [ "$INSTALL_OK" = "1" ] && [ -f /root/xos-postinstall.sh ]; then
  bash /root/xos-postinstall.sh || true
else
  if [ "$INSTALL_OK" != "1" ]; then
    echo "[XOs] Archinstall failed. Check /var/log/archinstall/install.log for details." || true
  fi
fi
