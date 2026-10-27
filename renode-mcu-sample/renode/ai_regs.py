# Eight 12-bit analog input channels at offsets 0x00..0x1C (word each).
# Robot / Monitor can Feed values with: sysbus WriteDoubleWord <AI_BASE+4*n> <0..4095>
if request.isInit:
    channels = [0] * 8
elif request.isRead:
    idx = request.offset // 4
    if 0 <= idx < 8:
        request.value = channels[idx] & 0xFFF
    else:
        request.value = 0
elif request.isWrite:
    idx = request.offset // 4
    if 0 <= idx < 8:
        channels[idx] = request.value & 0xFFF
