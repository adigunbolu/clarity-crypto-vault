;; CryptoVault Prime

;; Error Code Definitions
(define-constant ERROR_ACCESS_DENIED (err u401))
(define-constant ERROR_BAD_REQUEST (err u400))
(define-constant ERROR_FORBIDDEN (err u403))
(define-constant ERROR_TIMEOUT_CONSTRAINT (err u408))
(define-constant ERROR_NOT_FOUND (err u404))
(define-constant ERROR_CONFLICT (err u409))
(define-constant ERROR_INVALID_FORMAT (err u422))
(define-constant ERROR_LEVEL_CONSTRAINT (err u405))
(define-constant ERROR_TAXONOMY_CONSTRAINT (err u406))
(define-constant REPOSITORY_ADMINISTRATOR tx-sender)

;; Permission Level Constants
(define-constant PERMISSION_VIEW "view")
(define-constant PERMISSION_MODIFY "modify")
(define-constant PERMISSION_SUPERVISOR "supervisor")

;; Repository Statistics
(define-data-var archive-count uint u0)


;; Input Validation Utilities
(define-private (verify-entry-label (label (string-ascii 50)))
    (and
        (> (len label) u0)
        (<= (len label) u50)
    )
)

(define-private (verify-integrity-signature (signature (string-ascii 64)))
    (and
        (is-eq (len signature) u64)
        (> (len signature) u0)
    )
)

(define-private (verify-tags-collection (tag-collection (list 5 (string-ascii 30))))
    (and
        (>= (len tag-collection) u1)
        (<= (len tag-collection) u5)
        (is-eq (len (filter verify-tag-format tag-collection)) (len tag-collection))
    )
)

(define-private (verify-tag-format (tag (string-ascii 30)))
    (and
        (> (len tag) u0)
        (<= (len tag) u30)
    )
)

;; Primary Data Storage Structures
(define-map archive-entries
    { entry-id: uint }
    {
        label: (string-ascii 50),
        custodian: principal,
        integrity-signature: (string-ascii 64),
        supplementary-data: (string-ascii 200),
        timestamp-created: uint,
        timestamp-updated: uint,
        taxonomy: (string-ascii 20),
        tags: (list 5 (string-ascii 30))
    }
)

(define-map collaboration-registry
    { entry-id: uint, collaborator: principal }
    {
        permission-tier: (string-ascii 10),
        timestamp-assigned: uint,
        timestamp-termination: uint,
        editing-privileges: bool
    }
)

(define-private (verify-supplementary-data (data (string-ascii 200)))
    (and
        (>= (len data) u1)
        (<= (len data) u200)
    )
)

(define-private (verify-taxonomy (taxonomy-value (string-ascii 20)))
    (and
        (>= (len taxonomy-value) u1)
        (<= (len taxonomy-value) u20)
    )
)
