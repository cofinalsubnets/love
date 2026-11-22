# HalfKay on the Teensy 4.x, as src/tools/halfkay.l speaks it

Written from public descriptions and from a Teensy 4.1, not from any loader's source:
- PJRC's protocol page (https://www.pjrc.com/teensy/halfkay_protocol.html)
- Paul Stoffregen's forum statements (forum.pjrc.com thread 57176)
- third-party prose descriptions of the 4.x framing

## finding the board
- The board is in HalfKay after its program button is pressed, or after the running
  kernel's usb serial sees the line set to 134 baud (src/inle/usbcdc.h).
- It enumerates as a USB HID device, VID 0x16C0 (PJRC's), PID 0x0478; a 4.1 reports
  bcdDevice 1.08. halfkay.l finds it as the /dev/hidrawN whose
  /sys/class/hidraw/hidrawN/device/uevent names HID_ID 0003:000016C0:00000478, and waits
  for it to appear.
- The device's HID report descriptor, read from sysfs, gives its output report size. A 4.1
  reads: vendor page 0xFF9C, 8-bit items, an output report of 1088, a feature report of 384
  that halfkay.l does not use, and no report id item. halfkay.l refuses any other size by
  name, so an older board or a changed bootloader fails before any write.

## a write
- Each write is one HID output report of 1088 bytes:
  - bytes 0..2 hold the flash offset, little-endian;
  - bytes 3..63 are zero;
  - bytes 64..1087 are 1024 bytes of the image at that offset.
- The offset counts from the start of flash, not from its mapped address. The flash is
  mapped at 0x60000000, so a hex file's addresses would be rebased; love.bin is already
  flash offsets.
- The board uses no report ids, so a hidraw write is 1089 bytes: a leading 0, then the
  report. This matches PJRC's set-report control transfer (0x21, 9, 0x0200).
- The offset is a multiple of 1024. The 4.1's 8 MB flash is 8192 blocks, the 4.0's 1984.

## order and timing
- The first write erases the whole flash, so block 0 is always sent, even when it is all
  0xFF. After it, a block that is all 0xFF is skipped, since the erase left it so.
- Blocks go in ascending order.
- Measured on a 4.1: it takes blocks 0 and 1 at once, then refuses block 2 for 3.3 s
  while it erases. A write of 658 blocks, the erase included, takes 10.6 s; the same image
  written over itself takes 0.8 s.
- So halfkay.l retries any block until 45 s after the write began, and for 0.5 s once that
  window is over. The 45 s is a third party's report for a fully written 4.x flash (Paul:
  the erase "is slower than prior boards"); PJRC's page gives 3 s and 0.2 s for older boards.

## reboot
- One more report with offset bytes 0xFF 0xFF 0xFF and zero data starts the new program.
- The board detaches as it takes this report, so on Linux the write often reports an error;
  and it refuses the report while it is still writing the last blocks. So the write's own
  answer says nothing: halfkay.l sends the report again until the hidraw node goes away, and
  only then counts the program started.

## what it cannot do
- HalfKay has no readback. The proof of a write is the board booting the image
  (test_teensy41_board).
