; test_uefi_stay's boot.l, laid at its ESP's root for the menu (test/kernel/stay.l reads it back);
; the second entry's ramdisk is this file itself
(timeout 3)
(default 1)
(entry "efihello" "/efihello.efi" "one two")
(entry "efihello, a ramdisk" "/efihello.efi" "three" "/boot.l")
