// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC6909Claims} from "./interfaces/external/IERC6909Claims.sol";

/// @notice Minimalist and gas efficient standard ERC6909 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC6909.sol)
/// @dev Copied from the commit at 4b47a19038b798b4a33d9749d25e570443520647
/// @dev This contract has been modified from the implementation at the above link.
abstract contract ERC6909 is IERC6909Claims {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event OperatorSet(address indexed owner, address indexed operator, bool approved);

    event Approval(address indexed owner, address indexed spender, uint256 indexed id, uint256 amount);

    event Transfer(address caller, address indexed from, address indexed to, uint256 indexed id, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                             ERC6909 STORAGE SLOTS
    //////////////////////////////////////////////////////////////*/

    uint8 private constant BALANCES_SLOT = 0x10; // bytes1(bytes32(keccak256("BalanceSlot")))
    uint8 private constant ALLOWANCES_SLOT = 0x07; // bytes1(bytes32(keccak256("AllowanceSlot")))
    uint8 private constant OPERATORS_SLOT = 0xc2; // bytes1(bytes32(keccak256("OperatorsSlot")))

    /*//////////////////////////////////////////////////////////////
                              ERC6909 GETTERS
    //////////////////////////////////////////////////////////////*/

    function isOperator(address owner, address spender) public view returns (bool approved) {
        bytes32 _slot = _getOperatorSlot(owner, spender);
        /// @solidity memory-safe-assembly
        assembly {
            approved := sload(_slot)
        }
    }

    function balanceOf(address owner, uint256 id) public view returns (uint256 balanceValue) {
        bytes32 balanceSlot = _getBalanceSlot(owner, id);
        /// @solidity memory-safe-assembly
        assembly {
            balanceValue := sload(balanceSlot)
        }
    }

    function allowance(address owner, address spender, uint256 id) public view returns (uint256 allowanceValue) {
        bytes32 allowanceSlot = _getAllowanceSlot(owner, spender, id);
        /// @solidity memory-safe-assembly
        assembly {
            allowanceValue := sload(allowanceSlot)
        }
    }

    /*//////////////////////////////////////////////////////////////
                              ERC6909 LOGIC
    //////////////////////////////////////////////////////////////*/

    function transfer(address receiver, uint256 id, uint256 amount) public virtual returns (bool) {
        _decreaseBalanceOf(msg.sender, id, amount);
        _increaseBalanceOf(receiver, id, amount);

        emit Transfer(msg.sender, msg.sender, receiver, id, amount);

        return true;
    }

    function transferFrom(address sender, address receiver, uint256 id, uint256 amount) public virtual returns (bool) {
        if (msg.sender != sender && !isOperator(sender, msg.sender)) {
            uint256 allowed = allowance(sender, msg.sender, id);
            if (allowed != type(uint256).max) _setAllowance(sender, msg.sender, id, allowed - amount);
        }

        _decreaseBalanceOf(sender, id, amount);
        _increaseBalanceOf(receiver, id, amount);

        emit Transfer(msg.sender, sender, receiver, id, amount);

        return true;
    }

    function approve(address spender, uint256 id, uint256 amount) public virtual returns (bool) {
        _setAllowance(msg.sender, spender, id, amount);

        emit Approval(msg.sender, spender, id, amount);

        return true;
    }

    function setOperator(address operator, bool approved) public virtual returns (bool) {
        bytes32 _slot = _getOperatorSlot(msg.sender, operator);
        /// @solidity memory-safe-assembly
        assembly {
            sstore(_slot, approved)
        }

        emit OperatorSet(msg.sender, operator, approved);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC165 Interface ID for ERC165
            || interfaceId == 0x0f632fb3; // ERC165 Interface ID for ERC6909
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address receiver, uint256 id, uint256 amount) internal virtual {
        _increaseBalanceOf(receiver, id, amount);

        emit Transfer(msg.sender, address(0), receiver, id, amount);
    }

    function _burn(address sender, uint256 id, uint256 amount) internal virtual {
        _decreaseBalanceOf(sender, id, amount);

        emit Transfer(msg.sender, sender, address(0), id, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL STORAGE LOGIC
    //////////////////////////////////////////////////////////////*/
    function _setAllowance(address owner, address spender, uint256 id, uint256 value) internal {
        bytes32 allowanceSlot = _getAllowanceSlot(owner, spender, id);
        /// @solidity memory-safe-assembly
        assembly {
            sstore(allowanceSlot, value)
        }
    }

    function _decreaseBalanceOf(address owner, uint256 id, uint256 value) internal {
        bytes32 balanceSlot = _getBalanceSlot(owner, id);
        uint256 balanceOfValue;
        /// @solidity memory-safe-assembly
        assembly {
            balanceOfValue := sload(balanceSlot)
        }

        balanceOfValue -= value;

        /// @solidity memory-safe-assembly
        assembly {
            sstore(balanceSlot, balanceOfValue)
        }
    }

    function _increaseBalanceOf(address owner, uint256 id, uint256 value) internal {
        bytes32 balanceSlot = _getBalanceSlot(owner, id);
        uint256 balanceOfValue;
        /// @solidity memory-safe-assembly
        assembly {
            balanceOfValue := sload(balanceSlot)
        }

        balanceOfValue += value;

        /// @solidity memory-safe-assembly
        assembly {
            sstore(balanceSlot, balanceOfValue)
        }
    }

    function _getOperatorSlot(address owner, address spender) internal pure returns (bytes32 operatorSlot) {
        // operatorSlot = keccak256(abi.encodePacked(owner, OPERATORS_SLOT, spender))
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x14, spender) // [0x20, 0x34)
            mstore(0x00, or(shl(8, owner), OPERATORS_SLOT)) // [0x0b, 0x20)
            operatorSlot := keccak256(0x0b, 0x29)
        }
    }

    function _getBalanceSlot(address owner, uint256 id) internal pure returns (bytes32 balanceSlot) {
        // balanceSlot = keccak256(abi.encodePacked(owner, BALANCES_SLOT, id))
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x20, id)
            mstore(0x00, or(shl(8, owner), BALANCES_SLOT))
            balanceSlot := keccak256(0x0b, 0x35)
        }
    }

    function _getAllowanceSlot(address owner, address spender, uint256 id)
        internal
        pure
        returns (bytes32 allowanceSlot)
    {
        // allowanceSlot = keccak256(abi.encodePacked(owner, ALLOWANCES_SLOT, spender, id))
        /// @solidity memory-safe-assembly
        assembly {
            let pointer := mload(0x40)
            mstore(0x34, id) // [0x34, 0x54)
            mstore(0x14, spender) // [0x20, 0x34)
            mstore(0x00, or(shl(8, owner), ALLOWANCES_SLOT)) // [0x0b, 0x20)

            allowanceSlot := keccak256(0x0b, 0x49)

            mstore(0x40, pointer)
        }
    }
}
