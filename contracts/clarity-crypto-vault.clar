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

(define-private (verify-permission-tier (tier (string-ascii 10)))
    (or
        (is-eq tier PERMISSION_VIEW)
        (is-eq tier PERMISSION_MODIFY)
        (is-eq tier PERMISSION_SUPERVISOR)
    )
)

(define-private (verify-timespan (timespan uint))
    (and
        (> timespan u0)
        (<= timespan u52560) ;; Maximum timespan ~1 year in blocks
    )
)

(define-private (verify-distinct-user (user principal))
    (not (is-eq user tx-sender))
)

(define-private (is-entry-custodian (entry-id uint) (user principal))
    (match (map-get? archive-entries { entry-id: entry-id })
        entry (is-eq (get custodian entry) user)
        false
    )
)

(define-private (entry-exists (entry-id uint))
    (is-some (map-get? archive-entries { entry-id: entry-id }))
)

(define-private (verify-privileges-flag (privileges-flag bool))
    (or (is-eq privileges-flag true) (is-eq privileges-flag false))
)

;; Main Public Functions
(define-public (register-new-archive 
    (label (string-ascii 50))
    (integrity-signature (string-ascii 64))
    (supplementary-data (string-ascii 200))
    (taxonomy (string-ascii 20))
    (tags (list 5 (string-ascii 30)))
)
    (let
        (
            (new-id (+ (var-get archive-count) u1))
            (current-block block-height)
        )
        (asserts! (verify-entry-label label) ERROR_BAD_REQUEST)
        (asserts! (verify-integrity-signature integrity-signature) ERROR_BAD_REQUEST)
        (asserts! (verify-supplementary-data supplementary-data) ERROR_INVALID_FORMAT)
        (asserts! (verify-taxonomy taxonomy) ERROR_TAXONOMY_CONSTRAINT)
        (asserts! (verify-tags-collection tags) ERROR_INVALID_FORMAT)
        
        (map-set archive-entries
            { entry-id: new-id }
            {
                label: label,
                custodian: tx-sender,
                integrity-signature: integrity-signature,
                supplementary-data: supplementary-data,
                timestamp-created: current-block,
                timestamp-updated: current-block,
                taxonomy: taxonomy,
                tags: tags
            }
        )
        
        (var-set archive-count new-id)
        (ok new-id)
    )
)

(define-public (modify-archive
    (entry-id uint)
    (updated-label (string-ascii 50))
    (updated-integrity-signature (string-ascii 64))
    (updated-supplementary-data (string-ascii 200))
    (updated-tags (list 5 (string-ascii 30)))
)
    (let
        (
            (entry (unwrap! (map-get? archive-entries { entry-id: entry-id }) ERROR_NOT_FOUND))
        )
        (asserts! (is-entry-custodian entry-id tx-sender) ERROR_ACCESS_DENIED)
        (asserts! (verify-entry-label updated-label) ERROR_BAD_REQUEST)
        (asserts! (verify-integrity-signature updated-integrity-signature) ERROR_BAD_REQUEST)
        (asserts! (verify-supplementary-data updated-supplementary-data) ERROR_INVALID_FORMAT)
        (asserts! (verify-tags-collection updated-tags) ERROR_INVALID_FORMAT)
        
        (map-set archive-entries
            { entry-id: entry-id }
            (merge entry {
                label: updated-label,
                integrity-signature: updated-integrity-signature,
                supplementary-data: updated-supplementary-data,
                timestamp-updated: block-height,
                tags: updated-tags
            })
        )
        (ok true)
    )
)

(define-public (enable-collaboration
    (entry-id uint)
    (collaborator principal)
    (permission-tier (string-ascii 10))
    (timespan uint)
    (editing-privileges bool)
)
    (let
        (
            (current-block block-height)
            (termination-block (+ current-block timespan))
        )
        (asserts! (entry-exists entry-id) ERROR_NOT_FOUND)
        (asserts! (is-entry-custodian entry-id tx-sender) ERROR_ACCESS_DENIED)
        (asserts! (verify-distinct-user collaborator) ERROR_BAD_REQUEST)
        (asserts! (verify-permission-tier permission-tier) ERROR_LEVEL_CONSTRAINT)
        (asserts! (verify-timespan timespan) ERROR_TIMEOUT_CONSTRAINT)
        (asserts! (verify-privileges-flag editing-privileges) ERROR_BAD_REQUEST)
        
        (map-set collaboration-registry
            { entry-id: entry-id, collaborator: collaborator }
            {
                permission-tier: permission-tier,
                timestamp-assigned: current-block,
                timestamp-termination: termination-block,
                editing-privileges: editing-privileges
            }
        )
        (ok true)
    )
)

