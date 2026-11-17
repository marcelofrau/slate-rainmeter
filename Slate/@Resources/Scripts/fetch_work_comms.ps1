param([string]$OutFile)

$ErrorActionPreference = 'SilentlyContinue'
. "$PSScriptRoot\load_env.ps1"

$pyCode = @'
import sqlite3, os, re, html, pathlib
from datetime import datetime, timedelta

p = os.path.expandvars(r'%LOCALAPPDATA%\Microsoft\Windows\Notifications\wpndatabase.db')
out = {
    'olk_mail_state': '0 new mail',
    'olk_rem': '0',
    'updated': datetime.now().strftime('%H:%M')
}

# 1. Read New Outlook taskbar new-mail overlay state from Olk logs
has_overlay = False
olog_dir = pathlib.Path(os.path.expandvars(r'%LOCALAPPDATA%\Microsoft\Olk\logs'))
if olog_dir.exists():
    ologs = sorted(olog_dir.glob('olk_*.log'), key=lambda x: x.stat().st_mtime, reverse=True)
    for of in ologs[:2]:
        try:
            txt = of.read_text(encoding='utf-8', errors='ignore')
            for l in reversed(txt.splitlines()):
                if 'outlook-badge-newmail' in l or 'overlayIconSet' in l:
                    has_overlay = True
                    break
                if 'Overlay icon cleared' in l:
                    has_overlay = False
                    break
        except Exception:
            pass
        break

# 2. Pure-Python Snappy decompressor for New Outlook IndexedDB (pre-filtered + slice-optimized)
def read_varint(buf, pos):
    shift = 0
    res = 0
    while pos < len(buf):
        b = buf[pos]
        pos += 1
        res |= (b & 0x7f) << shift
        if (b & 0x80) == 0:
            return res, pos
        shift += 7
    return res, pos

def snappy_decompress(data: bytes) -> bytes:
    ulen, pos = read_varint(data, 0)
    n = len(data)
    out_b = bytearray()
    while pos < n:
        tag = data[pos]
        pos += 1
        ttype = tag & 0x03
        if ttype == 0:
            length = (tag >> 2) + 1
            if length > 60:
                extra = length - 60
                length = int.from_bytes(data[pos:pos+extra], 'little') + 1
                pos += extra
            out_b.extend(data[pos:pos+length])
            pos += length
        else:
            if ttype == 1:
                length = ((tag >> 2) & 0x07) + 4
                offset = ((tag & 0xe0) << 3) | data[pos]
                pos += 1
            elif ttype == 2:
                length = (tag >> 2) + 1
                offset = int.from_bytes(data[pos:pos+2], 'little')
                pos += 2
            else:
                length = (tag >> 2) + 1
                offset = int.from_bytes(data[pos:pos+4], 'little')
                pos += 4
            if offset <= 0 or offset > len(out_b):
                break
            if length <= offset:
                out_b.extend(out_b[-offset:len(out_b)-offset+length])
            else:
                for _ in range(length):
                    out_b.append(out_b[-offset])
    return bytes(out_b)

now_local = datetime.now().astimezone()
today_str = now_local.strftime('%Y-%m-%d')
tmrw_str  = (now_local + timedelta(days=1)).strftime('%Y-%m-%d')
b_today   = today_str.encode()
b_tmrw    = tmrw_str.encode()

def read_ldb(path: pathlib.Path) -> bytes:
    try:
        raw = path.read_bytes()
    except Exception:
        return b''
    if b_today not in raw and b_tmrw not in raw and b'UnreadCount' not in raw and b'CalendarItem' not in raw:
        return b''
    if path.suffix == '.log' or len(raw) < 48: return raw
    footer = raw[-48:]
    _, p0 = read_varint(footer, 0)
    _, p0 = read_varint(footer, p0)
    idx_off, p0 = read_varint(footer, p0)
    idx_sz, p0 = read_varint(footer, p0)
    idx_block = raw[idx_off:idx_off+idx_sz+5]
    if len(idx_block) < 5: return raw
    idx_data = snappy_decompress(idx_block[:-5]) if idx_block[-5] == 1 else idx_block[:-5]
    num_restarts = int.from_bytes(idx_data[-4:], 'little')
    limit = len(idx_data) - 4 * (num_restarts + 1)
    pos = 0
    out_b = bytearray()
    while pos < limit:
        shared, pos = read_varint(idx_data, pos)
        non_shared, pos = read_varint(idx_data, pos)
        val_len, pos = read_varint(idx_data, pos)
        pos += non_shared
        val = idx_data[pos:pos+val_len]
        pos += val_len
        b_off, vp = read_varint(val, 0)
        b_sz, vp = read_varint(val, vp)
        blk = raw[b_off:b_off+b_sz+5]
        if len(blk) == b_sz + 5:
            out_b.extend(snappy_decompress(blk[:-5]) if blk[-5] == 1 else blk[:-5])
    return bytes(out_b)

today_mtgs = {}
tmrw_mtgs  = {}
inbox_unread = None

