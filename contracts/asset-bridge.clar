;; Asset Bridge Contract
;; Mint gaming NFTs, facilitate cross-game asset transfers, manage marketplace transactions,
;; and ensure item authenticity and rarity verification

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ASSET-NOT-FOUND (err u101))
(define-constant ERR-GAME-NOT-REGISTERED (err u102))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u103))
(define-constant ERR-ASSET-NOT-TRANSFERABLE (err u104))
(define-constant ERR-INVALID-RARITY (err u105))
(define-constant ERR-MARKETPLACE-CLOSED (err u106))
(define-constant ERR-INVALID-PRICE (err u107))
(define-constant ERR-ASSET-NOT-FOR-SALE (err u108))

;; Rarity levels
(define-constant RARITY-COMMON u1)
(define-constant RARITY-UNCOMMON u2)
(define-constant RARITY-RARE u3)
(define-constant RARITY-EPIC u4)
(define-constant RARITY-LEGENDARY u5)
(define-constant RARITY-MYTHIC u6)

;; Asset types
(define-constant TYPE-CHARACTER u1)
(define-constant TYPE-WEAPON u2)
(define-constant TYPE-ARMOR u3)
(define-constant TYPE-CONSUMABLE u4)
(define-constant TYPE-COLLECTIBLE u5)

;; Data Variables
(define-data-var asset-counter uint u0)
(define-data-var game-counter uint u0)
(define-data-var marketplace-fee uint u250) ;; 2.5%
(define-data-var total-volume uint u0)

;; Data Maps
(define-map gaming-assets
  uint
  {
    owner: principal,
    game-id: uint,
    asset-type: uint,
    name: (string-utf8 50),
    description: (string-utf8 200),
    rarity: uint,
    level: uint,
    transferable: bool,
    metadata-uri: (string-utf8 200),
    created-at: uint,
    last-transfer: uint
  }
)

(define-map registered-games
  uint
  {
    developer: principal,
    name: (string-utf8 50),
    description: (string-utf8 200),
    revenue-share: uint,
    total-assets: uint,
    is-active: bool,
    website: (string-utf8 100)
  }
)

(define-map marketplace-listings
  uint
  {
    seller: principal,
    price: uint,
    listed-at: uint,
    expires-at: uint,
    is-active: bool
  }
)

(define-map asset-history
  { asset-id: uint, event-id: uint }
  {
    event-type: (string-ascii 10),
    from: (optional principal),
    to: principal,
    price: (optional uint),
    timestamp: uint,
    game-id: uint
  }
)

(define-map player-inventories
  principal
  (list 50 uint)
)

(define-map asset-statistics
  uint
  {
    total-transfers: uint,
    total-sales: uint,
    highest-sale: uint,
    average-price: uint,
    current-owner-since: uint
  }
)

(define-data-var event-counter uint u0)

;; Private Functions
(define-private (is-registered-game (game-id uint))
  (match (map-get? registered-games game-id)
    game-info (get is-active game-info)
    false
  )
)

(define-private (calculate-marketplace-fee (price uint))
  (/ (* price (var-get marketplace-fee)) u10000)
)

(define-private (add-to-inventory (owner principal) (asset-id uint))
  (let (
    (current-inventory (default-to (list) (map-get? player-inventories owner)))
  )
    (map-set player-inventories
      owner
      (unwrap-panic (as-max-len? (append current-inventory asset-id) u50))
    )
  )
)

(define-private (record-asset-event (asset-id uint) (event-type (string-ascii 10)) (from (optional principal)) (to principal) (price (optional uint)) (game-id uint))
  (let (
    (event-id (+ (var-get event-counter) u1))
  )
    (map-set asset-history
      { asset-id: asset-id, event-id: event-id }
      {
        event-type: event-type,
        from: from,
        to: to,
        price: price,
        timestamp: block-height,
        game-id: game-id
      }
    )
    (var-set event-counter event-id)
    event-id
  )
)

