; a/kore/asbook.l -- make sure the assembler module is registered for the cat:
; the wrapped l/holo files (backends, elf/obj/link, copy) reopen module 'holo,
; and holo's readers say (borrow 'holo) scoped or probe (cite 'holo ..) -- nothing
; reads it off an ambient splice anymore. the load rides an anonymous module
; layer -- registered nowhere, so use's splice is popped and nothing lands in
; the cat's own walk -- enter/leave are mopped, module carries them as values,
; so this is the door that works off the book. kore's cat
; order: .. asbook.l, l/holo/elf.l, ..; mooncc's: this, then the cross
; backends join the module (defbackend mutates its table), then elf/obj/link.
(module () (borrow 'holo))
