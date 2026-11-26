; said -- a line to the phone's log: lore runs on a terminal's pty there, so its stderr is the
; terminal's. (said s): under android's bridge alone (LOVE_DROID), an info line by android's
; own Log, tagged love
(module (said said)
(borrow 'posix)    ; close
(:
 (said s) ((cite 'droid 'jni-open) 0 @ d (? !(port? d) ()
   (: c ((cite 'droid 'jni-class) d "android/util/Log")
      _ (charm? c ? ((cite 'droid 'jni-static) d c "i" "(Ljava/lang/String;Ljava/lang/String;)I" ["love" s]))
      (close d, ())))))
) ; module said
