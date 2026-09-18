;;; common lisp benchmark harness -- mirrors bench/bench.l.
;;; (bench name work) auto-scales the repetition count (doubling until the run
;;; clears +min-ms+), then times that count ONCE MORE and reports the second run --
;;; the scaling runs pay the fixed per-process costs (JIT warm-up, the heap's first
;;; growth), which otherwise ride on whichever power of two the doubling landed on.
;;; one line per bench, matching the other harnesses:
;;;     <name> <lang> <reps> <ms> <checksum>
;;; work is a nullary function returning a deterministic checksum. the same file
;;; serves every ANSI CL on the box (sbcl, clisp, ecl); BENCH_LANG sets the
;;; label so the columns stay distinct, default "sbcl".
#+sbcl (declaim (sb-ext:muffle-conditions style-warning))
(defparameter +min-ms+ 200.0)
(defparameter +lang+
  (or (or #+sbcl  (sb-ext:posix-getenv "BENCH_LANG")
          #+clisp (ext:getenv "BENCH_LANG")
          #+ecl   (ext:getenv "BENCH_LANG")
          nil)
      "sbcl"))

(defun bench-run (work reps)            ; -> (values ms chk)
  (let* ((t0 (get-internal-real-time))
         (chk (let ((c nil)) (dotimes (i reps) (setf c (funcall work))) c)))
    (values (* 1000.0 (/ (- (get-internal-real-time) t0)
                         internal-time-units-per-second))
            chk)))

(defun bench (name work)
  (loop with reps = 1 do
    (multiple-value-bind (ms chk) (bench-run work reps)
      (declare (ignore chk))
      (when (>= ms +min-ms+)
        (multiple-value-bind (ms chk) (bench-run work reps)   ; warm
          (format t "~a ~a ~d ~,3f ~a~%" name +lang+ reps ms chk)
          (finish-output))
        (return))
      (setf reps (* 2 reps)))))
