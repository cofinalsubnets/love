; test/kernel/pane.l -- a mitty pane on the kernel, as the harbour opens one: hopen tethers a
; child on a pty of its own at the pane's size, moor scribes what the master reads onto the
; pane's grid until the child is gone, and hscreen-text reads the grid back. the crew's mitty,
; the one `inle` boots: on a woken image its doors were bound on the host. kernel corpus only.
(borrow 'mitty)

; a pane's rows once its child has ended; a watchdog stills the child's group should it hang,
; so a wedged pane fails its law and the corpus goes on
(: (kp-run p) (: pid (p 2) w (twirl (_ \ (rest 20000, still -pid 9)) 0)
                 (moor (hbox p) (hmas p) (), wait pid, freeze w, hscreen-text p @ r (close (hmas p), r))))

; a child's output lands on its pane's grid, its \n as \r\n
(hopen ["kore" "echo" "hi there"] 4 20 @ p
 (: rows (kp-run p)
  (test (two? p) ("hi there" = <rows) (4 = #rows))))

; a line typed into the pane: the discipline echoes it, cat writes it back, ^D ends cat
(hopen ["kore" "cat"] 4 20 @ p
 (: m (hmas p)
    _ (say m "abc\r", put m 4, flush m)
    rows (kp-run p)
  (test ("abc" = <rows) ("abc" = rows 1))))

; lush in a pane, as the harbour's first pane: a command's answer reaches the grid. the lines
; are typed before lush takes the terminal, so the answer ends a row of its own or its prompt's
(hopen ["lush"] 8 40 @ p
 (: m (hmas p)
    _ (say m "echo $((6 * 7))\r", say m "exit\r", flush m)
    rows (kp-run p)
  (test (any (r \ r = "42" || 3 < #r && "$ 42" = snip r (#r - 4) #r) rows))))
