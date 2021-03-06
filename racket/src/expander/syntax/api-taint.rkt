#lang racket/base
(require "syntax.rkt"
         "to-list.rkt"
         "scope.rkt"
         "taint-dispatch.rkt"
         (rename-in "taint.rkt"
                    [syntax-tainted? raw:syntax-tainted?]
                    [syntax-arm raw:syntax-arm]
                    [syntax-disarm raw:syntax-disarm]
                    [syntax-rearm raw:syntax-rearm]
                    [syntax-taint raw:syntax-taint])
         (only-in "../expand/syntax-local.rkt" syntax-local-phase-level)
         "../namespace/core.rkt"
         "../namespace/inspector.rkt"
         "../common/contract.rkt"
         (only-in "../expand/context.rkt" get-current-expand-context)
         "../expand/log.rkt")

;; Provides public versions of taint-related syntax functions

(provide syntax-tainted?
         syntax-arm
         syntax-disarm
         syntax-rearm
         syntax-taint)

(define/who (syntax-tainted? s)
  (check who syntax? s)
  (raw:syntax-tainted? s))

(define/who (syntax-arm s [maybe-insp #f] [use-mode? #f])
  (check who syntax? s)
  (unless (or (not maybe-insp)
              (inspector? maybe-insp))
    (raise-argument-error who "(or/c inspector? #f)" maybe-insp))
  (define insp (inspector-for-taint maybe-insp))
  (define armed-s
    (cond
      [use-mode?
       (taint-dispatch
        s
        (lambda (s) (raw:syntax-arm s insp))
        (syntax-local-phase-level))]
      [else
       (raw:syntax-arm s insp)]))
  (define ctx (get-current-expand-context #:fail-ok? #t))
  (when ctx (log-expand ctx 'track-syntax 'arm armed-s s))
  armed-s)

(define/who (syntax-disarm s maybe-insp)
  (check who syntax? s)
  (unless (or (not maybe-insp)
              (inspector? maybe-insp))
    (raise-argument-error who "(or/c inspector? #f)" maybe-insp))
  (define insp (inspector-for-taint maybe-insp))
  (define disarmed-s (raw:syntax-disarm s insp))
  (define ctx (get-current-expand-context #:fail-ok? #t))
  (when ctx (log-expand ctx 'track-syntax 'disarm disarmed-s s))
  disarmed-s)

(define/who (syntax-rearm s from-s [use-mode? #f])
  (check who syntax? s)
  (check who syntax? from-s)
  (define rearmed-s
    (cond
      [use-mode? (taint-dispatch
                  s
                  (lambda (s) (raw:syntax-rearm s from-s))
                  (syntax-local-phase-level))]
      [else
       (raw:syntax-rearm s from-s)]))
  (define ctx (get-current-expand-context #:fail-ok? #t))
  (when ctx (log-expand ctx 'track-syntax 'rearm rearmed-s s))
  rearmed-s)

(define/who (syntax-taint s)
  (check who syntax? s)
  (raw:syntax-taint s))

;; ----------------------------------------

(define (inspector-for-taint maybe-insp)
  (or maybe-insp
      (current-module-code-inspector)
      (current-code-inspector)))
