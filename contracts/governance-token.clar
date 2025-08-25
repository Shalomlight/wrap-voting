;; wrap-voting governance token contract
;; 
;; This contract manages a decentralized voting system with token-based governance.
;; It enables token holders to participate in proposal voting, delegation, and 
;; tracking of voting power across the ecosystem.

;; Error Codes
(define-constant err-unauthorized u1)
(define-constant err-insufficient-balance u2)
(define-constant err-already-voted u3)
(define-constant err-proposal-not-found u4)
(define-constant err-voting-closed u5)
(define-constant err-invalid-delegation u6)

;; Governance Token Configuration
(define-constant token-name "Wrap Governance Token")
(define-constant token-symbol "WRAP")
(define-constant token-decimals u6)

;; Data Maps
(define-map token-balances 
  { account: principal } 
  { balance: uint }
)

(define-map proposals
  { proposal-id: uint }
  { 
    title: (string-ascii 128),
    description: (string-ascii 256),
    proposer: principal,
    start-block: uint,
    end-block: uint,
    votes-for: uint,
    votes-against: uint,
    status: (string-ascii 32)
  }
)

(define-map votes
  { proposal-id: uint, voter: principal }
  { vote-weight: uint, vote-direction: bool }
)

(define-map delegations
  { delegator: principal }
  { delegate: principal, delegated-weight: uint }
)

;; Token State Variables
(define-data-var total-supply uint u0)
(define-data-var next-proposal-id uint u1)

;; Private Helper Functions
(define-private (get-balance (account principal))
  (default-to u0 (get balance (map-get? token-balances { account: account })))
)

(define-private (update-balance (account principal) (amount uint))
  (map-set token-balances 
    { account: account } 
    { balance: amount }
  )
)

;; Read-Only Functions
(define-read-only (get-token-balance (account principal))
  (ok (get-balance account))
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-proposal-details (proposal-id uint))
  (ok (map-get? proposals { proposal-id: proposal-id }))
)

;; Public Functions
(define-public (mint-tokens (recipient principal) (amount uint))
  (let ((current-balance (get-balance recipient)))
    (map-set token-balances
      { account: recipient }
      { balance: (+ current-balance amount) }
    )
    (var-set total-supply (+ (var-get total-supply) amount))
    (ok true)
  )
)

(define-public (create-proposal 
  (title (string-ascii 128)) 
  (description (string-ascii 256)) 
  (duration uint)
)
  (let 
    ((sender tx-sender)
     (proposal-id (var-get next-proposal-id))
     (start-block block-height)
     (end-block (+ start-block duration)))
    
    (var-set next-proposal-id (+ proposal-id u1))
    
    (map-set proposals 
      { proposal-id: proposal-id }
      { 
        title: title, 
        description: description,
        proposer: sender,
        start-block: start-block,
        end-block: end-block,
        votes-for: u0,
        votes-against: u0,
        status: "active"
      }
    )
    
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal 
  (proposal-id uint) 
  (vote-direction bool)
)
  (let 
    ((sender tx-sender)
     (voter-balance (get-balance sender))
     (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) (err err-proposal-not-found)))
     (existing-vote (map-get? votes { proposal-id: proposal-id, voter: sender })))
    
    ;; Check voting is still open
    (asserts! (< block-height (get end-block proposal)) (err err-voting-closed))
    
    ;; Prevent double voting
    (asserts! (is-none existing-vote) (err err-already-voted))
    
    ;; Record vote
    (map-set votes 
      { proposal-id: proposal-id, voter: sender }
      { vote-weight: voter-balance, vote-direction: vote-direction }
    )
    
    ;; Update proposal vote counts
    (if vote-direction 
      (map-set proposals 
        { proposal-id: proposal-id }
        (merge proposal { votes-for: (+ (get votes-for proposal) voter-balance) })
      )
      (map-set proposals 
        { proposal-id: proposal-id }
        (merge proposal { votes-against: (+ (get votes-against proposal) voter-balance) })
      )
    )
    
    (ok true)
  )
)

(define-public (delegate-voting-power (delegate principal))
  (let 
    ((sender tx-sender)
     (sender-balance (get-balance sender)))
    
    ;; Prevent self-delegation
    (asserts! (not (is-eq sender delegate)) (err err-invalid-delegation))
    
    (map-set delegations
      { delegator: sender }
      { delegate: delegate, delegated-weight: sender-balance }
    )
    
    (ok true)
  )
)