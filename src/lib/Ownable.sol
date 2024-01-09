// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.22;

import {IOwnable} from "src/interfaces/IOwnable.sol";

/**
 * @dev Contract module providing owner functionality, intended to be used through inheritance.
 * @dev No modifiers are provided to reduce bloat from unused code (even though this should be removed by the
 * compiler), as the child contract may have more complex authentication requirements than just a modifier from
 * this contract.
 */
abstract contract Ownable is IOwnable {
  /// @notice Contract owner.
  address public owner;

  /// @notice The pending new owner.
  address public pendingOwner;

  /// @dev Emitted when the owner address is updated.
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /// @dev Emitted when the first step of the two step ownership transfer is executed.
  event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

  /// @dev Thrown when the caller is not authorized to perform the action.
  error Unauthorized();

  /// @dev Thrown when an invalid address is passed as a parameter.
  error InvalidAddress();

  /// @param _owner The contract owner.
  constructor(address _owner) {
    emit OwnershipTransferred(owner, _owner);
    owner = _owner;
  }

  /// @notice Callable by the pending owner to transfer ownership to them.
  /// @dev Updates the owner in storage to pendingOwner and resets the pending owner.
  function acceptOwnership() external {
    if (msg.sender != pendingOwner) revert Unauthorized();
    delete pendingOwner;
    address _oldOwner = owner;
    owner = msg.sender;
    emit OwnershipTransferred(_oldOwner, msg.sender);
  }

  /// @notice Starts the ownership transfer of the contract to a new account.
  /// Replaces the pending transfer if there is one.
  /// @param _newOwner The new owner of the contract.
  function transferOwnership(address _newOwner) external onlyOwner {
    _assertAddressNotZero(_newOwner);
    pendingOwner = _newOwner;
    emit OwnershipTransferStarted(owner, _newOwner);
  }

  /// @dev Revert if the address is the zero address.
  function _assertAddressNotZero(address _address) internal pure {
    if (_address == address(0)) revert InvalidAddress();
  }

  modifier onlyOwner() {
    if (msg.sender != owner) revert Unauthorized();
    _;
  }
}
