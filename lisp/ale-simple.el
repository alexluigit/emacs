(defgroup ale-simple ()
  "Generic utilities for my dotemacs."
  :group 'editing)

(defcustom ale/simple-date-specifier "%F"
  "Date specifier for `format-time-string'.
Used by `ale/simple-insert-date'."
  :type 'string
  :group 'ale/simple)

(defcustom ale/simple-time-specifier "%R %z"
  "Time specifier for `format-time-string'.
Used by `ale/simple-insert-date'."
  :type 'string
  :group 'ale/simple)

;;; Commands

;;;; Comands for text editing

;;;###autoload
(defun ale/simple-replace-line-or-region ()
  "Replace line or region with latest kill.
This command can then be followed by the standard
`yank-pop' (default is bound to \\[yank-pop])."
  (interactive)
  (if (use-region-p)
      (delete-region (region-beginning) (region-end))
    (delete-region (point-at-bol) (point-at-eol)))
  (yank))

;;;###autoload
(defun ale/simple-insert-date (&optional arg)
  "Insert the current date as `ale/simple-date-specifier'.

With optional prefix ARG (\\[universal-argument]) also append the
current time understood as `ale/simple-time-specifier'.

When region is active, delete the highlighted text and replace it
with the specified date."
  (interactive "P")
  (let* ((date ale/simple-date-specifier)
         (time ale/simple-time-specifier)
         (format (if arg (format "%s %s" date time) date)))
    (when (use-region-p)
      (delete-region (region-beginning) (region-end)))
    (insert (format-time-string format))))


(autoload 'ffap-url-at-point "ffap")
(defvar ffap-string-at-point-region)

;;;###autoload
(defun ale/simple-escape-url ()
  "Wrap URL in angled brackets."
  (interactive)
  (when-let ((url (ffap-url-at-point)))
    (let* ((reg ffap-string-at-point-region)
           (beg (car reg))
           (end (cadr reg))
           (string (if (string-match-p "^mailto:" url)
                       (substring url 7)
                     url)))
      (delete-region beg end)
      (insert (format "<%s>" string)))))

;;;; Commands for code navigation (work in progress)

;;;###autoload
(defun ale/simple-downward-list (&optional arg)
  "Like `backward-up-list' but defaults to a forward motion.
With optional ARG, move that many times in the given
direction (negative is forward due to this being a
'backward'-facing command)."
  (interactive "P")
  (backward-up-list (or arg -1)))

;;;; Commands for paragraphs

(defvar-local ale/simple--auto-fill-cycle-state 1
  "Representation of `ale/simple-auto-fill-cycle' state.")

;; Based on gungadin-cylocal.el (private communication with Christopher
;; Dimech---disclosed with permission).
;;;###autoload
(defun ale/simple-auto-fill-cycle ()
  "Cycles auto fill for comments, everything, nothing."
  (interactive)
  (let ((n ale/simple--auto-fill-cycle-state))
    (pcase n
      (2
       (message "Auto fill %s" (propertize "buffer" 'face 'warning))
       (setq-local comment-auto-fill-only-comments nil)
       (setq-local ale/simple--auto-fill-cycle-state (1+ n)))
      (3
       (message "Disable auto fill")
       (auto-fill-mode 0)
       (setq-local ale/simple--auto-fill-cycle-state (1+ n)))
      (_
       (message "Auto fill %s" (propertize "comments" 'face 'success))
       (setq-local comment-auto-fill-only-comments t)
       (auto-fill-mode 1)
       (setq-local ale/simple--auto-fill-cycle-state 2)))))

;;;###autoload
(defun ale/simple-unfill-region-or-paragraph (&optional beg end)
  "Unfill paragraph or, when active, the region.
Join all lines in region delimited by BEG and END, if active,
while respecting any empty lines (so multiple paragraphs are not
joined, just unfilled).  If no region is active, operate on the
paragraph.  The idea is to produce the opposite effect of both
`fill-paragraph' and `fill-region'."
  (interactive "r")
  (let ((fill-column most-positive-fixnum))
    (if (use-region-p)
        (fill-region beg end)
      (fill-paragraph))))

;;;; Commands for windows

;; Inspired by Pierre Neidhardt's windower:
;; https://gitlab.com/ambrevar/emacs-windower/-/blob/master/windower.el
(defvar ale/simple--windows-current nil
  "Current window configuration.")

;;;###autoload
(define-minor-mode ale/simple-monocle
  "Toggle between multiple windows and single window.
This is the equivalent of maximising a window.  Tiling window
managers such as DWM, BSPWM refer to this state as 'monocle'."
  :lighter " -M-"
  :global nil
  (let ((config ale/simple--windows-current)
        (buf (current-buffer)))
    (if (one-window-p)
        (when config
          (set-window-configuration config))
      (setq ale/simple--windows-current (current-window-configuration))
      (when (window-parameter nil 'window-side) (delete-window))
      (delete-other-windows)
      (switch-to-buffer buf))))

(defun ale/simple--monocle-disable ()
  "Set variable `ale/simple-monocle' to nil, when appropriate.
To be hooked to `window-configuration-change-hook'."
  (when (and ale/simple-monocle
             (not (and (featurep 'transient) (window-live-p transient--window)))
             (not (one-window-p)))
    (delete-other-windows)
    (ale/simple-monocle -1)
    (set-window-configuration ale/simple--windows-current)))

(add-hook 'window-configuration-change-hook #'ale/simple--monocle-disable)

;;;; Commands for buffers

(defun ale/simple-kill-window-current (&optional force)
  "Kill current window. If current window is the only window,
delete current frame. With optional prefix
ARG (\\[universal-argument]) kill current buffer frame as well."
  (interactive "P")
  (when force (kill-buffer))
  (if (and (featurep 'lf) (lf-live-p))
      (lf-quit)
    (condition-case nil
        (delete-window)
      (error (delete-frame)))))

(defun ale/windmove--wm-takeover (direction)
  (let ((cmd "awesome-client")
        (args (concat
               "require(\"awful\").client.focus.byidx\("
               direction "\)")))
    (start-process "" nil cmd args)))

(defun ale/simple-winmove-r/d (&optional down)
  (interactive "P")
  (cond
   ((and (featurep 'lf) (lf-live-p))
    (ale/windmove--wm-takeover "1"))
   (down
    (condition-case nil (windmove-down)
      (user-error (ale/windmove--wm-takeover "1"))))
   (t
    (condition-case nil (windmove-right)
      (user-error
       (condition-case nil (windmove-down)
         (user-error (ale/windmove--wm-takeover "1"))))))))

(defun ale/simple-winmove-l/u (&optional up)
  (interactive "P")
  (cond
   ((and (featurep 'lf) (lf-live-p))
    (ale/windmove--wm-takeover "-1"))
   (up
    (condition-case nil (windmove-up)
      (user-error (ale/windmove--wm-takeover "-1"))))
   (t
    (condition-case nil (windmove-left)
      (user-error
       (condition-case nil (windmove-up)
         (user-error (ale/windmove--wm-takeover "-1"))))))))

;;;###autoload
(defun ale/simple-rename-file-and-buffer (name)
  "Apply NAME to current file and rename its buffer.
Do not try to make a new directory or anything fancy."
  (interactive
   (list (read-string "Rename current file: " (buffer-file-name))))
  (let* ((file (buffer-file-name)))
    (if (vc-registered file)
        (vc-rename-file file name)
      (rename-file file name))
    (set-visited-file-name name t t)))

(provide 'ale-simple)

;;; ale/simple.el ends here