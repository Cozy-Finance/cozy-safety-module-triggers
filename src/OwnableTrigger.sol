// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.22;

import {BaseTrigger} from "./abstract/BaseTrigger.sol";
import {Ownable} from "./lib/Ownable.sol";
import {TriggerState} from "./structs/StateEnums.sol";

contract OwnableTrigger is BaseTrigger, Ownable {
  /// @param _owner The address of the owner of the trigger, which is allowed to call `trigger()`.
  constructor(address _owner) Ownable(_owner) {
    _assertAddressNotZero(_owner);
  }

  /// @notice Callable by the owner to transition the state of the trigger to triggered.
  function trigger() external onlyOwner {
    _updateTriggerState(TriggerState.TRIGGERED);
  }
}
