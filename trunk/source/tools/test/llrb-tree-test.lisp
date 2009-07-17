;;;; -*- Mode:Common-Lisp; Package:GBBOPEN-TOOLS; Syntax:common-lisp -*-
;;;; *-* File: /usr/local/gbbopen/source/tools/test/llrb-tree-test.lisp *-*
;;;; *-* Edited-By: cork *-*
;;;; *-* Last-Edit: Fri Jul 17 13:34:35 2009 *-*
;;;; *-* Machine: cyclone.cs.umass.edu *-*

;;;; **************************************************************************
;;;; **************************************************************************
;;;; *
;;;; *                              LLRB Tree Tests
;;;; *
;;;; **************************************************************************
;;;; **************************************************************************

(in-package :gbbopen-tools)

;;; ---------------------------------------------------------------------------

(defun llrb-check-traversal (llrb-tree)
  (let ((last-key -infinity&))
    (map-llrb-tree
     #'(lambda (key value)
         (declare (ignore value))
         (unless (>& key last-key)
           (error "Wrong key ordering"))
         (setf last-key key))
     llrb-tree)))

;;; ---------------------------------------------------------------------------

(defun llrb-print-tree (node &optional (indent 0))
  (when node
    (let ((left (rbt-node-right node))
	  (right (rbt-node-left node)))
      (when left
	(llrb-print-tree left (1+& indent)))
      (loop for i from 1 to indent
          do (format t "  "))
      (format t "~a ~:[B~;R~]~%" (rbt-node-key node) (rbt-node-is-red? node))
      (when right
	(llrb-print-tree right (1+& indent))))))

;;; ---------------------------------------------------------------------------

