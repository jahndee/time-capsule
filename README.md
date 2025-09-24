# Time Capsule Smart Contract

A Stacks blockchain smart contract for creating digital time capsules with secure content storage and scheduled unlocking.

## Overview

The Time Capsule smart contract allows users to:
- Create digital time capsules with encrypted content
- Set future unlock times based on block height
- Assign beneficiaries who can access the content
- Extend unlock times for existing capsules
- Delete unopened capsules
- View capsule metadata

## Features

- **Secure Content Storage**: Store content hashes (SHA-256) or encrypted IPFS CIDs
- **Configurable Access**: Set specific block heights for unlocking content
- **Beneficiary System**: Optionally assign other principals who can access the content
- **Owner Controls**: Modify unlock times and delete unopened capsules
- **Event Tracking**: Comprehensive event system for all major operations

## Functions

### Public Functions

```clarity
(create-capsule (capsule-id uint) (content-hash (buff 64)) (unlock-block uint) (beneficiary (optional principal)))
(set-beneficiary (capsule-id uint) (new-beneficiary principal))
(extend-unlock (capsule-id uint) (new-unlock uint))
(open-capsule (capsule-id uint))
(delete-capsule (capsule-id uint))
(get-capsule (capsule-id uint))
```

### Error Codes

- `ERR-ALREADY-EXISTS (u100)`: Capsule ID already in use
- `ERR-INVALID-UNLOCK (u101)`: Invalid unlock block height
- `ERR-NOT-FOUND (u102)`: Capsule not found
- `ERR-NOT-AUTHORIZED (u103)`: Unauthorized access attempt
- `ERR-ALREADY-OPENED (u104)`: Capsule already opened
- `ERR-INVALID-UNLOCK-TIME (u105)`: Invalid unlock time extension
- `ERR-NO-CHANGE (u106)`: No change in operation
- `ERR-INVALID-HASH (u107)`: Invalid content hash format

## Security

- Input validation for all parameters
- Authorization checks for all operations
- Content hash length verification
- Unlock time validation against current block height
- Event logging for all state changes

## Usage Example

```clarity
;; Create a new time capsule
(contract-call? .time-capsule create-capsule 
    u1                                  ;; capsule-id
    0x1234...                          ;; content-hash (64 bytes)
    u100000                            ;; unlock-block
    (some 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)) ;; beneficiary
```

## Development Status

⚠️ **WARNING**: This contract is a prototype. Please audit before production use.
