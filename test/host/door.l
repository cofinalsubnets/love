; --- test/host/door.l: the console door, both bodies ---
; (door f) runs a tty app on this console and answers its charm. a terminal forks,
; inle and the page run a task -- and this is a terminal, so `door` takes the fork lane
; here; the task lane is called by name. not in the test/*.l corpus: it forks.
; run:  cat test/00-init.l test/host/door.l | out/love
(: _ (use 'console)
   D (from 'console)
   door (D 'door) door-task (D 'door-task) door-fork (D 'door-fork)
   ; the task lane: the app a task on this console, the caller parked until it lands
   _ (assert (7 = door-task (\ _ 7))
             (0 = door-task (\ _ "no charm"))
             ; ..and a door inside a door: the caller task parks in turn
             (9 = door-task (\ _ (door-task (\ _ 9)))))
   ; the fork lane: a child owns the tty, its charm is the parent's answer, and the
   ; parent's own state is untouched by whatever the child did
   box {}
   _ (pin box 'n 1)
   _ (assert (5 = door-fork (\ _ (: _ (pin box 'n 2) 5)))
             (1 = peep box 'n 0)
             (3 = door (\ _ 3))
             (0 = door (\ _ 'no-charm)))
   ; a scare in the child ends the child at 1, never the caller
   _ (assert (1 = door (\ _ (scare 'boom 1))))
   _ (test_fin ())
   _ (puts "door: ok -- the console door, forked here and as a task\n")
   0)
