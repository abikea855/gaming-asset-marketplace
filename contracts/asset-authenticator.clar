
;; Asset Authenticator Contract
;; Provides cryptographic verification and authenticity services for gaming assets
;; Manages certificates, signatures, and verification protocols

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-INVALID-SIGNATURE (err u201))
(define-constant ERR-CERTIFICATE-EXPIRED (err u202))
(define-constant ERR-CERTIFICATE-NOT-FOUND (err u203))
(define-constant ERR-INVALID-CERTIFICATE (err u204))
(define-constant ERR-ASSET-NOT-VERIFIED (err u205))
(define-constant ERR-VERIFICATION-FAILED (err u206))
(define-constant ERR-DUPLICATE-CERTIFICATE (err u207))
(define-constant ERR-INVALID-ISSUER (err u208))
(define-constant ERR-REVOKED-CERTIFICATE (err u209))

;; Certificate status constants
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-EXPIRED u2)
(define-constant STATUS-REVOKED u3)
(define-constant STATUS-PENDING u4)

;; Verification levels
(define-constant VERIFICATION-BASIC u1)
(define-constant VERIFICATION-ENHANCED u2)
(define-constant VERIFICATION-PREMIUM u3)

;; Data Variables
(define-data-var certificate-counter uint u0)
(define-data-var verification-counter uint u0)
(define-data-var certificate-fee uint u1000000) ;; 1 STX
(define-data-var verification-fee uint u500000) ;; 0.5 STX

;; Data Maps
(define-map authenticity-certificates
  uint
  {
    asset-id: uint,
    issuer: principal,
    certificate-hash: (buff 32),
    signature: (buff 65),
    issued-at: uint,
    expires-at: uint,
    verification-level: uint,
    status: uint,
    metadata: (string-utf8 200),
    issuer-reputation: uint
  }
)

(define-map authorized-issuers
  principal
  {
    name: (string-utf8 50),
    reputation-score: uint,
    total-certificates: uint,
    valid-certificates: uint,
    is-active: bool,
    registered-at: uint,
    specialization: (string-utf8 100)
  }
)

(define-map asset-verifications
  uint
  {
    asset-id: uint,
    verifier: principal,
    verification-hash: (buff 32),
    verification-data: (string-utf8 300),
    verified-at: uint,
    verification-level: uint,
    confidence-score: uint,
    attributes-verified: (list 10 (string-ascii 20)),
    is-valid: bool
  }
)

(define-map certificate-chains
  { root-cert: uint, child-cert: uint }
  {
    relationship-type: (string-ascii 15),
    created-at: uint,
    verified-by: principal,
    trust-level: uint
  }
)

(define-map verification-history
  { asset-id: uint, verification-id: uint }
  {
    verifier: principal,
    action: (string-ascii 20),
    timestamp: uint,
    details: (string-utf8 150),
    success: bool
  }
)

(define-map asset-authenticity-scores
  uint
  {
    overall-score: uint,
    certificate-score: uint,
    verification-score: uint,
    issuer-score: uint,
    age-score: uint,
    last-updated: uint,
    confidence-level: uint
  }
)

;; Reputation tracking
(define-map issuer-performance
  principal
  {
    successful-verifications: uint,
    failed-verifications: uint,
    disputed-certificates: uint,
    average-confidence: uint,
    last-activity: uint
  }
)

;; Private Functions
(define-private (calculate-authenticity-score (asset-id uint))
  (let (
    (certificate-data (map-get? authenticity-certificates asset-id))
    (verification-data (map-get? asset-verifications asset-id))
  )
    (match certificate-data
      cert-info
        (let (
          (cert-score (calculate-certificate-score cert-info))
          (verif-score (calculate-verification-score verification-data))
          (issuer-score (get-issuer-reputation-score (get issuer cert-info)))
          (age-score (calculate-age-score (get issued-at cert-info)))
        )
          (+ (* cert-score u25) (* verif-score u25) (* issuer-score u25) (* age-score u25))
        )
      u0
    )
  )
)

(define-private (calculate-certificate-score (cert-info (tuple (asset-id uint) (issuer principal) (certificate-hash (buff 32)) (signature (buff 65)) (issued-at uint) (expires-at uint) (verification-level uint) (status uint) (metadata (string-utf8 200)) (issuer-reputation uint))))
  (let (
    (status-score (if (is-eq (get status cert-info) STATUS-ACTIVE) u100 u0))
    (level-score (* (get verification-level cert-info) u20))
    (expiry-score (if (> (get expires-at cert-info) block-height) u50 u0))
  )
    (/ (+ status-score level-score expiry-score) u3)
  )
)

