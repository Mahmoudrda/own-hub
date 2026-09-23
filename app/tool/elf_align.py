"""Read p_align of every PT_LOAD segment in a 64-bit ELF.

Play requires 16 KB page alignment (p_align >= 16384) on 64-bit native
libraries. This parses the program header table rather than shelling out to a
toolchain, so it runs anywhere Python does.
"""
import struct
import sys

PT_LOAD = 1


def loads(path):
    with open(path, 'rb') as f:
        data = f.read()
    if data[:4] != b'\x7fELF':
        return None
    if data[4] != 2:  # not 64-bit
        return None
    little = data[5] == 1
    end = '<' if little else '>'
    e_phoff, = struct.unpack_from(end + 'Q', data, 0x20)
    e_phentsize, e_phnum = struct.unpack_from(end + 'HH', data, 0x36)
    out = []
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        p_type, = struct.unpack_from(end + 'I', data, off)
        if p_type != PT_LOAD:
            continue
        p_align, = struct.unpack_from(end + 'Q', data, off + 0x30)
        out.append(p_align)
    return out


worst_overall = None
for path in sys.argv[1:]:
    aligns = loads(path)
    if aligns is None:
        print('  %-46s not a 64-bit ELF' % path.split('lib/')[-1])
        continue
    worst = min(aligns)
    verdict = 'OK' if worst >= 16384 else 'TOO SMALL, Play will flag this'
    print('  %-46s p_align %6d  %s' % (path.split('lib/')[-1], worst, verdict))
    worst_overall = worst if worst_overall is None else min(worst_overall, worst)

if worst_overall is not None:
    print()
    print('smallest alignment across every 64-bit library: %d (%s)' % (
        worst_overall, 'OK' if worst_overall >= 16384 else 'FAILS the 16 KB rule'))