;; Enhanced version with streamlined validation logic
(define-public (modernized-modify-archive
    (entry-id uint)
    (updated-label (string-ascii 50))
    (updated-integrity-signature (string-ascii 64))
    (updated-supplementary-data (string-ascii 200))
    (updated-tags (list 5 (string-ascii 30)))
)
    (let
        (
            (entry (unwrap! (map-get? archive-entries { entry-id: entry-id }) ERROR_NOT_FOUND))
        )
        (asserts! (is-entry-custodian entry-id tx-sender) ERROR_ACCESS_DENIED)
        (let
            (
                (revised-entry (merge entry {
                    label: updated-label,
                    integrity-signature: updated-integrity-signature,
                    supplementary-data: updated-supplementary-data,
                    tags: updated-tags,
                    timestamp-updated: block-height
                }))
            )
            (map-set archive-entries { entry-id: entry-id } revised-entry)
            (ok true)
        )
    )
)

;; Optimized version with enhanced validation procedures
(define-public (performance-optimized-register
    (label (string-ascii 50))
    (integrity-signature (string-ascii 64))
    (supplementary-data (string-ascii 200))
    (taxonomy (string-ascii 20))
    (tags (list 5 (string-ascii 30)))
)
    (let
        (
            (new-id (+ (var-get archive-count) u1))
            (current-block block-height)
        )
        ;; Pre-validate all inputs before performing any state changes
        (asserts! (verify-entry-label label) ERROR_BAD_REQUEST)
        (asserts! (verify-integrity-signature integrity-signature) ERROR_BAD_REQUEST)
        (asserts! (verify-supplementary-data supplementary-data) ERROR_INVALID_FORMAT)
        (asserts! (verify-taxonomy taxonomy) ERROR_TAXONOMY_CONSTRAINT)
        (asserts! (verify-tags-collection tags) ERROR_INVALID_FORMAT)

        ;; Create single state change after validation
        (map-set archive-entries
            { entry-id: new-id }
            {
                label: label,
                custodian: tx-sender,
                integrity-signature: integrity-signature,
                supplementary-data: supplementary-data,
                timestamp-created: current-block,
                timestamp-updated: current-block,
                taxonomy: taxonomy,
                tags: tags
            }
        )

        ;; Update counter only after successful entry creation
        (var-set archive-count new-id)
        (ok new-id)
    )
)

;; Advanced modification function with enhanced security checks
(define-public (secure-archive-update
    (entry-id uint)
    (updated-label (string-ascii 50))
    (updated-integrity-signature (string-ascii 64))
    (updated-supplementary-data (string-ascii 200))
    (updated-tags (list 5 (string-ascii 30)))
)
    (let
        (
            (entry (unwrap! (map-get? archive-entries { entry-id: entry-id }) ERROR_NOT_FOUND))
            (current-timestamp block-height)
        )
        ;; Validate permissions first
        (asserts! (is-entry-custodian entry-id tx-sender) ERROR_ACCESS_DENIED)
        
        ;; Then validate all inputs
        (asserts! (verify-entry-label updated-label) ERROR_BAD_REQUEST)
        (asserts! (verify-integrity-signature updated-integrity-signature) ERROR_BAD_REQUEST)
        (asserts! (verify-supplementary-data updated-supplementary-data) ERROR_INVALID_FORMAT)
        (asserts! (verify-tags-collection updated-tags) ERROR_INVALID_FORMAT)

        ;; Apply all changes at once to minimize state transitions
        (map-set archive-entries
            { entry-id: entry-id }
            (merge entry {
                label: updated-label,
                integrity-signature: updated-integrity-signature,
                supplementary-data: updated-supplementary-data,
                timestamp-updated: current-timestamp,
                tags: updated-tags
            })
        )
        (ok true)
    )
)

;; Alternate storage structure for improved lookup performance
(define-map indexed-archive-entries
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

;; Enhanced creation function using optimized data structure
(define-public (enhanced-archive-creation
    (label (string-ascii 50))
    (integrity-signature (string-ascii 64))
    (supplementary-data (string-ascii 200))
    (taxonomy (string-ascii 20))
    (tags (list 5 (string-ascii 30)))
)
    (let
        (
            (new-id (+ (var-get archive-count) u1))
            (current-block block-height)
            (initiator tx-sender)
        )
        ;; Comprehensive validation of all provided parameters
        (asserts! (verify-entry-label label) ERROR_BAD_REQUEST)
        (asserts! (verify-integrity-signature integrity-signature) ERROR_BAD_REQUEST)
        (asserts! (verify-supplementary-data supplementary-data) ERROR_INVALID_FORMAT)
        (asserts! (verify-taxonomy taxonomy) ERROR_TAXONOMY_CONSTRAINT)
        (asserts! (verify-tags-collection tags) ERROR_INVALID_FORMAT)

        ;; Create record in optimized storage structure
        (map-set indexed-archive-entries
            { entry-id: new-id }
            {
                label: label,
                custodian: initiator,
                integrity-signature: integrity-signature,
                supplementary-data: supplementary-data,
                timestamp-created: current-block,
                timestamp-updated: current-block,
                taxonomy: taxonomy,
                tags: tags
            }
        )

        ;; Update archive counter
        (var-set archive-count new-id)
        (ok new-id)
    )
)

