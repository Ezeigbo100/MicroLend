;; Decentralized Micro-Lending Platform
;; A smart contract enabling peer-to-peer micro-lending with automated interest calculations,
;; collateral management, and secure loan lifecycle management

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-insufficient-funds (err u103))
(define-constant err-loan-active (err u104))
(define-constant err-loan-not-active (err u105))
(define-constant err-invalid-amount (err u106))
(define-constant err-loan-overdue (err u107))
(define-constant err-already-exists (err u108))

;; Interest rate: 10% annual (represented as 1000 basis points)
(define-constant annual-interest-rate u1000)
(define-constant basis-points u10000)
(define-constant blocks-per-year u52560) ;; Approximate blocks in a year

;; Data maps and vars
;; Loan structure containing all loan details
(define-map loans
    { loan-id: uint }
    {
        borrower: principal,
        lender: principal,
        amount: uint,
        interest-rate: uint,
        duration-blocks: uint,
        start-block: uint,
        collateral-amount: uint,
        status: (string-ascii 20), ;; "active", "repaid", "defaulted"
        total-repaid: uint
    }
)

;; User balances for internal accounting
(define-map user-balances
    { user: principal }
    { balance: uint }
)

;; Loan counter for unique loan IDs
(define-data-var next-loan-id uint u1)

;; Platform statistics
(define-data-var total-loans-issued uint u0)
(define-data-var total-volume uint u0)

;; Private functions
;; Calculate interest based on loan amount, rate, and time elapsed
(define-private (calculate-interest (principal-amount uint) (rate uint) (blocks-elapsed uint))
    (let
        (
            (annual-interest (/ (* principal-amount rate) basis-points))
            (block-interest (/ annual-interest blocks-per-year))
        )
        (* block-interest blocks-elapsed)
    )
)

;; Validate loan parameters
(define-private (is-valid-loan-request (amount uint) (duration uint) (collateral uint))
    (and
        (> amount u0)
        (> duration u0)
        (>= collateral (/ amount u2)) ;; Collateral must be at least 50% of loan amount
    )
)

;; Get user balance with default of 0
(define-private (get-balance (user principal))
    (default-to u0 (get balance (map-get? user-balances { user: user })))
)

;; Update user balance
(define-private (set-balance (user principal) (new-balance uint))
    (map-set user-balances { user: user } { balance: new-balance })
)

;; Public functions
;; Deposit funds to the platform
(define-public (deposit (amount uint))
    (let
        (
            (current-balance (get-balance tx-sender))
        )
        (begin
            (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
            (set-balance tx-sender (+ current-balance amount))
            (ok amount)
        )
    )
)

;; Withdraw funds from the platform
(define-public (withdraw (amount uint))
    (let
        (
            (current-balance (get-balance tx-sender))
        )
        (if (>= current-balance amount)
            (begin
                (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
                (set-balance tx-sender (- current-balance amount))
                (ok amount)
            )
            err-insufficient-funds
        )
    )
)

;; Request a loan
(define-public (request-loan (amount uint) (duration-blocks uint) (collateral-amount uint))
    (let
        (
            (loan-id (var-get next-loan-id))
            (borrower-balance (get-balance tx-sender))
        )
        (if (and 
                (is-valid-loan-request amount duration-blocks collateral-amount)
                (>= borrower-balance collateral-amount))
            (begin
                (map-set loans
                    { loan-id: loan-id }
                    {
                        borrower: tx-sender,
                        lender: contract-owner, ;; Placeholder until matched
                        amount: amount,
                        interest-rate: annual-interest-rate,
                        duration-blocks: duration-blocks,
                        start-block: u0,
                        collateral-amount: collateral-amount,
                        status: "pending",
                        total-repaid: u0
                    }
                )
                ;; Lock collateral
                (set-balance tx-sender (- borrower-balance collateral-amount))
                (var-set next-loan-id (+ loan-id u1))
                (ok loan-id)
            )
            err-invalid-amount
        )
    )
)

;; Fund a loan (lender provides funds)
(define-public (fund-loan (loan-id uint))
    (let
        (
            (loan-data (unwrap! (map-get? loans { loan-id: loan-id }) err-not-found))
            (lender-balance (get-balance tx-sender))
        )
        (if (and 
                (is-eq (get status loan-data) "pending")
                (>= lender-balance (get amount loan-data)))
            (begin
                ;; Transfer funds to borrower
                (set-balance tx-sender (- lender-balance (get amount loan-data)))
                (set-balance (get borrower loan-data) 
                    (+ (get-balance (get borrower loan-data)) (get amount loan-data)))
                ;; Update loan status
                (map-set loans
                    { loan-id: loan-id }
                    (merge loan-data {
                        lender: tx-sender,
                        status: "active",
                        start-block: block-height
                    })
                )
                ;; Update platform statistics
                (var-set total-loans-issued (+ (var-get total-loans-issued) u1))
                (var-set total-volume (+ (var-get total-volume) (get amount loan-data)))
                (ok true)
            )
            err-insufficient-funds
        )
    )
)

;; Repay loan with interest
(define-public (repay-loan (loan-id uint))
    (let
        (
            (loan-data (unwrap! (map-get? loans { loan-id: loan-id }) err-not-found))
            (blocks-elapsed (- block-height (get start-block loan-data)))
            (interest-owed (calculate-interest (get amount loan-data) (get interest-rate loan-data) blocks-elapsed))
            (total-owed (+ (get amount loan-data) interest-owed))
            (borrower-balance (get-balance tx-sender))
        )
        (if (and 
                (is-eq tx-sender (get borrower loan-data))
                (is-eq (get status loan-data) "active")
                (>= borrower-balance total-owed))
            (begin
                ;; Transfer repayment to lender
                (set-balance tx-sender (- borrower-balance total-owed))
                (set-balance (get lender loan-data) 
                    (+ (get-balance (get lender loan-data)) total-owed))
                ;; Return collateral to borrower
                (set-balance tx-sender 
                    (+ (get-balance tx-sender) (get collateral-amount loan-data)))
                ;; Update loan status
                (map-set loans
                    { loan-id: loan-id }
                    (merge loan-data {
                        status: "repaid",
                        total-repaid: total-owed
                    })
                )
                (ok total-owed)
            )
            err-insufficient-funds
        )
    )
)