(defun llrb-print (llrb-tree)
  (let ((root (llrb-tree-root llrb-tree)))
    (if root
        (llrb-prefix-map #'(lambda (node) (format t "~&~s~%" node)) root)
        (format t "#<empty>~%")))
  (values))

;;; ---------------------------------------------------------------------------

(defun llrb-tree-count-nodes (llrb-tree)
  (let ((count 0))
    (flet ((count-it (key value)
             (declare (ignore key value))
             (incf& count)))
      (map-llrb-tree #'count-it llrb-tree))
    count))

;;; ===========================================================================
;;;   Timing

(defun random-size-llrb-tree-test (n)
  ;; Build the test-data hash table:
  (let ((numbers (make-hash-table :size n))
        tree
        ht
        continuep 
        key)
    (declare (ignorable continuep))     ; for CL's that optimize this var away!
    (dotimes (i n)
      (let ((key (random n)))
        (setf (gethash key numbers) key)))
    (format t "~&;; Numbers: ~a~%" (hash-table-count numbers))
    ;; Build the LLRH tree:
    (printv "Building LLRH tree:")
    (time
     (with-hash-table-iterator (next numbers)
       (setf tree (make-llrb-tree #'compare&))
       (while (multiple-value-setq (continuep key) (next))
         (llrb-tree-insert key tree key))))
    (unless (= (hash-table-count numbers)
               (llrb-tree-count-nodes tree))
      (error "Wrong node count"))
    (llrb-check-traversal tree)
    ;; Now build the hash table:
    (printv "Building hash table:")
    (time
     (with-hash-table-iterator (next numbers)
       (setf ht (make-hash-table :size (hash-table-count numbers)))
       (while (multiple-value-setq (continuep key) (next))
         (setf (gethash key ht) key))))
    ;; LLRH retrievals:
    (printv "LLRB retrievals:")
    (time
     (with-hash-table-iterator (next numbers)
       (while (multiple-value-setq (continuep key) (next))
         (unless (get-llrb-tree-node key tree)
           (error "Did not retrieve ~s" key)))))
    ;; Hash-table retrievals:
    (printv "Hash-table retrievals:")
    (time
     (with-hash-table-iterator (next numbers)
       (while (multiple-value-setq (continuep key) (next))
         (gethash key ht))))
    ;; Now delete about 1/2 of the numbers in the test data:
    (with-hash-table-iterator (next numbers)
       (while (multiple-value-setq (continuep key) (next))
         (when (plusp& (random 2)) (remhash key numbers))))
    (let ((remaining-numbers (-& (hash-table-count ht)
                                 (hash-table-count numbers))))
      (format t "~&;; Remaining numbers: ~a~%" remaining-numbers)
      ;; LLRH deletes:
      (printv "LLRB deletes:")
      (time
       (let ((delete-counter (hash-table-count ht)))
         (with-hash-table-iterator (next numbers)
           (while (multiple-value-setq (continuep key) (next))
             (printv "===>" key)
             (llrb-tree-delete key tree)
             #-debugging
             (let ((count (llrb-tree-count tree))
                   (node-count (llrb-tree-count-nodes tree)))
               (decf& delete-counter)
               (printv delete-counter)
               (unless (=& count node-count)
                 (llrb-print tree)
                 (error "Count mismatch during deletes: ~s ~s ~s"
                        count node-count remaining-numbers)))))))
      ;; Hash-table deletes:
      (printv "Hash-table deletes:")
      (time
       (with-hash-table-iterator (next numbers)
         (while (multiple-value-setq (continuep key) (next))
           (remhash key ht))))
      (let ((count (llrb-tree-count-nodes tree)))
        (unless (= (hash-table-count ht) count)
          (error "Wrong count after deletes: ~s" count))))))

;;; ===========================================================================
;;;  Basic LLRB-tree trip test

(defun basic-llrb-tree-test (&optional verbose)
  (format t "~&;; Starting basic LLRB-tree tests...~%")
  (let (llrb-tree)
    (macrolet
        ((logger ((s &body setup) &body body)
           `(progn (format t "~&;; ~40,,,'-<-~>~%;; ~a~%" ,s)
                   ,@setup
                   (when verbose (llrb-print llrb-tree))
                   ,@body
                   (when verbose (llrb-print llrb-tree)))))
      (flet
          ((nil-result-error ()
             (error "Result was nil"))
           (non-nil-result-error ()
             (error "Result was not nil")))
        (logger ("Delete missing from empty tree:"
                 (setf llrb-tree (make-llrb-tree #'compare&)))
                (when (llrb-tree-delete 5 llrb-tree)
                  (non-nil-result-error)))
        (when verbose (llrb-print-tree llrb-tree))
        (logger ("Delete root:"
                 (setf llrb-tree (make-llrb-tree #'compare&))
                 (llrb-tree-insert 5 llrb-tree 5))
                (unless (llrb-tree-delete 5 llrb-tree)
                  (nil-result-error)))
        (when verbose (llrb-print-tree llrb-tree))
        (logger ("Delete missing (left) from singleton tree:"
                 (setf llrb-tree (make-llrb-tree #'compare&))
                 (llrb-tree-insert 5 llrb-tree 5))
                (when (llrb-tree-delete 1 llrb-tree)
                  (non-nil-result-error)))
        (when verbose (llrb-print-tree llrb-tree))
        (logger ("Delete missing (right) from singleton tree:"
                 (setf llrb-tree (make-llrb-tree #'compare&))
                 (llrb-tree-insert 5 llrb-tree 5))
                (when (llrb-tree-delete 9 llrb-tree)
                  (non-nil-result-error)))
        (when verbose (llrb-print-tree llrb-tree))
        (logger ("Delete 1 from 5-1 tree:"
                 (setf llrb-tree (make-llrb-tree #'compare&))
                 (llrb-tree-insert 5 llrb-tree 5)
                 (llrb-tree-insert 1 llrb-tree 1))
                (unless (llrb-tree-delete 1 llrb-tree)
                  (nil-result-error)))
        (when verbose (llrb-print-tree llrb-tree))
        (logger ("Delete 9 from 1-5-9 tree:"
                 (setf llrb-tree (make-llrb-tree #'compare&))
                 (llrb-tree-insert 5 llrb-tree 5)
                 (llrb-tree-insert 1 llrb-tree 1)
                 (llrb-tree-insert 9 llrb-tree 1))
                (unless (llrb-tree-delete 9 llrb-tree)
                  (nil-result-error)))
        (when verbose (llrb-print-tree llrb-tree))
        (logger ("Make 1:8 tree:"
                 (setf llrb-tree (make-llrb-tree #'compare&))
                 (loop for i from 1 to 8 do
                       (llrb-tree-insert i llrb-tree i))))
        (when verbose (llrb-print-tree llrb-tree))
        (logger ("Delete 5 from 5-1 tree:"
                 (setf llrb-tree (make-llrb-tree #'compare&))
                 (llrb-tree-insert 5 llrb-tree 5)
                 (llrb-tree-insert 1 llrb-tree nil))
                (unless (llrb-tree-delete 5 llrb-tree)
                  (nil-result-error)))
        (when verbose (llrb-print-tree llrb-tree)))))
    (format t "~&;; Completed basic LLRB-tree tests.~%"))
  
;;; ---------------------------------------------------------------------------

(when *autorun-modules*
  (basic-llrb-tree-test))
  
;;; ===========================================================================
;;;				  End of File
;;; ===========================================================================

