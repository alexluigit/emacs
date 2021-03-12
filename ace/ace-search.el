(require 'isearch)
(require 'replace)
(require 'grep)

;;;; Isearch

;;;###autoload
(defun ace/search-isearch-other-end ()
  "End current search in the opposite side of the match.
Particularly useful when the match does not fall within the
confines of word boundaries (e.g. multiple words)."
  (interactive)
  (isearch-done)
  (when isearch-other-end
    (goto-char isearch-other-end)))

;;;###autoload
(defun ace/search-isearch-abort-dwim ()
  "Delete failed `isearch' input, single char, or cancel search.

This is a modified variant of `isearch-abort' that allows us to
perform the following, based on the specifics of the case: (i)
delete the entirety of a non-matching part, when present; (ii)
delete a single character, when possible; (iii) exit current
search if no character is present and go back to point where the
search started."
  (interactive)
  (if (eq (length isearch-string) 0)
      (isearch-cancel)
    (isearch-del-char)
    (while (or (not isearch-success) isearch-error)
      (isearch-pop-state)))
  (isearch-update))

;;;###autoload
(defun ace/search-isearch-repeat-forward (&optional arg)
  "Move forward, keeping point at the beginning of the match.
Optionally move to ARGth match in the given direction."
  (interactive "p")
  (when (and isearch-forward isearch-other-end)
    (goto-char isearch-other-end))
  (isearch-repeat-forward (or arg 1)))

;;;###autoload
(defun ace/search-isearch-repeat-backward (&optional arg)
  "Move backward, keeping point at the beginning of the match.
Optionally move to ARGth match in the given direction."
  (interactive "p")
  (when (and (not isearch-forward) isearch-other-end)
    (goto-char isearch-other-end))
  (isearch-repeat-backward (or arg 1)))

(defmacro ace/search-isearch-occurrence (name edge &optional doc)
  "Construct function for moving to `isearch' occurrence.
NAME is the name of the function.  EDGE is either the beginning
or the end of the buffer.  Optional DOC is the resulting
function's docstring."
  `(defun ,name (&optional arg)
     ,doc
     (interactive "p")
     (let ((x (or arg 1))
           (command (intern (format "isearch-%s-of-buffer" ,edge))))
       (isearch-forward-symbol-at-point)
       (funcall command x))))

(ace/search-isearch-occurrence
 ace/search-isearch-beginning-of-buffer
 "beginning"
 "Run `isearch-beginning-of-buffer' for the symbol at point.
With numeric ARG, move to ARGth occurrence counting from the
beginning of the buffer.")

(ace/search-isearch-occurrence
 ace/search-isearch-end-of-buffer
 "end"
 "Run `isearch-end-of-buffer' for the symbol at point.
With numeric ARG, move to ARGth occurrence counting from the
end of the buffer.")

;;;; Replace/Occur

;; TODO: make this work backwardly when given a negative argument
(defun ace/search-isearch-replace-symbol ()
  "Run `query-replace-regexp' for the symbol at point."
  (interactive)
  (isearch-forward-symbol-at-point)
  (isearch-query-replace-regexp))

(defvar ace/search-url-regexp
  (concat
   "\\b\\(\\(www\\.\\|\\(s?https?\\|ftp\\|file\\|gopher\\|"
   "nntp\\|news\\|telnet\\|wais\\|mailto\\|info\\):\\)"
   "\\(//[-a-z0-9_.]+:[0-9]*\\)?"
   (let ((chars "-a-z0-9_=#$@~%&*+\\/[:word:]")
	     (punct "!?:;.,"))
     (concat
      "\\(?:"
      ;; Match paired parentheses, e.g. in Wikipedia URLs:
      ;; http://thread.gmane.org/47B4E3B2.3050402@gmail.com
      "[" chars punct "]+" "(" "[" chars punct "]+" ")"
      "\\(?:" "[" chars punct "]+" "[" chars "]" "\\)?"
      "\\|"
      "[" chars punct "]+" "[" chars "]"
      "\\)"))
   "\\)")
  "Regular expression that matches URLs.
Copy of variable `browse-url-button-regexp'.")

(autoload 'goto-address-mode "goto-addr")

;;;###autoload
(defun ace/search-occur-urls ()
  "Produce buttonised list of all URLs in the current buffer."
  (interactive)
  (add-hook 'occur-hook #'goto-address-mode)
  (occur ace/search-url-regexp "\\&")
  (remove-hook 'occur-hook #'goto-address-mode))

;;;###autoload
(defun ace/search-occur-browse-url ()
  "Point browser at a URL in the buffer using completion.
Which web browser to use depends on the value of the variable
`browse-url-browser-function'.

Also see `ace/search-occur-url'."
  (interactive)
  (let ((matches nil))
    (save-excursion
      (goto-char (point-min))
      (while (search-forward-regexp ace/search-url-regexp nil t)
        (push (match-string-no-properties 0) matches)))
    (funcall browse-url-browser-function
             (completing-read "Browse URL: " matches nil t))))

;; (defun ace/search-occur-dired (regexp &optional nlines)
;;   "Perform `multi-occur' with REGEXP in all dired marked files.
;; When called with a prefix argument NLINES, display NLINES lines before and after."
;;   (interactive (occur-read-primary-args))
;;   (multi-occur (mapcar #'find-file (dired-get-marked-files)) regexp nlines))

;; (defun ace/search-occur-project (regexp &optional nlines)
;;   "Perform `multi-occur' in the current project files."
;;   (interactive (occur-read-primary-args))
;;   (let* ((directory (read-directory-name "Search in directory: "))
;;          (files (if (and directory (not (string= directory (projectile-project-root))))
;;                     (projectile-files-in-project-directory directory)
;;                   (projectile-current-project-files)))
;;          (buffers (mapcar #'find-file 
;;                           (mapcar #'(lambda (file)
;;                                       (expand-file-name file (projectile-project-root)))
;;                                   files))))
;;     (multi-occur buffers regexp nlines)))

;; (defun noccur-project (regexp &optional nlines directory-to-search)
;;   "Perform `multi-occur' with REGEXP in the current project files.
;; When called with a prefix argument NLINES, display NLINES lines before and after.
;; If DIRECTORY-TO-SEARCH is specified, this directory will be searched recursively;
;; otherwise, the user will be prompted to specify a directory to search.
;; For performance reasons, files are filtered using 'find' or 'git
;; ls-files' and 'grep'."
;;   (interactive (occur-read-primary-args))
;;   (let* ((default-directory (or directory-to-search (read-directory-name "Search in directory: ")))
;;          (files (mapcar #'find-file-noselect
;;                         (noccur--find-files regexp))))
;;     (multi-occur files regexp nlines)))

;; (defun noccur--within-git-repository-p ()
;;   (locate-dominating-file default-directory ".git"))

;; (defun noccur--find-files (regexp)
;;   (let* ((listing-command (if (noccur--within-git-repository-p)
;;                               "git ls-files -z"
;;                             "find . -type f -print0"))
;;          (command (format "%s | xargs -0 grep -l \"%s\""
;;                           listing-command
;;                           regexp)))
;;     (split-string (shell-command-to-string command) "\n")))

(provide 'ace-search)
