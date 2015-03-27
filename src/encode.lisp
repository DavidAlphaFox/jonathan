(in-package :cl-user)
(defpackage jonathan.encode
  (:use :cl
        :jonathan.util)
  (:import-from :fast-io
                :fast-write-byte
                :make-output-buffer
                :finish-output-buffer)
  (:import-from :trivial-types
                :association-list-p)
  (:export :*octet-as-default*
           :*from*
           :to-json
           :%to-json
           :%write-char
           :%write-string))
(in-package :jonathan.encode)

(declaim (optimize (speed 3) (safety 0) (debug 0)))

(defvar *octet* nil)
(defvar *from* nil)
(defvar *stream* nil)

(declaim (inline %write-string))
(defun %write-string (string)
  (if *octet*
      (loop for c across string
            do (fast-write-byte (char-code c) *stream*))
      (write-string string *stream*))
  nil)

(declaim (inline %write-char))
(defun %write-char (char)
  (if *octet*
      (fast-write-byte (char-code char) *stream*)
      (write-char char *stream*))
  nil)

(defun to-json (obj &key (octet *octet*) (from *from*))
  "Converting object to JSON String."
  (let ((*stream* (if octet
                      (make-output-buffer)
                      (make-string-output-stream)))
        (*octet* octet)
        (*from* from))
    (%to-json obj)
    (if octet
        (finish-output-buffer *stream*)
        (get-output-stream-string *stream*))))

(defgeneric %to-json (obj))

(defmethod %to-json ((string string))
  (%write-char #\")
  (loop for char across string
        do (case char
             (#\newline (%write-string "\\n"))
             (#\return (%write-string "\\r"))
             (#\tab (%write-string "\\t"))
             (#\" (%write-string "\\\""))
             (#\\ (%write-string "\\\\"))
             (t (%write-char char))))
  (%write-char #\"))

(defmethod %to-json ((number number))
  (%write-string (princ-to-string number)))

(defmethod %to-json ((ratio ratio))
  (%to-json (coerce ratio 'float)))

(defmethod %to-json ((list list))
  (cond
    ((and (eq *from* :alist)
          (trivial-types:association-list-p list))
     (progn (%write-char #\{)
            (loop for (item rest) on list
                  do (%to-json (princ-to-string (car item)))
                  do (%write-char #\:)
                  do (%to-json (cdr item))
                  when rest do (%write-char #\,))
            (%write-char #\})))
    ((my-plist-p list)
     (progn (%write-char #\{)
            (loop for (key val next) on list by #'cddr
                  do (%to-json (princ-to-string key))
                  do (%write-char #\:)
                  do (%to-json val)
                  when next do (%write-char #\,))
            (%write-char #\})))
    (t
     (progn (%write-char #\[)
            (loop for (item next) on list
                  do (%to-json item)
                  when next do (%write-char #\,))
            (%write-char #\])))))

(defmethod %to-json ((symbol symbol))
  (%to-json (symbol-name symbol)))

(defmethod %to-json ((true (eql t)))
  (declare (ignore true))
  (%write-string "true"))

(defmethod %to-json ((false (eql :false)))
  (declare (ignore false))
  (%write-string "false"))

(defmethod %to-json ((false (eql :null)))
  (declare (ignore false))
  (%write-string "null"))

(defmethod %to-json ((n (eql nil)))
  (declare (ignore n))
  (%write-string "[]"))
