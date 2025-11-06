;; ------------------------------------------------------------
;; ReCycleX Protocol - Decentralized Waste Reward System
;; Functionality: decentralized-waste-reward-system
;; Author: [Your Name]
;; License: MIT
;; ------------------------------------------------------------

;; -----------------------------
;; 1. Constants & Errors
;; -----------------------------
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_RECORD (err u101))
(define-constant ERR_ALREADY_VERIFIED (err u102))

;; -----------------------------
;; 2. Data Variables & Maps
;; -----------------------------
(define-data-var recycle-counter uint u0)
(define-fungible-token rex-token)

;; store the contract owner (deployer) at contract publish time
(define-data-var contract-owner principal tx-sender)

(define-map recyclers principal bool)
(define-map authorities principal bool)

(define-map recycle-records
  uint
  {
    recycler: principal,
    material: (string-ascii 50),
    weight: uint,
    verified: bool
  }
)

(define-public (register-recycler (account principal))
  (begin
    ;; Only contract owner can register recyclers
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set recyclers account true)
    (ok "Recycler successfully registered")
  )
)

(define-public (register-authority (account principal))
  (begin
    ;; Only contract owner can register authorities
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set authorities account true)
    (ok "Authority successfully registered")
  )
)

;; -----------------------------
;; 4. Recycling Record Functions
;; -----------------------------
(define-public (record-recycle (material (string-ascii 50)) (weight uint))
  (begin
    ;; Only registered recyclers can submit records
    (asserts! (is-some (map-get? recyclers tx-sender)) ERR_UNAUTHORIZED)
    (let ((rec-id (+ (var-get recycle-counter) u1)))
      (map-set recycle-records rec-id
        {
          recycler: tx-sender,
          material: material,
          weight: weight,
          verified: false
        }
      )
      (var-set recycle-counter rec-id)
      (ok (tuple (record-id rec-id) (status "recorded")))
    )
  )
)

(define-public (verify-recycle (rec-id uint))
  (let ((record (map-get? recycle-records rec-id)))
    (begin
      ;; Only authorities can verify records
      (asserts! (is-some (map-get? authorities tx-sender)) ERR_UNAUTHORIZED)
      (asserts! (is-some record) ERR_INVALID_RECORD)
      (let ((data (unwrap-panic record)))
        (if (get verified data)
          ERR_ALREADY_VERIFIED
          (begin
            ;; Update verification status
            (map-set recycle-records rec-id
              {
                recycler: (get recycler data),
                material: (get material data),
                weight: (get weight data),
                verified: true
              }
            )
            ;; Mint REX tokens based on weight recycled
            (try! (ft-mint? rex-token (get weight data) (get recycler data)))
            (ok (tuple (verified true) (reward (get weight data))))
          )
        )
      )
    )
  )
)

;; -----------------------------
;; 5. Read-only Functions
;; -----------------------------
(define-read-only (get-record (rec-id uint))
  (map-get? recycle-records rec-id)
)

(define-read-only (get-total-records)
  (var-get recycle-counter)
)

(define-read-only (is-recycler (account principal))
  (default-to false (map-get? recyclers account))
)

(define-read-only (is-authority (account principal))
  (default-to false (map-get? authorities account))
)
