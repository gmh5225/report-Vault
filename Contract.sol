

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VaultLogic {
    address public owner; // slot 0
    bytes32 private password; // slot 1

    constructor(bytes32 _password) public {
        owner = msg.sender;
        password = _password;
    }

    function changeOwner(bytes32 _password, address newOwner) public {
        if (password == _password) {
            owner = newOwner;
        } else {
            revert("password error");
        }
    }
}

contract Vault {
    address public owner; // slot 0
    VaultLogic logic; // slot 1
    mapping(address => uint256) deposites; // slot 2
    bool public canWithdraw = false; // slot 3

    constructor(address _logicAddress) public {
        logic = VaultLogic(_logicAddress);
        owner = msg.sender;
    }

    fallback() external {
        (bool result,) = address(logic).delegatecall(msg.data);
        if (result) {
            this;
        }
    }

    receive() external payable { }

    function deposite() public payable {
        deposites[msg.sender] += msg.value;
    }

    function isSolve() external view returns (bool) {
        if (address(this).balance == 0) {
            return true;
        }
    }

    function openWithdraw() external {
        if (owner == msg.sender) {
            canWithdraw = true;
        } else {
            revert("not owner");
        }
    }

    function withdraw() public {
        if (canWithdraw && deposites[msg.sender] >= 0) {
            (bool result,) = msg.sender.call{ value: deposites[msg.sender] }("");
            if (result) {
                deposites[msg.sender] = 0;
            }
        }
    }
}