(define-private (calculate-verification-score (verification-data (optional (tuple (asset-id uint) (verifier principal) (verification-hash (buff 32)) (verification-data (string-utf8 300)) (verified-at uint) (verification-level uint) (confidence-score uint) (attributes-verified (list 10 (string-ascii 20))) (is-valid bool)))))
  (match verification-data
    verif-info (if (get is-valid verif-info) (get confidence-score verif-info) u0)
    u50 ;; Default score if no verification data
  )
)

(define-private (get-issuer-reputation-score (issuer principal))
  (match (map-get? authorized-issuers issuer)
    issuer-info (get reputation-score issuer-info)
    u50 ;; Default score for unknown issuers
  )
)

(define-private (calculate-age-score (issued-at uint))
  (let (
    (age (- block-height issued-at))
  )
    (if (<= age u1000) u100 ;; Very recent
      (if (<= age u10000) u75 ;; Recent
        (if (<= age u50000) u50 ;; Moderate age
          u25 ;; Old
        )
      )
    )
  )
)

(define-private (update-issuer-reputation (issuer principal) (success bool))
  (match (map-get? issuer-performance issuer)
    performance
      (map-set issuer-performance
        issuer
        (if success
          (merge performance
            {
              successful-verifications: (+ (get successful-verifications performance) u1),
              last-activity: block-height
            }
          )
          (merge performance
            {
              failed-verifications: (+ (get failed-verifications performance) u1),
              last-activity: block-height
            }
          )
        )
      )
    ;; Initialize if not exists
    (map-set issuer-performance
      issuer
      {
        successful-verifications: (if success u1 u0),
        failed-verifications: (if success u0 u1),
        disputed-certificates: u0,
        average-confidence: u75,
        last-activity: block-height
      }
    )
  )
)

;; Public Functions
(define-public (register-issuer
    (name (string-utf8 50))
    (specialization (string-utf8 100))
  )
  (begin
    (map-set authorized-issuers
      tx-sender
      {
        name: name,
        reputation-score: u75, ;; Starting reputation
        total-certificates: u0,
        valid-certificates: u0,
        is-active: true,
        registered-at: block-height,
        specialization: specialization
      }
    )
    (ok tx-sender)
  )
)

(define-public (issue-authenticity-certificate
    (asset-id uint)
    (certificate-hash (buff 32))
    (signature (buff 65))
    (expires-at uint)
    (verification-level uint)
    (metadata (string-utf8 200))
  )
  (let (
    (certificate-id (+ (var-get certificate-counter) u1))
    (issuer-info (unwrap! (map-get? authorized-issuers tx-sender) ERR-NOT-AUTHORIZED))
  )
    (asserts! (get is-active issuer-info) ERR-NOT-AUTHORIZED)
    (asserts! (> expires-at block-height) ERR-INVALID-CERTIFICATE)
    (asserts! (and (>= verification-level VERIFICATION-BASIC) (<= verification-level VERIFICATION-PREMIUM)) ERR-INVALID-CERTIFICATE)
    
    ;; Check for fee payment (simplified for this example)
    (try! (stx-transfer? (var-get certificate-fee) tx-sender CONTRACT-OWNER))
    
    ;; Create certificate
    (map-set authenticity-certificates
      certificate-id
      {
        asset-id: asset-id,
        issuer: tx-sender,
        certificate-hash: certificate-hash,
        signature: signature,
        issued-at: block-height,
        expires-at: expires-at,
        verification-level: verification-level,
        status: STATUS-ACTIVE,
        metadata: metadata,
        issuer-reputation: (get reputation-score issuer-info)
      }
    )
    
    ;; Update issuer statistics
    (map-set authorized-issuers
      tx-sender
      (merge issuer-info
        {
          total-certificates: (+ (get total-certificates issuer-info) u1),
          valid-certificates: (+ (get valid-certificates issuer-info) u1)
        }
      )
    )
    
    ;; Calculate and store authenticity score
    (let (
      (authenticity-score (calculate-authenticity-score asset-id))
    )
      (map-set asset-authenticity-scores
        asset-id
        {
          overall-score: authenticity-score,
          certificate-score: (calculate-certificate-score (unwrap-panic (map-get? authenticity-certificates certificate-id))),
          verification-score: u0, ;; Will be updated when verification is added
          issuer-score: (get reputation-score issuer-info),
          age-score: u100, ;; New certificate gets full age score
          last-updated: block-height,
          confidence-level: verification-level
        }
      )
    )
    
    (var-set certificate-counter certificate-id)
    (ok certificate-id)
  )
)

