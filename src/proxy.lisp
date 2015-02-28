(in-package #:aeon)


(defvar *requests* (make-hash-table :test 'eq))
(defvar *requests-counter* 0)

(defun start (address port)
  "Starts the socket server."
  (usocket:socket-server address
                         port
                         #'tcp-handler
                         nil
                         :multi-threading t
                         :in-new-thread t))

(defun tcp-handler (stream)
  "The main TCP handler."
  (declare (type stream stream))
  (let ((str (format nil "~{~A~}"
                     (loop for line = (read-line stream nil 'eof)
                        until (or (eq line 'eof) (string= line ""))
                        collect (concat line '(#\Newline)))))
        (next-id (incf *requests-counter*)))
    (setf (gethash next-id *requests*)
          (list :request str :stream stream))
    (signal! *app* (got-request int) next-id)
    (proxy (http-request-parse-lines (cl-ppcre:split (concat '(#\Newline)) str))
           stream)))

(defun proxy (req stream)
  (handler-case
      (multiple-value-bind (body status headers uri req-stream must-close reason-phrase)
          (drakma:http-request (concat "http://" (http-request-host req) ":"
                                       (write-to-string (http-request-port req))
                                       (http-request-request-uri req)))
        (declare (ignore uri req-stream must-close))
        (write-sequence (http-response-dump status reason-phrase headers
                                            body)
                        stream)
        (force-output stream))
    (error () (progn
                (write-sequence (http-response-dump 500 "Internal Server Error"
                                                    '((X-From . "aeon"))
                                                    "Not yet supported.")
                                stream)))))
