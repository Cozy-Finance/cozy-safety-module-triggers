// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.22;

import {BaseTrigger} from "./abstract/BaseTrigger.sol";
import {Ownable} from "./lib/Ownable.sol";
import {TriggerState} from "./structs/StateEnums.sol";

contract OwnableTrigger is BaseTrigger, Ownable {
  constructor(address _owner) Ownable(_owner) {}

  /// @notice Callable by the owner to transition the state of the trigger to triggered.
  function runProgrammaticCheck() external onlyOwner {
    _updateTriggerState(TriggerState.TRIGGERED);
  }
}