(define-public (verify-asset-authenticity
    (asset-id uint)
    (verification-hash (buff 32))
    (verification-data (string-utf8 300))
    (attributes-verified (list 10 (string-ascii 20)))
    (confidence-score uint)
  )
  (let (
    (verification-id (+ (var-get verification-counter) u1))
    (certificate-exists (is-some (map-get? authenticity-certificates asset-id)))
  )
    (asserts! certificate-exists ERR-CERTIFICATE-NOT-FOUND)
    (asserts! (<= confidence-score u100) ERR-VERIFICATION-FAILED)
    
    ;; Charge verification fee
    (try! (stx-transfer? (var-get verification-fee) tx-sender CONTRACT-OWNER))
    
    ;; Store verification
    (map-set asset-verifications
      verification-id
      {
        asset-id: asset-id,
        verifier: tx-sender,
        verification-hash: verification-hash,
        verification-data: verification-data,
        verified-at: block-height,
        verification-level: VERIFICATION-ENHANCED,
        confidence-score: confidence-score,
        attributes-verified: attributes-verified,
        is-valid: (>= confidence-score u70)
      }
    )
    
    ;; Update authenticity score
    (let (
      (new-score (calculate-authenticity-score asset-id))
    )
      (map-set asset-authenticity-scores
        asset-id
        (merge
          (default-to
            {
              overall-score: u0,
              certificate-score: u0,
              verification-score: u0,
              issuer-score: u0,
              age-score: u0,
              last-updated: u0,
              confidence-level: u0
            }
            (map-get? asset-authenticity-scores asset-id)
          )
          {
            overall-score: new-score,
            verification-score: confidence-score,
            last-updated: block-height
          }
        )
      )
    )
    
    (var-set verification-counter verification-id)
    (ok verification-id)
  )
)

(define-public (revoke-certificate (certificate-id uint))
  (let (
    (certificate (unwrap! (map-get? authenticity-certificates certificate-id) ERR-CERTIFICATE-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get issuer certificate)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status certificate) STATUS-ACTIVE) ERR-INVALID-CERTIFICATE)
    
    ;; Update certificate status
    (map-set authenticity-certificates
      certificate-id
      (merge certificate { status: STATUS-REVOKED })
    )
    
    ;; Update issuer statistics
    (let (
      (issuer-info (unwrap-panic (map-get? authorized-issuers tx-sender)))
    )
      (map-set authorized-issuers
        tx-sender
        (merge issuer-info
          {
            valid-certificates: (- (get valid-certificates issuer-info) u1)
          }
        )
      )
    )
    
    (update-issuer-reputation tx-sender false)
    (ok certificate-id)
  )
)

(define-public (challenge-authenticity (asset-id uint) (reason (string-utf8 200)))
  (let (
    (certificate (map-get? authenticity-certificates asset-id))
  )
    (match certificate
      cert-info
        (begin
          ;; Record challenge in verification history
          (map-set verification-history
            { asset-id: asset-id, verification-id: (var-get verification-counter) }
            {
              verifier: tx-sender,
              action: "challenge",
              timestamp: block-height,
              details: (unwrap-panic (as-max-len? reason u150)),
              success: true
            }
          )
          
          ;; Reduce confidence in issuer
          (update-issuer-reputation (get issuer cert-info) false)
          
          (ok true)
        )
      ERR-CERTIFICATE-NOT-FOUND
    )
  )
)

;; Read-only Functions
(define-read-only (get-certificate-details (certificate-id uint))
  (map-get? authenticity-certificates certificate-id)
)

(define-read-only (get-issuer-details (issuer principal))
  (map-get? authorized-issuers issuer)
)

(define-read-only (get-asset-verification (verification-id uint))
  (map-get? asset-verifications verification-id)
)

(define-read-only (get-authenticity-score (asset-id uint))
  (map-get? asset-authenticity-scores asset-id)
)

(define-read-only (verify-certificate-signature (certificate-id uint) (expected-hash (buff 32)))
  (match (map-get? authenticity-certificates certificate-id)
    cert-info (is-eq (get certificate-hash cert-info) expected-hash)
    false
  )
)

(define-read-only (is-certificate-valid (certificate-id uint))
  (match (map-get? authenticity-certificates certificate-id)
    cert-info
      (and
        (is-eq (get status cert-info) STATUS-ACTIVE)
        (> (get expires-at cert-info) block-height)
      )
    false
  )
)

(define-read-only (get-issuer-reputation (issuer principal))
  (match (map-get? authorized-issuers issuer)
    issuer-info (get reputation-score issuer-info)
    u0
  )
)

(define-read-only (get-verification-history (asset-id uint) (verification-id uint))
  (map-get? verification-history { asset-id: asset-id, verification-id: verification-id })
)

(define-read-only (get-system-stats)
  {
    total-certificates: (var-get certificate-counter),
    total-verifications: (var-get verification-counter),
    certificate-fee: (var-get certificate-fee),
    verification-fee: (var-get verification-fee)
  }
)