;; Public Functions
(define-public (register-game
    (name (string-utf8 50))
    (description (string-utf8 200))
    (revenue-share uint)
    (website (string-utf8 100))
  )
  (let (
    (game-id (+ (var-get game-counter) u1))
  )
    (map-set registered-games
      game-id
      {
        developer: tx-sender,
        name: name,
        description: description,
        revenue-share: revenue-share,
        total-assets: u0,
        is-active: true,
        website: website
      }
    )
    
    (var-set game-counter game-id)
    (ok game-id)
  )
)

(define-public (mint-gaming-asset
    (recipient principal)
    (game-id uint)
    (asset-type uint)
    (name (string-utf8 50))
    (description (string-utf8 200))
    (rarity uint)
    (level uint)
    (metadata-uri (string-utf8 200))
  )
  (let (
    (asset-id (+ (var-get asset-counter) u1))
    (game-info (unwrap! (map-get? registered-games game-id) ERR-GAME-NOT-REGISTERED))
  )
    (asserts! (is-eq tx-sender (get developer game-info)) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= rarity RARITY-COMMON) (<= rarity RARITY-MYTHIC)) ERR-INVALID-RARITY)
    
    ;; Create asset
    (map-set gaming-assets
      asset-id
      {
        owner: recipient,
        game-id: game-id,
        asset-type: asset-type,
        name: name,
        description: description,
        rarity: rarity,
        level: level,
        transferable: true,
        metadata-uri: metadata-uri,
        created-at: block-height,
        last-transfer: block-height
      }
    )
    
    ;; Initialize statistics
    (map-set asset-statistics
      asset-id
      {
        total-transfers: u0,
        total-sales: u0,
        highest-sale: u0,
        average-price: u0,
        current-owner-since: block-height
      }
    )
    
    ;; Update game stats
    (map-set registered-games
      game-id
      (merge game-info { total-assets: (+ (get total-assets game-info) u1) })
    )
    
    ;; Add to recipient's inventory
    (add-to-inventory recipient asset-id)
    
    ;; Record creation event
    (record-asset-event asset-id "mint" none recipient none game-id)
    
    (var-set asset-counter asset-id)
    (ok asset-id)
  )
)

(define-public (transfer-asset (asset-id uint) (recipient principal))
  (let (
    (asset-info (unwrap! (map-get? gaming-assets asset-id) ERR-ASSET-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get owner asset-info)) ERR-NOT-AUTHORIZED)
    (asserts! (get transferable asset-info) ERR-ASSET-NOT-TRANSFERABLE)
    
    ;; Update asset ownership
    (map-set gaming-assets
      asset-id
      (merge asset-info
        {
          owner: recipient,
          last-transfer: block-height
        }
      )
    )
    
    ;; Update statistics
    (let (
      (stats (unwrap-panic (map-get? asset-statistics asset-id)))
    )
      (map-set asset-statistics
        asset-id
        (merge stats
          {
            total-transfers: (+ (get total-transfers stats) u1),
            current-owner-since: block-height
          }
        )
      )
    )
    
    ;; Add to recipient's inventory
    (add-to-inventory recipient asset-id)
    
    ;; Record transfer event
    (record-asset-event asset-id "transfer" (some tx-sender) recipient none (get game-id asset-info))
    
    (ok asset-id)
  )
)

(define-public (list-asset-for-sale (asset-id uint) (price uint) (duration uint))
  (let (
    (asset-info (unwrap! (map-get? gaming-assets asset-id) ERR-ASSET-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get owner asset-info)) ERR-NOT-AUTHORIZED)
    (asserts! (> price u0) ERR-INVALID-PRICE)
    
    (map-set marketplace-listings
      asset-id
      {
        seller: tx-sender,
        price: price,
        listed-at: block-height,
        expires-at: (+ block-height duration),
        is-active: true
      }
    )
    
    (ok asset-id)
  )
)

