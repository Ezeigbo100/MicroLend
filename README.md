MicroLend
=========

A decentralized micro-lending platform built on the Stacks blockchain, enabling secure and transparent peer-to-peer micro-lending with automated interest calculations, collateral management, and a robust loan lifecycle.

Table of Contents
-----------------

-   MicroLend

    -   Table of Contents

    -   Description

    -   Constants

    -   Data Structures

    -   Private Functions

    -   Public Functions

    -   Error Codes

    -   Usage

    -   Deployment

    -   Contributing

    -   License

Description
-----------

MicroLend is a smart contract designed to facilitate a decentralized micro-lending ecosystem. It allows users to:

-   **Deposit and Withdraw Funds:** Manage their STX tokens within the platform.

-   **Request Loans:** Borrow funds by providing collateral.

-   **Fund Loans:** Lenders can provide capital to pending loan requests.

-   **Repay Loans:** Borrowers can repay their loans, including calculated interest.

-   **Advanced Loan Management:** Handle partial repayments, loan extensions, and liquidation of defaulted loans.

The contract automates interest calculation based on a defined annual rate and manages collateral to secure loans, ensuring a transparent and trustless lending environment.

Constants
---------

| Constant | Value | Description | Category |
| :------- | :---- | :---------- | :------- |
| `contract-owner` | `tx-sender` | The principal address that deployed the contract. | **Access Control** |
| `err-owner-only` | `u100` | Error: Only the contract owner can perform this action. | **Error Codes** |
| `err-not-found` | `u101` | Error: The requested item (e.g., loan) was not found. | **Error Codes** |
| `err-unauthorized` | `u102` | Error: The transaction sender is not authorized for this action. | **Error Codes** |
| `err-insufficient-funds` | `u103` | Error: Insufficient funds for the requested operation. | **Error Codes** |
| `err-loan-active` | `u104` | Error: The loan is currently active and cannot be modified in this way. | **Error Codes** |
| `err-loan-not-active` | `u105` | Error: The loan is not active. | **Error Codes** |
| `err-invalid-amount` | `u106` | Error: The provided amount is invalid (e.g., zero or too low). | **Error Codes** |
| `err-loan-overdue` | `u107` | Error: The loan is overdue. | **Error Codes** |
| `err-already-exists` | `u108` | Error: The item already exists. | **Error Codes** |
| `annual-interest-rate` | `u1000` | Annual interest rate set at 10% (1000 basis points). | **Financial Parameters** |
| `basis-points` | `u10000` | Basis points constant for calculations (100% = 10000 basis points). | **Financial Parameters** |
| `blocks-per-year` | `u52560` | Approximate number of blocks in a year (used for interest calculation). | **Time and Blocks** |

Data Structures
---------------

### `loans` Map

Stores details for each loan.

```
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
        status: (string-ascii 20), ;; "pending", "active", "repaid", "defaulted"
        total-repaid: uint
    }
)

```

### `user-balances` Map

Tracks the internal STX balance for each user within the contract.

```
(define-map user-balances
    { user: principal }
    { balance: uint }
)

```

### `next-loan-id` Variable

A data variable that holds the next available unique ID for a new loan.

```
(define-data-var next-loan-id uint u1)

```

### `total-loans-issued` Variable

A data variable that tracks the total number of loans issued on the platform.

```
(define-data-var total-loans-issued uint u0)

```

### `total-volume` Variable

A data variable that tracks the cumulative volume of STX loaned out on the platform.

```
(define-data-var total-volume uint u0)

```

Private Functions
-----------------

These functions are internal helpers and cannot be called directly by users.

### `calculate-interest`

Calculates the interest owed on a loan based on the principal amount, annual rate, and the number of blocks elapsed.

```
(define-private (calculate-interest (principal-amount uint) (rate uint) (blocks-elapsed uint)))

```

### `is-valid-loan-request`

Validates the parameters for a new loan request, ensuring the amount and duration are positive and collateral meets the minimum requirement (at least 50% of the loan amount).

```
(define-private (is-valid-loan-request (amount uint) (duration uint) (collateral uint)))

```

### `get-balance`

Retrieves the internal balance of a given user, defaulting to `u0` if no balance is found.

