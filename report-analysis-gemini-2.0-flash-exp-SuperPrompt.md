# Smart Contract Security Analysis Report

## About

This contract implements a vault system with two contracts: `VaultLogic` and `Vault`. The `VaultLogic` contract handles ownership changes, while `Vault` manages deposits and withdrawals. The `Vault` contract uses delegatecall to interact with `VaultLogic`, making `Vault` a proxy contract. Funds are deposited by users into the `Vault` and can be withdrawn by users, only if `canWithdraw` is set to true by the contract owner.

## Findings Severity breakdown
- Critical: 1
- High: 2
- Medium: 2
- Low: 3
- Gas: 2

---

### Delegatecall Vulnerability
- **Title:** Delegatecall Vulnerability
- **Severity:** Critical
- **Description:** The `Vault` contract uses `delegatecall` to execute code from `VaultLogic`. This means the logic in `VaultLogic` is executed in the context of the `Vault` contract. Any state variable manipulation within `VaultLogic` affects `Vault`'s storage, potentially leading to unintended consequences and manipulation of the Vault's state. The `VaultLogic` contract has the owner (slot 0) and password (slot 1) storage variables. These variables are overriden from slot 0 and 1 of the Vault contract. This includes the `owner` field of `Vault` contract
- **Impact:** An attacker can call `changeOwner` with the correct password, and change the owner in the `Vault` contract (because the storage of the owner is in slot 0). After this, the attacker can set the `canWithdraw` variable to true and can withdraw all the balance of the contract, effectively stealing the deposited funds.
- **Location:** Vault.sol:18, VaultLogic.sol:7
- **Recommendation:** Avoid using `delegatecall` with untrusted code. For code reuse, prefer inheritance. If `delegatecall` is necessary, ensure that the target contract does not modify state variables of the calling contract. Consider using a proper proxy pattern (e.g., EIP-1967) that isolates the implementation storage from the proxy storage or implement a delegatecall with restricted access.

---

### Unprotected Initialization
- **Title:** Unprotected Initialization
- **Severity:** High
- **Description:** The `Vault` constructor takes the `_logicAddress` as parameter. There is no check if the address is actually a `VaultLogic` contract and no check to prevent the contract owner from being set to an arbitrary address during deployment, potentially causing a Denial of Service.
- **Impact:** An attacker can deploy an arbitrary contract at the provided address and use the malicious contract to control the `Vault` contract due to the `delegatecall`. This can lead to unauthorized access and loss of funds if `delegatecall` uses a malicious contract.
- **Location:** Vault.sol:11
- **Recommendation:** Validate the provided logic address against code size using `extcodesize` in the constructor and ensure its a contract address.

---

### Missing Access Control in `openWithdraw` Function
- **Title:** Missing Access Control in `openWithdraw` Function
- **Severity:** High
- **Description:** The `openWithdraw` function allows the contract owner to set `canWithdraw` to `true`. However, the `owner` variable can be changed using the `delegatecall` vulnerability. If the attacker gains control over `Vault.owner` by exploiting the `delegatecall`, they can then call `openWithdraw` and then `withdraw` to steal all the funds from the vault.
- **Impact:** An attacker who has successfully changed the `Vault.owner` through the `delegatecall` vulnerability can set `canWithdraw` to `true` and can withdraw all funds.
- **Location:** Vault.sol:32
- **Recommendation:** Ensure that the `owner` variable is only modifiable by the constructor using proper proxy patterns or immutable.

---

### Insecure Withdrawal Logic
- **Title:** Insecure Withdrawal Logic
- **Severity:** Medium
- **Description:** The `withdraw` function does not check if the `msg.sender` has a balance before performing the transfer. It only checks if the balance is greater or equal than 0. This can cause an issue if the `deposites[msg.sender]` is set to 0, then `msg.sender.call{ value: 0 }` will be executed without a revert, with potential security or gas issues. Also, the code uses `call` to send funds, which does not revert on failure.
- **Impact:** Gas can be wasted if the user calls withdraw with a deposit of 0. Also, the withdraw function will not revert if the `call` fails and the deposit will be set to 0, losing the funds.
- **Location:** Vault.sol:38
- **Recommendation:** Check if the deposit is greater than zero before attempting to withdraw, revert the `call` if the transfer fails and add a check to prevent sending funds to the contract itself. Use `transfer()` to send funds instead of `call` to automatically revert on failure. Also, use `require` instead of `if(result)` to enforce the expected behavior.

---

