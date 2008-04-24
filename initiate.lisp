;;;; -*- Mode:Common-Lisp; Package:Common-Lisp-User; Syntax:common-lisp -*-
;;;; *-* File: /usr/local/gbbopen/initiate.lisp *-*
;;;; *-* Edited-By: cork *-*
;;;; *-* Last-Edit: Wed Apr 23 19:21:45 2008 *-*
;;;; *-* Machine: cyclone.cs.umass.edu *-*

;;;; **************************************************************************
;;;; **************************************************************************
;;;; *
;;;; *                 Useful (Standard) GBBopen Initiations
;;;; *
;;;; **************************************************************************
;;;; **************************************************************************
;;;
;;; Written by: Dan Corkill
;;;
;;; Copyright (C) 2002-2008, Dan Corkill <corkill@GBBopen.org>
;;; Part of the GBBopen Project (see LICENSE for license information).
;;;
;;; Useful generic GBBopen initialization definitions.  Load this file from
;;; your personal CL initialization file (in place of startup.lisp).  After
;;; loading, handy top-level-loop keyword commands, such as :gbbopen-tools,
;;; :gbbopen, :gbbopen-user, and :gbbopen-test, are available on Allegro CL,
;;; CLISP, Clozure CL, CMUCL, SCL, ECL, Lispworks, OpenMCL, and SBCL.  GBBopen
;;; keyword commands are also supported in the SLIME REPL.
;;;
;;; For example:
;;;
;;;    > :gbbopen-test :create-dirs
;;;
;;; will compile and load GBBopen and perform a basic trip test.
;;;
;;; Equivalent functions such as gbbopen-tools, gbbopen, gbbopen-user, and
;;; gbbopen-test are also defined in the common-lisp-user package.  These
;;; functions can be used in all CL implementations.  For example:
;;;
;;;    > (gbbopen-test :create-dirs)
;;;
;;; * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;;;
;;;  12-08-02 File Created (originally named gbbopen-init.lisp).  (Corkill)
;;;  03-21-04 Added :agenda-shell-test.  (Corkill)
;;;  05-04-04 Added :timing-test.  (Corkill)
;;;  06-10-04 Added :multiprocesing.  (Corkill)
;;;  06-04-05 Integrated gbbopen-clinit.cl and gbbopen-lispworks.lisp into
;;;           this file.  (Corkill)
;;;  12-10-05 Added loading of personal gbbopen-tll-commands.lisp file, if one
;;;           is present in (user-homedir-pathname).  (Corkill)
;;;  02-05-06 Always load extended-repl, now that SLIME command interface is
;;;           available.  (Corkill)
;;;  04-07-06 Added gbbopen-modules directory support.  (Corkill)
;;;  03-25-08 Renamed to more intuitive initiate.lisp.  (Corkill)
;;;  03-29-08 Add process-gbbopen-modules-directory rescanning.  (Corkill)
;;;
;;; * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

(in-package :common-lisp-user)

;;; ---------------------------------------------------------------------------
;;;  Used to control gbbopen-modules directory processing by startup.lisp:

(defvar *skip-gbbopen-modules-directory-processing* nil)

;;; ---------------------------------------------------------------------------
;;;  Used to indicate if GBBopen's startup.lisp file has been loaded:

(defvar *gbbopen-startup-loaded* nil)

;;; ---------------------------------------------------------------------------