```
(define-private (get-balance (user principal)))

```

### `set-balance`

Updates the internal balance of a specified user.

```
(define-private (set-balance (user principal) (new-balance uint)))

```

Public Functions
----------------

These functions can be called by any user interacting with the smart contract.

### `deposit`

Allows `tx-sender` to deposit a specified `amount` of STX tokens into their internal balance within the contract.

```
(define-public (deposit (amount uint)))

```

### `withdraw`

Allows `tx-sender` to withdraw a specified `amount` of STX tokens from their internal balance back to their wallet. Requires sufficient balance.

```
(define-public (withdraw (amount uint)))

```

### `request-loan`

Enables a `borrower` (`tx-sender`) to request a loan by specifying the `amount`, `duration-blocks`, and `collateral-amount`. The collateral is locked upon request. The loan status is initially "pending".

```
(define-public (request-loan (amount uint) (duration-blocks uint) (collateral-amount uint)))

```

### `fund-loan`

Allows a `lender` (`tx-sender`) to fund a "pending" loan identified by `loan-id`. Upon funding, the loan status changes to "active", the `start-block` is recorded, and platform statistics are updated.

```
(define-public (fund-loan (loan-id uint)))

```

### `repay-loan`

Allows the `borrower` (`tx-sender`) of an "active" loan to repay the full `amount` plus calculated interest. Upon successful repayment, the loan status changes to "repaid", and the collateral is returned to the borrower.

```
(define-public (repay-loan (loan-id uint)))

```

### `manage-loan-advanced`

Provides advanced functionalities for loan management:

-   **`"partial-repay"`**: Allows the borrower to make a partial payment towards an active loan.

-   **`"liquidate"`**: Allows the lender to liquidate an overdue and active loan, transferring the collateral to the lender as compensation.

-   **`"extend"`**: Allows the borrower to extend the loan duration by paying an extension fee (5% of the original loan amount).

```
(define-public (manage-loan-advanced (loan-id uint) (action (string-ascii 20)) (amount uint)))

```

Error Codes
-----------

The contract uses specific error codes to indicate the reason for a failed transaction:

-   `u100`: Owner-only function called by a non-owner.

-   `u101`: Loan or other data not found.

-   `u102`: Unauthorized access or action.

-   `u103`: Insufficient funds for the operation.

-   `u104`: Loan is already active.

-   `u105`: Loan is not active.

-   `u106`: Invalid amount provided.

-   `u107`: Loan is overdue.

-   `u108`: Item already exists.

Usage
-----

To interact with the MicroLend contract:

1.  **Deploy the contract** on the Stacks blockchain.

2.  **Deposit funds** using the `deposit` function to have STX available within the platform for lending or as collateral.

3.  **Borrowers:** Call `request-loan` with the desired amount, duration, and collateral. Ensure you have enough STX deposited for collateral.

4.  **Lenders:** Monitor pending loan requests. Call `fund-loan` with the `loan-id` of a pending loan you wish to fund. Ensure you have enough STX deposited to cover the loan amount.

5.  **Borrowers:** Once a loan is active, call `repay-loan` to pay back the principal plus interest.

6.  **Advanced Management:**

    -   Borrowers can use `manage-loan-advanced` with `"partial-repay"` to make partial payments or `"extend"` to extend the loan term (with a fee).

    -   Lenders can use `manage-loan-advanced` with `"liquidate"` to claim collateral for overdue loans.

Deployment
----------

This contract is written in Clarity and is designed to be deployed on the Stacks blockchain. You will need a Stacks development environment (e.g., Clarity Playground, `clarity-cli`, or a local Devnet) to compile and deploy this contract.

Contributing
------------

Contributions are welcome! If you have suggestions for improvements, bug fixes, or new features, please feel free to:

1.  Fork the repository.

2.  Create a new branch (`git checkout -b feature/your-feature-name`).

3.  Make your changes.

4.  Commit your changes (`git commit -m 'Add new feature'`).

5.  Push to the branch (`git push origin feature/your-feature-name`).

6.  Open a Pull Request.

License
-------

This project is licensed under the MIT License. See the `LICENSE` file for details.
