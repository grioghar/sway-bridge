#!/usr/bin/env python3
"""Read-only probe of the Sway's serial configuration protocol.

Frame:  53 57 41 59 | cmd u8 | len u16 LE | payload | xor(cmd, len bytes, payload)

Only sends requests that read state. Never sends a Send*/FirmwareUpgrade command.
usage: probe.py [--dump-project FILE] [--dump-preset FILE]
"""
import argparse, glob, struct, sys, time
import serial

MAGIC = b"SWAY"
ACK, ERROR, HANDSHAKE = 0x01, 0x02, 0x03
# Host sends the bare command to read; the Sway answers with the same command + data.
PROJECT_HEADER, PROJECT_FRAGMENT = 0x11, 0x12      # header -> u32 size; fragment <- u16 index, -> <=56 bytes
PRESET_HEADER, PRESET_FRAGMENT = 0x21, 0x22        # same, for the selected preset
PRESET_SELECTION, REQ_PRESET_SELECTION = 0x23, 0x25  # -> bank u8, preset u8
BRIGHTNESS = 0x31                                  # -> u8
EEPROM_HEADER, EEPROM_FRAGMENT = 0x41, 0x42
# Write-side commands (0x13, 0x23, 0x24, 0x32, 0x43, 0x04, 0xff) are deliberately not defined here.
FRAGMENT = 56
NAMES = {v: k for k, v in list(globals().items()) if isinstance(v, int) and k.isupper()}


def frame(cmd, payload=b""):
    body = bytes([cmd]) + struct.pack("<H", len(payload)) + payload
    x = 0
    for b in body:
        x ^= b
    return MAGIC + body + bytes([x])


class Sway:
    def __init__(self, path=None, verbose=True):
        path = path or (glob.glob("/dev/cu.usbmodem*") or [None])[0]
        if not path:
            sys.exit("no /dev/cu.usbmodem* port")
        self.s = serial.Serial(path, 115200, timeout=1.0, exclusive=True)
        self.v = verbose
        time.sleep(0.2)
        self.s.reset_input_buffer()

    def send(self, cmd, payload=b""):
        f = frame(cmd, payload)
        if self.v:
            print(f"> {NAMES.get(cmd, hex(cmd)):22s} {f.hex(' ')[:90]}")
        self.s.write(f)
        self.s.flush()

    def recv(self, timeout=1.5):
        self.s.timeout = timeout
        buf = b""
        while not buf.endswith(MAGIC):          # resync on the marker
            c = self.s.read(1)
            if not c:
                if self.v:
                    print(f"< (timeout) stray={buf.hex(' ')}")
                return None, b""
            buf += c
        head = self.s.read(3)
        if len(head) < 3:
            return None, b""
        cmd, ln = head[0], struct.unpack("<H", head[1:3])[0]
        payload = self.s.read(ln)
        chk = self.s.read(1)
        x = 0
        for b in head + payload:
            x ^= b
        ok = chk and chk[0] == x
        if self.v:
            print(f"< {NAMES.get(cmd, hex(cmd)):22s} len={ln:<5d} {'ok ' if ok else 'BAD'} {payload[:40].hex(' ')}")
        return cmd, payload

    def fetch(self, header_cmd, fragment_cmd):
        """Read a blob: ask for its size, then pull 56-byte fragments by index."""
        self.send(header_cmd)
        cmd, p = self.recv()
        if cmd != header_cmd or len(p) != 4:
            return None
        size = struct.unpack("<I", p)[0]
        out = b""
        self.v, v = False, self.v
        for i in range((size + FRAGMENT - 1) // FRAGMENT):
            self.send(fragment_cmd, struct.pack("<H", i))
            cmd, p = self.recv(3)
            if cmd != fragment_cmd:
                print("unexpected reply", cmd, "at fragment", i); break
            out += p
        self.v = v
        print(f"  fetched {len(out)}/{size} bytes")
        return out[:size] if len(out) >= size else None


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--port")
    ap.add_argument("--dump-project")
    ap.add_argument("--dump-preset")
    a = ap.parse_args()
    d = Sway(a.port)
    d.send(HANDSHAKE)
    cmd, p = d.recv()
    if cmd == HANDSHAKE and len(p) >= 23:
        name = p[:20].split(b"\0")[0].decode(errors="replace")
        print(f"  name={name!r} firmware={p[20]}.{p[21]}.{p[22]} extra={p[23:].hex(' ')}")
    for req in (REQ_PRESET_SELECTION, BRIGHTNESS):
        d.send(req)
        d.recv()
    if a.dump_preset:
        blob = d.fetch(PRESET_HEADER, PRESET_FRAGMENT)
        if blob:
            open(a.dump_preset, "wb").write(blob)
    if a.dump_project:
        blob = d.fetch(PROJECT_HEADER, PROJECT_FRAGMENT)
        if blob:
            open(a.dump_project, "wb").write(blob)