### Lack of Input Validation in `deposite` Function
- **Title:** Lack of Input Validation in `deposite` Function
- **Severity:** Medium
- **Description:** The `deposite` function does not have any validation checks on the `msg.value`. An attacker can deposit a very small amount of wei to cause overflow issues with large values in future deposits and/or to potentially DOS the contract, as well as make gas calculations higher, which can cause the transaction to fail and create griefing issues.
- **Impact:** Could potentially cause arithmetic overflow issues with large amounts.
- **Location:** Vault.sol:27
- **Recommendation:** Implement a minimum deposit amount or a maximum deposit check and use SafeMath or solidity version 0.8.0 that implement overflow protection.

---
###  Missing `extcodesize` check in constructor of `Vault`
-   **Title:** Missing `extcodesize` check in constructor
-   **Severity:** Low
-   **Description:** The `Vault` contract's constructor does not check if the provided address of the `VaultLogic` is a contract or an EOA.
-   **Impact:** Sending an EOA address will cause the delegatecall to fail and the contract would be bricked.
-   **Location:** Vault.sol:11
-   **Recommendation:** Implement an `extcodesize` check in the constructor to verify that `_logicAddress` is a contract.

---
### Unnecessary `this` Statement
- **Title:** Unnecessary `this` Statement
- **Severity:** Low
- **Description:** The `this` statement after the delegatecall is unecessary.
- **Impact:** Unnecessary code.
- **Location:** Vault.sol:19
- **Recommendation:** Remove the unnecessary `this` statement after the delegatecall.

---
### Unused `isSolve()` function
- **Title:** Unused `isSolve()` function
- **Severity:** Low
- **Description:** The function `isSolve()` is not used within the contract and it does not have any practical use.
- **Impact:** Unnecessary code.
- **Location:** Vault.sol:30
- **Recommendation:** Remove the unused `isSolve` function or add it as part of the contract's logic.

---
### Unnecessary contract redeploy
- **Title:** Unnecessary contract redeploy
- **Severity:** Gas
- **Description:** Every time a `Vault` contract is created it will deploy another contract `VaultLogic`, increasing deployment gas costs.
- **Impact:** More deployment gas.
- **Location:** Vault.sol:11
- **Recommendation:** Deploy one `VaultLogic` contract once and provide that address to the `Vault` contract when deploying new `Vault` contracts.

---
### Gas Optimization: Check `canWithdraw` before `deposites[msg.sender]`
- **Title:** Gas Optimization: Check `canWithdraw` before `deposites[msg.sender]`
- **Severity:** Gas
- **Description:** In the `withdraw` function, the check for `canWithdraw` should be performed before accessing the mapping `deposites`. This will save gas in cases where `canWithdraw` is `false` since the mapping lookup will be avoided.
- **Impact:** Minor gas savings.
- **Location:** Vault.sol:38
- **Recommendation:** Reorder the checks in the `withdraw` function to check `canWithdraw` first.

## Detailed Analysis

### Architecture:
The contract consists of two contracts: `VaultLogic` and `Vault`. The `VaultLogic` contract contains the logic for owner change using a password and is meant to be used as a library using delegatecall. The `Vault` contract serves as the main interface for user interaction. It stores deposits, manages withdrawals, and delegates function calls to `VaultLogic` using `delegatecall`. This pattern creates a proxy-like architecture.

### Code Quality:
The code lacks proper access control checks and input validation, contributing to vulnerabilities. There is a lack of comments explaining the purpose of each function. The code is not optimized for gas efficiency.

### Centralization Risks:
The contract owner has privileged control over setting the `canWithdraw` variable, which dictates when users can withdraw their funds. However, the `owner` is vulnerable to change through the delegatecall. This centralization point can be a risk if the owner account is compromised and could lead to a complete loss of funds if not handled properly.

### Systemic Risks:
The use of `delegatecall` introduces systemic risks as it allows for execution of arbitrary code within the context of the `Vault` contract. This depends on an external address which increases the risks related to third party dependencies.

### Testing & Verification:
To effectively test this contract, one should consider the following test cases:

-   Correct deployment of the contract with a proper logic contract address.
-   Correct deposits and balance tracking.
-   Withdrawal attempts with `canWithdraw` set to `false` should revert.
-   Withdrawal attempts by users with no balance should not transfer any ether and should not fail.
-   Successful change of the owner by providing the correct password.
-   Unsuccessful change of the owner with a wrong password
-   Successful change of the owner using a malicious contract and then using that to open the withdraw, and then withdraw the funds.
-   Attempting to delegatecall using a non-contract address should fail.
-   Attempting to deposit with a very small amount of Wei.
-   Attempting to withdraw a very small amount of Wei

