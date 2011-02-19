;;;; -*- Mode:Common-Lisp; Package:CL-USER; Syntax:common-lisp -*-
;;;; *-* File: /usr/local/gbbopen/source/gbbopen/test/network-streaming-slave.lisp *-*
;;;; *-* Edited-By: cork *-*
;;;; *-* Last-Edit: Fri Feb 18 11:35:48 2011 *-*
;;;; *-* Machine: twister.local *-*

;;;; **************************************************************************
;;;; **************************************************************************
;;;; *
;;;; *                    GBBopen Network Streaming Slave 
;;;; *                  (start this slave before the master!)
;;;; *
;;;; *                   [Experimental! Subject to change]
;;;; *
;;;; **************************************************************************
;;;; **************************************************************************
;;;
;;; Written by: Dan Corkill
;;;
;;; Copyright (C) 2011, Dan Corkill <corkill@GBBopen.org>
;;; Part of the GBBopen Project.
;;; Licensed under Apache License 2.0 (see LICENSE for license information).
;;;
;;; * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;;;
;;;  02-01-11 File created.  (Corkill)
;;;
;;; * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

(in-package :cl-user)

;; Compile/load GBBopen's :streaming module:
(streaming :create-dirs)

;; Compile/load the :tutorial module (without running it):
(cl-user::tutorial-example :create-dirs :noautorun)

;; The slave host (me!):
(define-streamer-node "slave"
    :localnodep 't
    :host "127.0.0.1"
    :package ':tutorial)

;; The master host:
(define-streamer-node "master"
    :host "127.0.0.1"
    :port (1+ (port-of (find-streamer-node "slave")))
    :package ':tutorial)

;; Help 
#+IF-DEBUGGING
(setf gbbopen:*break-on-receive-errors* 't)

;; Silly queued-reception methods:
(defmethod beginning-queued-read ((tag (eql ':tutorial)))
  (format t "~&;; Beginning ~s queued receive...~%" tag))
(defmethod ending-queued-read ((tag (eql ':tutorial)))
  (format t "~&;; Ending ~s queued receive.~%" tag))
(defmethod beginning-queued-read ((tag t))
  (format t "~&;; Beginning ~a receive...~%" tag))
(defmethod ending-queued-read ((tag t))
  (format t "~&;; Ending ~a receive.~%" tag))

;; Silly command form method:
(defmethod handle-streamed-command-form ((command (eql ':print)) &rest args)
  (format t "~&;; Print:~{ ~s~}~%" args))

;; Silly connection-exiting method:
(defmethod handle-stream-connection-exiting ((connection stream) exit-status)
  (format t "~&;; Connection ~s closing~@[: (~s)~]~%"
          connection exit-status))

;; Show what is happening once streaming begins!
(enable-event-printing 'create-instance-event 'location)
(enable-event-printing 'delete-instance-event 'location)
(add-event-function
 ;; Enable update-nonlink-slot-event printing only after the delete-instance
 ;; has been received:
 #'(lambda (&rest args)
     (declare (ignore args))
     (enable-event-printing 'update-nonlink-slot-event 'location :slot-name 'time)
     (enable-event-printing '(link-slot-event +) 'location :slot-name 'previous-location)
     (enable-event-printing '(link-slot-event +) 'location :slot-name 'next-location))
 'delete-instance-event 'location)

;; Don't warn that the Agenda Shell isn't running to process trigger events on
;; received goodies:
(setf *warn-about-unusual-requests* nil)

;; Prepare to receive from the master:
(defparameter *network-stream-server* (start-network-stream-server))

;;; ===========================================================================
;;;				  End of File
;;; ===========================================================================

