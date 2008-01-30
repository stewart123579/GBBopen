;;;; -*- Mode:Common-Lisp; Package:GBBOPEN; Syntax:common-lisp -*-
;;;; *-* File: /home/gbbopen/source/gbbopen/epilogue.lisp *-*
;;;; *-* Edited-By: cork *-*
;;;; *-* Last-Edit: Wed Jan 30 11:11:12 2008 *-*
;;;; *-* Machine: whirlwind.corkills.org *-*

;;;; **************************************************************************
;;;; **************************************************************************
;;;; *
;;;; *                GBBopen Miscellaneous Entities & Epilogue
;;;; *
;;;; **************************************************************************
;;;; **************************************************************************
;;;
;;; Written by: Dan Corkill
;;;
;;; Copyright (C) 2004-2008, Dan Corkill <corkill@GBBopen.org>
;;; Part of the GBBopen Project (see LICENSE for license information).
;;;
;;; * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;;;
;;;  01-16-04 File Created.  (Corkill)
;;;  05-03-04 Added reset-gbbopen.  (Corkill)
;;;  11-07-07 Retain the root-space-instance when resetting GBBopen.  (Corkill)
;;;  01-28-08 Added load-blackboard-repository and save-blackboard-repository.
;;;           (Corkill)
;;;
;;; * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

(in-package :gbbopen)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (export '(load-blackboard-repository
            save-blackboard-repository
            reset-gbbopen)))

;;; ===========================================================================
;;;  Miscellaneous Entities

(defun reset-gbbopen (&key (disable-events t)
			   (retain-classes nil)
			   (retain-event-printing nil)
			   (retain-event-functions nil)
			   ;; Not documented:
			   (retain-space-instance-event-functions nil))
  ;;; Deletes all unit and space instances; resets instance counters to 1.
  (let ((*%%events-enabled%%* (not disable-events)))
    (map-extended-unit-classes 
     #'(lambda (unit-class plus-subclasses)
	 (declare (ignore plus-subclasses))
	 (unless (or 
                  ;; Retain the root-space-instance
                  (eq (class-name unit-class) 'root-space-instance)
                  (and retain-classes
                       (unit-class-in-specifier-p unit-class retain-classes)))
	   ;; We must practice safe delete-instance:
	   (let ((instances nil))
	     (map-instances-given-class 
	      #'(lambda (instance) (push instance instances)) unit-class)
	     (mapc #'delete-instance instances)
	     (reset-unit-class unit-class))))
     't)
    (unless retain-event-printing (disable-event-printing))
    ;; Keep around the path-event-functions specifications for new
    ;; space-instances if either :retain-event-functions (or the more
    ;; specific :retain-space-instance-event-functions) is specified:
    (unless (or retain-event-functions
		retain-space-instance-event-functions)
      (map-event-classes 
       #'(lambda (event-class plus-subclasses)
	   (declare (ignore plus-subclasses))
	   (setf (space-instance-event-class.path-event-functions event-class)
		 nil))
       (find-class 'space-instance-event)))
    ;; Remove all event functions (path-event-functions specifications
    ;; for new space instances are removed above, if appropriate):
    (unless retain-event-functions
      (remove-all-event-functions))))

;;; ===========================================================================
;;;  Save & restore repository

(defun make-bb-pathname (pathname) 
  ;; Adds type "bb", if not supplied ; then adds defaults from
  ;; *default-pathname-defaults*, as needed:
  (merge-pathnames 
   pathname
   (make-pathname :type "bb"
                  :defaults *default-pathname-defaults*)))

;;; ---------------------------------------------------------------------------

(defun save-blackboard-repository (pathname &key (package ':cl-user)
                                                 (read-default-float-format 
                                                  'single-float))
  (with-open-file (file (make-bb-pathname pathname)
                   :direction ':output
                   :if-exists ':supersede)
    (format file ";;;  GBBopen Blackboard Repository (saved ~a)~%"
            (internet-text-date-and-time))
    (with-saving/sending-block (file :package package
                                     :read-default-float-format 
                                     read-default-float-format)
      (let ((root-space-instance-children (children-of *root-space-instance*)))
        (format file "~&;;;  Space instances:~%")
        (let ((*save/send-references-only* 't))
          (print-object-for-saving/sending root-space-instance-children file))
        (let ((*save/send-references-only* nil))
          (dolist (child root-space-instance-children)
            (traverse-space-instance-tree 
             #'(lambda (space-instance)
                 (print-object-for-saving/sending space-instance file))
             child))
          (format file "~&;;;  Other unit instances:~%")
          (do-instances-of-class (instance t)
            ;; Skip  space instances:
            (unless (typep instance 'root-space-instance)
              (print-object-for-saving/sending instance file))))))
    (format file "~&;;;  End of File~%")
    (pathname file)))

;;; ---------------------------------------------------------------------------

(defun empty-blackboard-repository-p ()
  ;; Returns t if there are no unit instances (other than the
  ;; root-space-instance) in the blackboard repository
  (map-unit-classes
   #'(lambda (class)
       (unless (eq (class-name class) 'root-space-instance)
         (when (plusp& (class-instances-count class))
           (return-from empty-blackboard-repository-p nil))))
   (find-class 'standard-unit-instance))
  ;; The repository is empty:
  't)

;;; ---------------------------------------------------------------------------

(defun load-blackboard-repository (pathname &rest reset-gbbopen-args
                                                  &key (confirm-if-not-empty 't))
  (declare (dynamic-extent reset-gbbopen-args))
  (when (and confirm-if-not-empty
             (not (empty-blackboard-repository-p)))
    (unless (yes-or-no-p "The blackboard repository is not empty.~
                          ~%Continue anyway ~
                          (the current contents will be deleted)? ")
      (return-from load-blackboard-repository nil)))
  (with-open-file (file  (make-bb-pathname pathname)
                   :direction ':input)
    (apply 'reset-gbbopen 
           (remove-property reset-gbbopen-args ':confirm-if-not-empty))
    (with-reading-object-block (file)
      (let ((root-children (read file))
            (*%%allow-setf-on-link%%* 't))
        (setf (slot-value *root-space-instance* 'children) root-children))
      ;; Now read everything else:
      (let ((eof-marker '#:eof))
        (until (eq eof-marker (read file nil eof-marker)))))
    (pathname file)))
  
;;; ===========================================================================
;;;  GBBopen is fully loaded

(pushnew :gbbopen *features*)
(pushnew *gbbopen-version-keyword* *features*)

;;; ===========================================================================
;;;				  End of File
;;; ===========================================================================