(define-public (buy-asset (asset-id uint))
  (let (
    (asset-info (unwrap! (map-get? gaming-assets asset-id) ERR-ASSET-NOT-FOUND))
    (listing (unwrap! (map-get? marketplace-listings asset-id) ERR-ASSET-NOT-FOR-SALE))
    (price (get price listing))
    (marketplace-cut (calculate-marketplace-fee price))
    (seller-amount (- price marketplace-cut))
  )
    (asserts! (get is-active listing) ERR-ASSET-NOT-FOR-SALE)
    (asserts! (< block-height (get expires-at listing)) ERR-MARKETPLACE-CLOSED)
    
    ;; Transfer payment
    (try! (stx-transfer? seller-amount tx-sender (get seller listing)))
    (try! (stx-transfer? marketplace-cut tx-sender CONTRACT-OWNER))
    
    ;; Transfer ownership
    (map-set gaming-assets
      asset-id
      (merge asset-info
        {
          owner: tx-sender,
          last-transfer: block-height
        }
      )
    )
    
    ;; Update listing status
    (map-set marketplace-listings
      asset-id
      (merge listing { is-active: false })
    )
    
    ;; Update statistics
    (let (
      (stats (unwrap-panic (map-get? asset-statistics asset-id)))
      (new-avg (if (> (get total-sales stats) u0)
        (/ (+ (* (get average-price stats) (get total-sales stats)) price) (+ (get total-sales stats) u1))
        price
      ))
    )
      (map-set asset-statistics
        asset-id
        {
          total-transfers: (+ (get total-transfers stats) u1),
          total-sales: (+ (get total-sales stats) u1),
          highest-sale: (if (> price (get highest-sale stats)) price (get highest-sale stats)),
          average-price: new-avg,
          current-owner-since: block-height
        }
      )
    )
    
    ;; Add to buyer's inventory
    (add-to-inventory tx-sender asset-id)
    
    ;; Record sale event
    (record-asset-event asset-id "sale" (some (get seller listing)) tx-sender (some price) (get game-id asset-info))
    
    ;; Update global volume
    (var-set total-volume (+ (var-get total-volume) price))
    
    (ok asset-id)
  )
)

(define-public (cross-game-transfer (asset-id uint) (target-game-id uint))
  (let (
    (asset-info (unwrap! (map-get? gaming-assets asset-id) ERR-ASSET-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get owner asset-info)) ERR-NOT-AUTHORIZED)
    (asserts! (is-registered-game target-game-id) ERR-GAME-NOT-REGISTERED)
    (asserts! (get transferable asset-info) ERR-ASSET-NOT-TRANSFERABLE)
    
    ;; Update asset's game association
    (map-set gaming-assets
      asset-id
      (merge asset-info
        {
          game-id: target-game-id,
          last-transfer: block-height
        }
      )
    )
    
    ;; Record cross-game transfer event
    (record-asset-event asset-id "bridge" (some tx-sender) tx-sender none target-game-id)
    
    (ok asset-id)
  )
)

;; Read-only functions
(define-read-only (get-asset-details (asset-id uint))
  (map-get? gaming-assets asset-id)
)

(define-read-only (get-game-details (game-id uint))
  (map-get? registered-games game-id)
)

(define-read-only (get-marketplace-listing (asset-id uint))
  (map-get? marketplace-listings asset-id)
)

(define-read-only (get-player-inventory (player principal))
  (map-get? player-inventories player)
)

(define-read-only (get-asset-statistics (asset-id uint))
  (map-get? asset-statistics asset-id)
)

(define-read-only (get-asset-history (asset-id uint) (event-id uint))
  (map-get? asset-history { asset-id: asset-id, event-id: event-id })
)

(define-read-only (get-marketplace-stats)
  {
    total-assets: (var-get asset-counter),
    total-games: (var-get game-counter),
    total-volume: (var-get total-volume),
    marketplace-fee: (var-get marketplace-fee)
  }
)
