; test/gate/spin.l -- a task that ends while no peer can run. `twirl` spawns it, the parent
; parks on a timer, and the child reaches its last form with nobody runnable to hand the
; cpu to. the exit is a yield whose Ip does not advance, so a scheduler that treats it as a
; fairness yield lands back on the same op and the process spins at a whole core for as
; long as the parent sleeps -- which is forever, for a server. the gate beside this weighs
; the cpu it spends; the program itself only has to sit still.
(: _ (twirl (\ _ 0) ())
   _ (rest 4000)
   (puts "spin: the parent woke\n"))
