;;;; -*- Mode:Common-Lisp; Package:GBBOPEN-TOOLS; Syntax:common-lisp -*-
;;;; *-* File: /home/gbbopen/source/tools/print-object-for.lisp *-*
;;;; *-* Edited-By: cork *-*
;;;; *-* Last-Edit: Tue Jan 22 03:56:40 2008 *-*
;;;; *-* Machine: whirlwind.corkills.org *-*

;;;; **************************************************************************
;;;; **************************************************************************
;;;; *
;;;; *             Print Object For Saving & For Sending Support
;;;; *
;;;; **************************************************************************
;;;; **************************************************************************
;;;
;;; Written by: Dan Corkill
;;;
;;; Copyright (C) 2007-2008, Dan Corkill <corkill@GBBopen.org>
;;; Part of the GBBopen Project (see LICENSE for license information).
;;;
;;; * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;;;
;;;  07-18-07 File created.  (Corkill)
;;;
;;; * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

(in-package :gbbopen-tools)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (import '(clos:class-slots
            clos:slot-definition-name)))
  
(eval-when (:compile-toplevel :load-toplevel :execute)
  (export '(*print-object-for-sending*  ; not yet documented
            print-object-for-saving     ; not yet documented
            print-object-for-saving/sending ; not yet documented
            print-object-for-sending    ; not yet documented
            print-slot-for-saving/sending ; not yet documented
            slots-for-saving/sending    ; not yet documented
            with-saving/sending-block))) ; not yet documented

;;; ===========================================================================
;;;  With-sending/saving-block

(defvar *recorded-class-descriptions-ht*)

