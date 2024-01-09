// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

interface IOwnable {
  /// @notice Callable by the pending owner to transfer ownership to them.
  function acceptOwnership() external;

  /// @notice The current owner.
  function owner() external view returns (address);

  /// @notice Callable by the current owner to transfer ownership to a new account. The new owner must call
  /// acceptOwnership() to finalize the transfer.
  function transferOwnership(address newOwner_) external;
}