## Final Recommendations

1.  **Replace `delegatecall` with a standard proxy pattern (e.g., EIP-1967)** to prevent state manipulation vulnerabilities and to ensure the correct separation between the logic and proxy storage.
2.  **Validate the `_logicAddress`** in the constructor of `Vault` to verify it's a contract using `extcodesize` and use a factory pattern or deploy `VaultLogic` once.
3.  **Implement proper access control:** Ensure only the owner, set during contract creation, can call privileged functions (e.g., `openWithdraw`) and prevent the owner from being changed by `delegatecall`. Consider immutable variables for owner and logic address.
4.  **Add input validation:** Implement checks for minimum deposit amounts in the `deposite` function to prevent very small amounts from being used, which could cause DOS in the long run.
5.  **Enhance withdrawal logic:** Ensure the withdraw function reverts on failure when sending funds, use `transfer()` instead of `call`, check that the user's deposit is greater than zero before calling the transfer, and add a check to prevent sending funds to the contract itself. Use require instead of `if(result)`
6.  **Improve gas efficiency:** Reorder the `canWithdraw` check in the `withdraw` function and remove unused functions.
7.  **Add proper documentation and comments:** Explain the purpose of each function and variable, especially when handling critical operations.
8.  **Implement proper testing:** Test all edge cases with proper test frameworks, like Foundry.

## Improved Code with Security Comments

```solidity
// File: Contract.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Contract for handling logic
contract VaultLogic {
    address public owner; // slot 0, immutable after constructor
    bytes32 private password; // slot 1

    constructor(bytes32 _password)  {
        owner = msg.sender;
        password = _password;
    }

    // Function to change the owner. This is vulnerable when using delegatecall
    // This function is only used to show the delegatecall vulnerability
    function changeOwner(bytes32 _password, address newOwner) public {
        if (password == _password) {
            owner = newOwner;
        } else {
            revert("password error");
        }
    }
}

// Main vault contract
contract Vault {
    // Define immutable state variables
    address public immutable owner;  // slot 0, immutable, set at constructor
    VaultLogic public immutable logic; // slot 1, immutable, set at constructor

    mapping(address => uint256) public deposites; // slot 2
    bool public canWithdraw = false; // slot 3

    // Minimum deposit amount to prevent DOS and issues when using very small deposits
    uint256 public minDepositAmount = 1 wei;

    // Constructor to initialize the vault with the address of the logic contract
    constructor(address _logicAddress)  {
        // Ensure that the _logicAddress is a contract address and not an EOA.
        require(_logicAddress != address(0), "Logic address cannot be 0");
        require(getCodeSize(_logicAddress) > 0, "Logic address must be a contract");
        logic = VaultLogic(_logicAddress); // set the immutable logic address
        owner = msg.sender; // set the immutable owner
    }

    // Delegatecall to the logic contract
    // The fallback function is only needed to show the delegatecall vulnerability
    fallback() external {
         (bool result,) = address(logic).delegatecall(msg.data);
           // Delegate call will revert if it fails
         require(result, "Delegatecall failed");
    }

    // Receive function to handle ether deposits to the contract
    receive() external payable { }

    // Function to deposit ether into the vault
    function deposite() public payable {
        // Ensure that the msg.value is greater than the minimum deposit amount
        require(msg.value >= minDepositAmount, "Deposit amount is less than minimum deposit amount");
        deposites[msg.sender] += msg.value;
    }

    // Function to open withdraw by the contract owner
    function openWithdraw() public {
        // Checks if the caller is the owner and reverts if not
        require(msg.sender == owner, "not owner");
        canWithdraw = true;
    }

    // Function to withdraw funds
    function withdraw() public {
        // Checks if withdrawal is allowed.
        // Checks `canWithdraw` before accessing deposites mapping for gas optimization
        require(canWithdraw, "Withdrawals are not open yet.");
        require(deposites[msg.sender] > 0, "No funds to withdraw.");
        // Transfer the user's deposit to the user's address
        (bool result,) = msg.sender.call{value: deposites[msg.sender]}("");
        require(result, "Transfer failed"); // Revert if transfer fails

        // Set the deposit to zero after a successful transfer
        deposites[msg.sender] = 0;
    }

    function getCodeSize(address _addr) public view returns (uint) {
        uint size;
        assembly {
            size := extcodesize(_addr)
        }
        return size;
    }
}
```