(defmacro with-saving/sending-block ((&key) &body body)
  `(let ((*recorded-class-descriptions-ht*
          #+allegro
          (make-hash-table :test 'eq :values nil)
          #-allegro
          (make-hash-table :test 'eq)))
     ,@body))

;;; ===========================================================================
;;;  User level print-object-for-saving/sending functions

(defvar *print-object-for-sending* nil)

(defun print-object-for-saving (object stream)
  (let ((*print-object-for-sending* nil))
    (print-object-for-saving/sending object stream)))

(defun print-object-for-sending (object stream)
  (let ((*print-object-for-sending* 't))
    (print-object-for-saving/sending object stream)))

;;; ===========================================================================
;;;  Slots-for-saving/sending methods

(defgeneric slots-for-saving/sending (class))

;;; ---------------------------------------------------------------------------
;;;  Default

(defmethod slots-for-saving/sending ((class standard-class))
  (class-slots class))

;;; ===========================================================================
;;;  Standard print-object-for-saving/sending methods

(defgeneric print-object-for-saving/sending (object stream))

;;; ---------------------------------------------------------------------------
;;;  Default

(defmethod print-object-for-saving/sending (object stream)
  (prin1 object stream))

;;; ---------------------------------------------------------------------------
;;;  Lists

(defmethod print-object-for-saving/sending ((cons cons) stream)
  (cond
   ;; Compact (quote object) printing:
   ((and (eq (first cons) 'quote)
         (null (cddr cons))
         (not (null (cdr cons))))
    (princ "'" stream)
    (print-object-for-saving/sending (second cons) stream))
   ;; Regular list printing:
   (t (let ((ptr cons))
        (princ "(" stream)
        (print-object-for-saving/sending (car ptr) stream)
        (loop
          (when (atom (setf ptr (cdr ptr))) (return))
          (princ " " stream)
          (print-object-for-saving/sending (car ptr) stream))
        (unless (null ptr)
          (princ " . " stream)
          (print-object-for-saving/sending ptr stream))
        (princ ")" stream))))
  cons)

;;; ---------------------------------------------------------------------------
;;;  Strings

(defmethod print-object-for-saving/sending ((string string) stream)
  (prin1 string stream))

;;; ---------------------------------------------------------------------------
;;;  Vectors

(defmethod print-object-for-saving/sending ((vector vector) stream)
  (format stream "#(")
  (dotimes (i (length vector))
    (declare (fixnum i))
    (unless (zerop i) (princ " " stream))
    (print-object-for-saving/sending (aref vector i) stream))
  (princ ")" stream)
  vector)

;;; ---------------------------------------------------------------------------
;;;  Bit-vectors

(defmethod print-object-for-saving/sending ((bit-vector bit-vector) stream)
  (prin1 bit-vector stream))

;;; ---------------------------------------------------------------------------
;;;  Arrays (simple only--someday support extended syntax for arrays with
;;;          a fill-pointer, specialized element-type, etc.)

(defmethod print-object-for-saving/sending ((array array) stream)
  (let ((dimensions (array-dimensions array))
        (index -1))
    (declare (fixnum index))
    (labels
        ((helper (dimensions)
           (cond 
            ((null dimensions)
             (print-object-for-saving/sending
              (row-major-aref array (the fixnum (incf index))) stream))
            (t (let ((dimension (first dimensions)))
                 (princ "(" stream)
                 (dotimes (i dimension)
                   (declare (fixnum i))
                   (unless (zerop i) (princ " " stream))
                   (helper (rest dimensions)))
                 (princ ")" stream))))))
      (format stream "#~sA" (array-rank array))
      (helper dimensions)
      (princ " " stream)))
  array)

;;; ---------------------------------------------------------------------------
;;;  Structures

(defmethod print-object-for-saving/sending ((structure structure-object) 
                                            stream)
  (let ((class (class-of structure)))
    (format stream "#S(~s" (class-name class))
    (dolist (slot (slots-for-saving/sending class))
      (let ((slot-name (slot-definition-name slot)))
        (format stream " :~a " slot-name)
        (print-object-for-saving/sending
         (slot-value structure slot-name) stream)))
    (princ ")" stream))
  structure)

;;; ---------------------------------------------------------------------------
;;;  Class Descriptions

(defmethod print-object-for-saving/sending ((class standard-class) stream)
  (format stream "#GC(~s" (class-name class))
  (dolist (slot (slots-for-saving/sending class))
    (let ((slot-name (slot-definition-name slot)))
      (format stream " ~s" slot-name)))
  (princ ")" stream)
  (terpri stream)
  class)

;;; ---------------------------------------------------------------------------
;;;  Instances

(defgeneric print-slot-for-saving/sending (instance slot-name stream))

;;; ---------------------------------------------------------------------------

(defmethod print-slot-for-saving/sending ((instance standard-object)
                                          slot-name
                                          stream)
  (print-object-for-saving/sending (slot-value instance slot-name) stream))

;;; ---------------------------------------------------------------------------

(defmethod print-object-for-saving/sending ((instance standard-object) stream)
  (let* ((class (class-of instance))
         (class-name (class-name class)))
    ;; Save the class description, if we've not done so in
    ;; this block:
    (unless (gethash class-name *recorded-class-descriptions-ht*)
      (print-object-for-saving/sending class stream)
      (setf (gethash class-name *recorded-class-descriptions-ht*) 't))
    (format stream "#GI(~s" (class-name class))
    (dolist (slot (slots-for-saving/sending class))
      (princ " " stream)
      (if (slot-boundp-using-class class instance slot)
          (print-slot-for-saving/sending 
           instance (slot-definition-name slot) stream)
          ;; Unbound value indicator:
          (format stream "#GU")))
    (princ ")" stream))
  instance)

;;; ---------------------------------------------------------------------------
;;;  Hash Tables

(defmethod print-object-for-saving/sending ((hash-table hash-table) stream)
  (let ((keys-and-values-hash-table? 
         #+allegro (excl:hash-table-values hash-table)
         #-allegro 't))
    (format stream "#GH(~s ~s ~s"
            (hash-table-test hash-table)
            (hash-table-count hash-table)
            keys-and-values-hash-table?)
    (maphash 
     (if keys-and-values-hash-table? 
         #'(lambda (key value)
             (format stream " ")
             (print-object-for-saving/sending key stream)
             (format stream " ")
             (print-object-for-saving/sending value stream))
         #'(lambda (key value)
             (declare (ignore value))
             (format stream " ")
             (print-object-for-saving/sending key stream)))
     hash-table)
    (princ ")" stream)
    hash-table))

;;; ===========================================================================
;;;				  End of File
;;; ===========================================================================