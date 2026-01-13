### 1. Standard Payment Flow (Updated)

This diagram now shows how the backend handles both the server-to-server notification and the user's browser redirect from the same `vpc_ReturnURL`.

```mermaid
sequenceDiagram
    participant Client
    participant MerchantServer as Merchant Server
    participant Onepay
    participant FrontendApp as Frontend App

    Client->>MerchantServer: Initiate Payment
    MerchantServer->>Onepay: Redirect user with payment parameters (vpc_ReturnURL -> backend)

    Onepay->>Client: Show payment page
    Client->>Onepay: Enter payment details and submit

    alt Server-to-Server IPN (in background)
        Onepay-->>MerchantServer: POST to vpc_ReturnURL (IPN)
        MerchantServer-->>MerchantServer: Verify hash, update order status
        MerchantServer-->>Onepay: Respond with plain text 'confirm-success'
    end

    alt User Browser Redirect
        Onepay->>Client: Redirect browser to vpc_ReturnURL
        Client->>MerchantServer: GET from browser to vpc_ReturnURL
        MerchantServer->>MerchantServer: Verify hash, update order status (idempotently)
        MerchantServer->>Client: Redirect browser to Frontend Confirmation Page
    end
    
    Client->>FrontendApp: Load Confirmation Page (e.g., /checkout/confirmation?order_number=...)
    FrontendApp->>MerchantServer: API Call: GET /api/orders/{order_number}
    MerchantServer->>FrontendApp: Return verified order status (e.g., 'paid')
    FrontendApp->>Client: Display "Payment Successful"
```

### 2. Payment with Token Creation (Updated)

The callback and confirmation flow is the same, following the new, more detailed pattern.

```mermaid
sequenceDiagram
    participant Client
    participant MerchantServer as Merchant Server
    participant Onepay
    participant FrontendApp as Frontend App

    Client->>MerchantServer: Initiate Payment and Request to Save Card
    MerchantServer->>MerchantServer: Prepare payment data, including `vpc_CreateToken: 'true'`
    MerchantServer->>Onepay: Redirect user with payment parameters (vpc_ReturnURL -> backend)

    Onepay->>Client: Show payment page
    Client->>Onepay: Enter payment details and submit
    Onepay->>Onepay: Store card details and generate token

    alt Server-to-Server IPN (in background)
        Onepay-->>MerchantServer: POST to vpc_ReturnURL with token details
        MerchantServer-->>MerchantServer: Verify hash, store token, update order status
        MerchantServer-->>Onepay: Respond with plain text 'confirm-success'
    end

    alt User Browser Redirect
        Onepay->>Client: Redirect browser to vpc_ReturnURL
        Client->>MerchantServer: GET from browser to vpc_ReturnURL
        MerchantServer->>MerchantServer: Verify hash, update order status (idempotently)
        MerchantServer->>Client: Redirect browser to Frontend Confirmation Page
    end
    
    Client->>FrontendApp: Load Confirmation Page
    FrontendApp->>MerchantServer: API Call: GET /api/orders/{order_number}
    MerchantServer->>FrontendApp: Return verified order status
    FrontendApp->>Client: Display "Payment Successful"
```

### 3. Installment Payment (Updated)

This flow also now correctly shows the final confirmation process. This example covers both installment selection methods (at Onepay or at the merchant site), as the confirmation flow is identical.

```mermaid
sequenceDiagram
    participant Client
    participant MerchantServer as Merchant Server
    participant Onepay
    participant FrontendApp as Frontend App

    Client->>MerchantServer: Initiate Installment Payment
    MerchantServer->>Onepay: Redirect user with installment parameters (vpc_ReturnURL -> backend)

    Onepay->>Client: Show payment page (with or without pre-selected plan)
    Client->>Onepay: Confirm payment

    alt Server-to-Server IPN (in background)
        Onepay-->>MerchantServer: POST to vpc_ReturnURL (IPN)
        MerchantServer-->>MerchantServer: Verify hash, update order status and installment info
        MerchantServer-->>Onepay: Respond with plain text 'confirm-success'
    end

    alt User Browser Redirect
        Onepay->>Client: Redirect browser to vpc_ReturnURL
        Client->>MerchantServer: GET from browser to vpc_ReturnURL
        MerchantServer->>MerchantServer: Verify hash, update order status (idempotently)
        MerchantServer->>Client: Redirect browser to Frontend Confirmation Page
    end
    
    Client->>FrontendApp: Load Confirmation Page
    FrontendApp->>MerchantServer: API Call: GET /api/orders/{order_number}
    MerchantServer->>FrontendApp: Return verified order status
    FrontendApp->>Client: Display "Payment Successful"
```

### 4. Query Transaction (QueryDR)

This flow allows the merchant to check the status of a transaction.

```mermaid
sequenceDiagram
    participant MerchantServer as Merchant Server
    participant Onepay

    MerchantServer->>MerchantServer: Prepare QueryDR request data (`vpc_Command: 'queryDR'`, `vpc_MerchTxnRef`)
    MerchantServer->>MerchantServer: Sort parameters and create string to hash
    MerchantServer->>MerchantServer: Generate vpc_SecureHash
    MerchantServer->>Onepay: API Call: Send QueryDR request
    Onepay->>Onepay: Retrieve transaction status
    Onepay->>MerchantServer: Return transaction details
    MerchantServer->>MerchantServer: Verify vpc_SecureHash of the response
    MerchantServer->>MerchantServer: Process the transaction status (e.g., update order in database)
```

### 5. Verify Secure Hash

This is a critical step that happens whenever the merchant server receives a response from Onepay. It ensures the data has not been tampered with.

```mermaid
graph TD
    A[Receive response from Onepay with parameters and vpc_SecureHash] --> B{Extract vpc_SecureHash from response};
    A --> C{Remove vpc_SecureHash from parameters};
    C --> D{Sort the remaining parameters alphabetically};
    D --> E{Create a string by joining the key-value pairs with '&'};
    E --> F{Generate a new secure hash using your secret HASH_CODE and the created string};
    F --> G{Compare the generated hash with the vpc_SecureHash from the response};
    G --> H{Hashes Match?};
    H -- Yes --> I[Process is valid];
    H -- No --> J[Process is invalid, reject transaction];
```