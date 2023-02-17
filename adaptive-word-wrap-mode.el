;;; adaptive-word-wrap-mode.el --- major mode for editing indent awarde word wrap -*- coding: utf-8; lexical-binding: t; -*-

(defvar adaptive-word-wrap-extra-indent 'double
  "The amount of extra indentation for wrapped code lines.
When 'double, indent by twice the major-mode indentation.
When 'single, indent by the major-mode indentation.
When a positive integer, indent by this fixed amount.
When a negative integer, dedent by this fixed amount.
Otherwise no extra indentation will be used.")

(defvar adaptive-word-wrap-disabled-modes
  '(fundamental-mode so-long-mode)
  "Major-modes where `global-adaptive-word-wrap-mode' should not enable
`adaptive-word-wrap-mode'.")

(defvar adaptive-word-wrap-visual-modes
  '(org-mode)
  "Major-modes where `adaptive-word-wrap-mode' should not use
`adaptive-wrap-prefix-mode'.")

(defvar adaptive-word-wrap-text-modes
  '(text-mode markdown-mode markdown-view-mode gfm-mode gfm-view-mode rst-mode
    latex-mode LaTeX-mode)
  "Major-modes where `adaptive-word-wrap-mode' should not provide extra indentation.")

(when (memq 'visual-line-mode text-mode-hook)
  (remove-hook 'text-mode-hook #'visual-line-mode)
  (add-hook 'text-mode-hook #'adaptive-word-wrap-mode))

(defvar adaptive-word-wrap--major-mode-is-visual nil)
(defvar adaptive-word-wrap--major-mode-is-text nil)
(defvar adaptive-word-wrap--enable-adaptive-wrap-mode nil)
(defvar adaptive-word-wrap--enable-visual-line-mode nil)
(defvar adaptive-word-wrap--major-mode-indent-var nil)

(defvar adaptive-wrap-extra-indent)
(defun adaptive-word-wrap--adjust-extra-indent-a (fn beg end)
  "Contextually adjust extra adaptive-word-wrap indentation."
  (let ((adaptive-wrap-extra-indent (adaptive-word-wrap--calc-extra-indent beg)))
    (funcall fn beg end)))

(defun adaptive-word-wrap--calc-extra-indent (p)
  "Calculate extra adaptive-word-wrap indentation at point."
  (if (not (or adaptive-word-wrap--major-mode-is-text
               (sp-point-in-string-or-comment p)))
      (pcase adaptive-word-wrap-extra-indent
        ('double
         (* 2 (symbol-value adaptive-word-wrap--major-mode-indent-var)))
        ('single
         (symbol-value adaptive-word-wrap--major-mode-indent-var))
        ((and (pred integerp) fixed)
         fixed)
        (_ 0))
    0))

;;;###autoload
(define-minor-mode adaptive-word-wrap-mode
  "Wrap long lines in the buffer with language-aware indentation.

This mode configures `adaptive-wrap' and `visual-line-mode' to wrap long lines
without modifying the buffer content. This is useful when dealing with legacy
code which contains gratuitously long lines, or running emacs on your
wrist-phone.

Wrapped lines will be indented to match the preceding line. In code buffers,
lines which are not inside a string or comment will have additional indentation
according to the configuration of `adaptive-word-wrap-extra-indent'."
  :init-value nil
  (if adaptive-word-wrap-mode
      (progn
        (setq-local adaptive-word-wrap--major-mode-is-visual
                    (memq major-mode adaptive-word-wrap-visual-modes))
        (setq-local adaptive-word-wrap--major-mode-is-text
                    (memq major-mode adaptive-word-wrap-text-modes))

        (setq-local adaptive-word-wrap--enable-adaptive-wrap-mode
                    (and (not (bound-and-true-p adaptive-wrap-prefix-mode))
                         (not adaptive-word-wrap--major-mode-is-visual)))

        (setq-local adaptive-word-wrap--enable-visual-line-mode
                    (not (bound-and-true-p visual-line-mode)))

        (unless adaptive-word-wrap--major-mode-is-visual
          (require 'dtrt-indent) ; for dtrt-indent--search-hook-mapping
          (require 'smartparens) ; for sp-point-in-string-or-comment

          (setq-local adaptive-word-wrap--major-mode-indent-var
                      (caddr (dtrt-indent--search-hook-mapping major-mode)))

          (advice-add #'adaptive-wrap-fill-context-prefix :around #'adaptive-word-wrap--adjust-extra-indent-a))

        (when adaptive-word-wrap--enable-adaptive-wrap-mode
          (adaptive-wrap-prefix-mode +1))
        (when adaptive-word-wrap--enable-visual-line-mode
          (visual-line-mode +1)))

    ;; disable adaptive-word-wrap-mode
    (unless adaptive-word-wrap--major-mode-is-visual
      (advice-remove #'adaptive-wrap-fill-context-prefix #'adaptive-word-wrap--adjust-extra-indent-a))

    (when adaptive-word-wrap--enable-adaptive-wrap-mode
      (adaptive-wrap-prefix-mode -1))
    (when adaptive-word-wrap--enable-visual-line-mode
      (visual-line-mode -1))))

(defun adaptive-word-wrap--enable-global-mode ()
  "Enable `adaptive-word-wrap-mode' for `adaptive-word-wrap-global-mode'.

Wrapping will be automatically enabled in all modes except special modes, or
modes explicitly listed in `adaptive-word-wrap-disabled-modes'."
  (unless (or (eq (get major-mode 'mode-class) 'special)
              (memq major-mode adaptive-word-wrap-disabled-modes))
    (adaptive-word-wrap-mode +1)))

;;;###autoload
(define-globalized-minor-mode global-adaptive-word-wrap-mode
  adaptive-word-wrap-mode
  adaptive-word-wrap--enable-global-mode)
  
(provide 'adaptive-word-wrap-mode)
