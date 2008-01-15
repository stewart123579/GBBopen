;;;; -*- Mode:Common-Lisp; Package:GBBOPEN-USER; Syntax:common-lisp -*-
;;;; *-* File: /home/gbbopen/current/source/gbbopen/control-shells/examples/abort-ks-execution.lisp *-*
;;;; *-* Edited-By: cork *-*
;;;; *-* Last-Edit: Sat Jul 28 12:21:27 2007 *-*
;;;; *-* Machine: ruby.corkills.org *-*

;;;; **************************************************************************
;;;; **************************************************************************
;;;; *
;;;; *                       Abort KS Execution Example
;;;; *
;;;; **************************************************************************
;;;; **************************************************************************
;;;
;;; Written by: Dan Corkill
;;;
;;; Copyright (C) 2006-2007, Dan Corkill <corkill@GBBopen.org>
;;; Part of the GBBopen Project (see LICENSE for license information).
;;;
;;; * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;;;
;;;  11-13-06 File Created.  (Corkill)
;;;
;;; * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

(in-package :gbbopen-user)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (use-package '(:portable-threads :agenda-shell)))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (import '(common-lisp-user::*autorun-modules*)))

;;; ---------------------------------------------------------------------------

(define-ks ks-to-abort 
    :trigger-events ((start-control-shell-event)) 
    :execution-function 'ks-to-abort-execution-function)

(defun ks-to-abort-execution-function (ksa)
  (declare (ignore ksa))
  (format t "~&;; KS ~s is going to sleep...~%"
          'ks-to-abort)
  (polling-sleep 5)
  (warn "KS ~s was not aborted." 'ks-to-abort))

;;; ---------------------------------------------------------------------------

(defun initializations (event-name &key &allow-other-keys)
  (declare (ignore event-name))
  ;; Clean up any previous run:
  (reset-gbbopen :retain-classes '((ks :plus-subclasses))
                 :retain-event-functions 't
                 :retain-event-printing 't)
  (let ((sleep-time 2))
    ;; Got threads? Spawn a thread to abort ths KS execution:
    #-threads-not-available
    (spawn-thread "KS aborter" 
                   #'(lambda (sleep-time)
                       (format t "~&;; Spawned aborting thread, sleeping ~
                                   for ~s second~:p...~%"
                               sleep-time)                       
                       (sleep sleep-time)
                       (format t "~&;; Aborting KS execution...~%")
                       (abort-ks-execution))
                   sleep-time)
    ;; No threads? Set the abort-time and add a polling-function to abort the
    ;; KS execution:
    #+threads-not-available
    (let ((abort-time (+ (get-universal-time) sleep-time)))
      (labels ((abort-ks-polling-function ()
                 (when (>= (get-universal-time) abort-time)
                   (remove-polling-function #'abort-ks-polling-function)
                   (format t "~&;; Aborting KS execution...~%")
                   (abort-ks-execution))))
        (add-polling-function #'abort-ks-polling-function)))))

(add-event-function 'initializations 'start-control-shell-event
                    ;; Initializations should be done first!
                    :priority 100)

;;; ---------------------------------------------------------------------------

(when *autorun-modules*
  (format t "~{~&~s~%~}"
	  (multiple-value-list (start-control-shell))))

;;; ===========================================================================
;;;				  End of File
;;; ===========================================================================
