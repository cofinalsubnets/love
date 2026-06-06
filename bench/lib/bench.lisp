;;; sbcl (common lisp) benchmark harness -- mirrors bench/bench.g.
;;; (bench name work) auto-scales the repetition count (doubling until the run
;;; clears +min-ms+), then prints one line matching the other harnesses:
;;;     <name> sbcl <reps> <ms> <checksum>
;;; work is a nullary function returning a deterministic checksum.
(declaim (sb-ext:muffle-conditions style-warning))
(defparameter +min-ms+ 200.0)

(defun bench (name work)
  (loop with reps = 1 do
    (let* ((t0 (get-internal-real-time))
           (chk (let ((c nil)) (dotimes (i reps) (setf c (funcall work))) c))
           (ms (* 1000.0 (/ (- (get-internal-real-time) t0)
                            internal-time-units-per-second))))
      (when (>= ms +min-ms+)
        (format t "~a sbcl ~d ~,3f ~a~%" name reps ms chk)
        (finish-output)
        (return))
      (setf reps (* 2 reps)))))
