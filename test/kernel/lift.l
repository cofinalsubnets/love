; test/kernel/lift.l -- a file carried out of the machine the way the shell's `lift` takes it:
; a path written to /proc/lift, and the seat outside does the rest. the node runner lays
; the file beside itself under the path's last name, and the rule reads it back.
(: f "/tmp/lifted.txt"
   msg "carried out of the machine, whole\n"
   p (open f "w")
   _ (say p msg, close p)
   q (open "/proc/lift" "w")
   (? !(hot? q) (puts "lift: no /proc/lift\n")
      (: _ (say q f, close q)
         _ (rest 800)                      ; the worker lifts at its next idle
         (puts "lift asked\n"))))
