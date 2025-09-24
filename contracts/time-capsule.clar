;; Time Capsule - Digital Legacy Vaults
;; Store a content-hash (or encrypted CID) that is retrievable only after a configured block height.
;; Author: example
;; WARNING: Prototype. Audit before production.

;; Contract declaration
;; Implement the time-capsule trait
(impl-trait .time-capsule-trait.time-capsule-trait)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Storage and Constants
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Constants for validation
(define-constant ERR-ALREADY-EXISTS u100)
(define-constant ERR-INVALID-UNLOCK u101)
(define-constant ERR-NOT-FOUND u102)
(define-constant ERR-NOT-AUTHORIZED u103)
(define-constant ERR-ALREADY-OPENED u104)
(define-constant ERR-INVALID-UNLOCK-TIME u105)
(define-constant ERR-NO-CHANGE u106)
(define-constant ERR-INVALID-HASH u107)

;; Storage
(define-map capsules
  uint  ;; capsule-id
  {
    owner: principal,
    content-hash: (buff 64),
    unlock-block: uint,
    beneficiary: (optional principal),
    opened: bool
  })

;; Event storage
(define-data-var last-event-id uint u0)

(define-map events
  uint
  {
    event-type: (string-ascii 20),
    capsule-id: uint,
    owner: principal,
    data: (optional (tuple (unlock-block uint)))
  })

;; Helpers
(define-constant block-0 u0)
(define-private (current-block)
  block-0)

;; Validation helpers
(define-private (validate-capsule-id (id uint) (should-exist bool))
  (ok 
    (if should-exist
      (asserts! (is-some (map-get? capsules id)) (err ERR-NOT-FOUND))
      (asserts! (is-none (map-get? capsules id)) (err ERR-ALREADY-EXISTS)))))

(define-private (validate-unlock-time (unlock uint))
  (ok (asserts! (> unlock (current-block)) (err ERR-INVALID-UNLOCK))))

(define-private (validate-owner (owner principal))
  (ok (asserts! (is-eq tx-sender owner) (err ERR-NOT-AUTHORIZED))))

(define-private (validate-not-opened (opened bool))
  (ok (asserts! (not opened) (err ERR-ALREADY-OPENED))))

;; Set or update beneficiary
(define-public (set-beneficiary (capsule-id uint) (new-beneficiary principal))
  (let ((capsule (unwrap! (map-get? capsules capsule-id) (err ERR-NOT-FOUND))))
    (begin
      (asserts! (is-eq tx-sender (get owner capsule)) (err ERR-NOT-AUTHORIZED))
      (asserts! (not (get opened capsule)) (err ERR-ALREADY-OPENED))
      (map-set capsules capsule-id 
        (merge capsule { beneficiary: (some new-beneficiary) }))
      (print { 
        event-type: "beneficiary-set", 
        capsule-id: capsule-id,
        owner: tx-sender,
        beneficiary: new-beneficiary 
      })
      (ok true))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Public functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Create a new time-capsule.
;; - capsule-id: user-defined unique id (uint)
;; - content-hash: buffer (e.g., sha256 hash or ipfs CID bytes)
;; - unlock-block: block height after which capsule can be opened
;; - beneficiary: optional principal who can open after unlock (if owner doesn't)
;; Create a new time-capsule
(define-public (create-capsule (capsule-id uint) (content-hash (buff 64)) (unlock-block uint) (beneficiary (optional principal)))
  (let ((existing-capsule (map-get? capsules capsule-id)))
    (if (is-some existing-capsule)
      (err ERR-ALREADY-EXISTS)
      (begin
        ;; Validate inputs
        (asserts! (is-eq (len content-hash) u64) (err ERR-INVALID-HASH))
        (asserts! (> unlock-block (current-block)) (err ERR-INVALID-UNLOCK))
        ;; Create capsule
        (let ((capsule { 
                owner: tx-sender
              , content-hash: content-hash
              , unlock-block: unlock-block
              , beneficiary: beneficiary
              , opened: false }))
          ;; Store capsule and emit event
          (begin
            (map-set capsules capsule-id capsule)
            (print {
              event-type: "capsule-created",
              capsule-id: capsule-id,
              unlock-block: unlock-block,
              beneficiary: beneficiary
            })
            (ok capsule-id)))))))

;; Extend unlock block height
(define-public (extend-unlock (capsule-id uint) (new-unlock uint))
  (let ((capsule (unwrap! (map-get? capsules capsule-id) (err ERR-NOT-FOUND))))
    (begin
      ;; Validate state
      (asserts! (is-eq tx-sender (get owner capsule)) (err ERR-NOT-AUTHORIZED))
      (asserts! (not (get opened capsule)) (err ERR-ALREADY-OPENED))
      (asserts! (> new-unlock (get unlock-block capsule)) (err ERR-INVALID-UNLOCK-TIME))
      ;; Update capsule
      (let ((updated-capsule (merge capsule { unlock-block: new-unlock })))
        (begin
          (map-set capsules capsule-id updated-capsule)
          (print {
            event-type: "unlock-extended",
            capsule-id: capsule-id,
            old-unlock: (get unlock-block capsule),
            new-unlock: new-unlock
          })
          (ok new-unlock))))))

;; Open a capsule
(define-public (open-capsule (capsule-id uint))
  (let ((capsule (unwrap! (map-get? capsules capsule-id) (err ERR-NOT-FOUND))))
    (let ((is-owner (is-eq tx-sender (get owner capsule)))
          (beneficiary (get beneficiary capsule)))
      (begin
        ;; Validate authorization
        (asserts! (or is-owner
                   (and (is-some beneficiary)
                        (is-eq tx-sender (unwrap! beneficiary (err ERR-NOT-AUTHORIZED)))))
                (err ERR-NOT-AUTHORIZED))
        ;; Validate state
        (asserts! (not (get opened capsule)) (err ERR-ALREADY-OPENED))
        (asserts! (>= (current-block) (get unlock-block capsule)) (err ERR-INVALID-UNLOCK))
        ;; Update capsule
        (let ((updated-capsule (merge capsule { opened: true })))
          (begin
            (map-set capsules capsule-id updated-capsule)
            (print {
              event-type: "capsule-opened",
              capsule-id: capsule-id,
              opener: tx-sender
            })
            (ok (get content-hash capsule))))))))

;; Owner may delete a capsule before it's opened
(define-public (delete-capsule (capsule-id uint))
  (let ((capsule (unwrap! (map-get? capsules capsule-id) (err ERR-NOT-FOUND))))
    (begin
      ;; Validate state
      (asserts! (is-eq tx-sender (get owner capsule)) (err ERR-NOT-AUTHORIZED))
      (asserts! (not (get opened capsule)) (err ERR-ALREADY-OPENED))
      ;; Delete capsule
      (map-delete capsules capsule-id)
      (print {
        event-type: "capsule-deleted",
        capsule-id: capsule-id,
        owner: tx-sender
      })
      (ok true))))

;; Read-only view: fetch capsule metadata (owner, unlock-block, beneficiary, opened)
(define-read-only (get-capsule (capsule-id uint))
  (match (map-get? capsules capsule-id)
    capsule 
    (ok {
      owner: (get owner capsule),
      unlock-block: (get unlock-block capsule),
      beneficiary: (get beneficiary capsule),
      opened: (get opened capsule)
    })
    (err ERR-NOT-FOUND)))