idb_dir = pathlib.Path(os.path.expandvars(r'%LOCALAPPDATA%\Microsoft\Olk\EBWebView\Default\IndexedDB\https_outlook.office.com_0.indexeddb.leveldb'))
if idb_dir.exists():
    pat = re.compile(rb'((?:' + b_today + rb'|' + b_tmrw + rb')T\d{2}:\d{2}:00\.000Z)')
    inbox_pat = re.compile(rb'distinguishedFolderType".inbox".FolderClass".IPF\.Note".UnreadCountI')
    for f in sorted(list(idb_dir.glob('*.ldb')) + list(idb_dir.glob('*.log')), key=lambda x: x.stat().st_mtime, reverse=True):
        dec = read_ldb(f)
        if not dec:
            continue
        if inbox_unread is None and b'UnreadCountI' in dec:
            im = inbox_pat.search(dec)
            if im:
                v, _ = read_varint(dec, im.end())
                inbox_unread = v >> 1
        if b_today not in dec and b_tmrw not in dec:
            continue
        for m in pat.finditer(dec):
            pos = m.start()
            ctx = dec[max(0, pos-25):min(len(dec), pos+80)]
            if b'Start' in ctx and b'End' in ctx:
                end_m = pat.search(dec[pos+24:pos+100])
                if not end_m:
                    continue
                s = dec.find(b'Subject', pos, min(len(dec), pos+60000))
                if s == -1:
                    continue
                sc = dec[s+7:s+200]
                for marker in [b'TailoredXp', b'Location:', b'".Appointment']:
                    tp = sc.find(marker)
                    if tp != -1: sc = sc[:tp]
                if sc.count(0) > len(sc) // 3:
                    idx0 = next((i for i in range(len(sc)-1) if 32 <= sc[i] < 127 and sc[i+1] == 0), 0)
                    title = sc[idx0:].decode('utf-16le', 'ignore').strip('". \x00')
                else:
                    title = ''.join(chr(x) for x in sc[2:] if 32 <= x < 127).strip('". ')
                if not title or 'Cancelled' in title or 'Canceled' in title:
                    continue
                try:
                    st_utc = datetime.fromisoformat(m.group(1).decode().replace('Z', '+00:00'))
                    et_utc = datetime.fromisoformat(end_m.group(1).decode().replace('Z', '+00:00'))
                    st_loc = st_utc.astimezone(now_local.tzinfo)
                    et_loc = et_utc.astimezone(now_local.tzinfo)
                    if (et_loc - st_loc).total_seconds() >= 20 * 3600:
                        continue
                    sh = st_loc.strftime('%H:%M')
                    eh = et_loc.strftime('%H:%M')
                    d_loc = st_loc.strftime('%Y-%m-%d')
                    if d_loc == today_str and et_loc > now_local:
                        today_mtgs[(sh, title)] = (st_loc, et_loc, f'{sh}-{eh}', title)
                    elif d_loc == tmrw_str:
                        day_abbr = st_loc.strftime('%a')
                        tmrw_mtgs[(sh, title)] = (st_loc, et_loc, f'{day_abbr} {sh}', title)
                except Exception:
                    pass

# 3. Read active toast counts from Notification DB
mail_toasts = 0
if os.path.exists(p):
    con = sqlite3.connect(f'file:{p}?mode=ro', uri=True)
    cur = con.cursor()
    rem_idx = 0
    for hid, ntype, payload in cur.execute("""
        SELECT h.PrimaryId, n.Type, n.Payload
        FROM Notification n
        JOIN NotificationHandler h ON n.HandlerId = h.RecordId
        WHERE h.PrimaryId LIKE '%Outlook%'
        ORDER BY n.ArrivalTime DESC
    """):
        raw = payload.decode('utf-8', 'ignore') if isinstance(payload, bytes) else str(payload)
        if ntype == 'toast':
            if 'Snooze' in raw or ' minutes before start' in raw:
                rem_idx += 1
            else:
                mail_toasts += 1
    out['olk_rem'] = str(rem_idx)

unread_num = max(inbox_unread or 0, mail_toasts)
if unread_num > 0:
    out['olk_mail_state'] = f'{unread_num} new mail'
elif has_overlay:
    out['olk_mail_state'] = '1+ new mail'
else:
    out['olk_mail_state'] = '0 new mail'

sorted_today = sorted(today_mtgs.values(), key=lambda x: x[0])
sorted_tmrw  = sorted(tmrw_mtgs.values(), key=lambda x: x[0])
combined = sorted_today + sorted_tmrw

out['upcoming_count'] = str(len(sorted_today))
for i in range(1, 9):
    if i <= len(combined):
        _, _, tspan, title = combined[i-1]
        out[f'm{i}_time'] = tspan
        out[f'm{i}_title'] = title
    else:
        out[f'm{i}_time'] = '--:--' if i == 1 else ''
        out[f'm{i}_title'] = 'No more meetings today' if i == 1 else ''

for k, v in out.items():
    v = str(v).replace('\r', ' ').replace('\n', ' ')
    print(f'{k}={v}')
'@

$lines = $pyCode | python - 2>$null
if ($OutFile -and $lines) {
    $dir = Split-Path -Parent $OutFile
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllLines($OutFile, $lines, [System.Text.UTF8Encoding]::new($false))
}