(defun compile-if-advantageous (fn-name)
  ;;; Compile bootstrap-loaded function or macro on CLs where this is desirable
  #+ecl (declare (ignore fn-name))
  #-ecl (compile fn-name))

;;; ---------------------------------------------------------------------------
;;; Load top-level REPL extensions for CLISP, CMUCL, SCL, ECL, and SBCL and
;;; SLIME command extensions for all:

(eval-when (:compile-toplevel :load-toplevel :execute)
  (let ((truename *load-truename*))
    (load (make-pathname 
	   :name "extended-repl"
	   :type "lisp"
	   :defaults truename))))

;;; ---------------------------------------------------------------------------
;;;  GBBopen's startup.lisp loader
;;;    :force t -> load startup.lisp even if it was loaded before
;;;    :skip-gbbopen-modules-directory-processing -> controls whether 
;;;                 <homedir>/gbbopen-modules/ processing is performed

(let ((truename *load-truename*))
  (defun startup-gbbopen (&key                         
                          force
                          ((:skip-gbbopen-modules-directory-processing
                            *skip-gbbopen-modules-directory-processing*)
                           *skip-gbbopen-modules-directory-processing*))
    (cond 
     ;; Scan for changes if startup.lisp has been loaded:
     ((and (not force) *gbbopen-startup-loaded*)
      (unless *skip-gbbopen-modules-directory-processing*
        (funcall 'process-gbbopen-modules-directory "commands" 't)
        (funcall 'process-gbbopen-modules-directory "modules" 't)))
     ;; Load startup.lisp:
     (t (load (make-pathname 
               :name "startup"
               :type "lisp"
               :defaults truename))))))
  
;; Lispworks can't compile the interpreted closure:
#-lispworks
(compile-if-advantageous 'startup-gbbopen)

;;; ---------------------------------------------------------------------------

(defun set-package (package-specifier)
  (let ((swank-package (find-package ':swank)))
    (cond
     ;; If we are SLIME'ing:
     ((and swank-package 
           ;; Returns true if successful:
           (funcall (intern (symbol-name '#:set-slime-repl-package)
                            swank-package)
                    package-specifier))
      't)
     ;; Otherwise:
     (t (setf *package* (find-package package-specifier))
        ;; For LEP Emacs interface (Allegro & SCL):
        #+(or allegro scl)
        (when (lep:lep-is-running)
          (lep::eval-in-emacs (format nil "(setq fi:package ~s)"
                                      (package-name *package*))))))))

(compile-if-advantageous 'set-package)

;;; ---------------------------------------------------------------------------

(defun startup-module (module-name options &optional package)
  (startup-gbbopen)
  (funcall (intern (symbol-name '#:cm-tll-command) :mini-module)
           (list* module-name ':propagate options))
  (when package 
    (set-package package)
    (import '(common-lisp-user::gbbopen-tools 
              common-lisp-user::gbbopen
              common-lisp-user::gbbopen-user 
              common-lisp-user::gbbopen-test)
            *package*))
  (values))

(compile-if-advantageous 'startup-module)

;;; ===========================================================================
;;;   Define-TLL-command

(defun redefining-cl-user-tll-command-warning (command fn)
  ;; avoid SBCL optimization warning: 
  (declare (optimize (speed 1)))
  (let ((*package* (find-package ':common-lisp)))
    (format t "~&;; Redefining ~s function for TLL command ~s~%"
            fn command)))

(compile-if-advantageous 'redefining-cl-user-tll-command-warning)

;;; ---------------------------------------------------------------------------

(defmacro define-tll-command (command lambda-list &rest body)
  (let ((options nil))
    ;; Handle (<command> <option>*) syntax:
    (when (consp command)
      (setf options (rest command))
      (setf command (first command))
      (let ((bad-options 
             (set-difference options '(:add-to-native-help 
                                       :no-help
                                       :skip-cl-user-function))))
        (dolist (bad-option bad-options)
          (warn "Illegal command option ~s specified for tll-command ~s"
                bad-option command))))
    `(progn
       (define-extended-repl-command 
           ,(cond
             ((member ':no-help options)
              `(,command :no-help))
             ((member ':add-to-native-help options)
              `(,command :add-to-native-help))
             (t command))
           ,lambda-list
         ,@body)
       ;; Define command functions in the :CL-USER package on all CL
       ;; implementations:
       ,@(unless (member ':skip-cl-user-function options)
           (let ((fn-name (intern (symbol-name command) ':common-lisp-user)))
             `((when (fboundp ',fn-name)
                 (redefining-cl-user-tll-command-warning ',command ',fn-name))
               (defun ,fn-name ,lambda-list 
                 ,@body)))))))

(compile-if-advantageous 'define-tll-command)

;;; ===========================================================================
;;;  Load GBBopen's standard TLL commands

(let ((truename *load-truename*))
  (load (make-pathname 
	 :name "commands"
	 :type "lisp"
	 :defaults truename)))

;;; ---------------------------------------------------------------------------
;;;  If there is a gbbopen-commands.lisp file (or compiled version) in the
;;;  users "home" directory, load it now. 

(load (namestring (make-pathname :name "gbbopen-commands"
				 ;; CLISP and ECL don't handle :unspecific
				 :type #-(or clisp ecl) ':unspecific 
				       #+(or clisp ecl) nil
				 :version ':newest
				 :defaults (user-homedir-pathname)))
      :if-does-not-exist nil)

;;; ===========================================================================
;;;  Load gbbopen-modules-directory processing, if needed:

(let ((truename *load-truename*))
  (load (make-pathname 
         :name "gbbopen-modules-directory"
         :type "lisp"
         :defaults truename)))

;;; ---------------------------------------------------------------------------
;;;  If there is a gbbopen-modules directory in the users "home" directory,
;;;  load the commands.lisp file (if present) from each module directory
;;;  that is linked from the gbbopen-modules directory. 

(process-gbbopen-modules-directory "commands")

;;; ===========================================================================
;;;				  End of File
;;; ===========================================================================