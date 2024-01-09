// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.22;

import {BaseTrigger} from "../../src/abstract/BaseTrigger.sol";
import {TriggerState} from "../../src/structs/StateEnums.sol";

contract MinimalTrigger is BaseTrigger {
  constructor() BaseTrigger() {
    state = TriggerState.ACTIVE;
  }

  function TEST_HOOK_updateTriggerState(TriggerState _newState) public {
    _updateTriggerState(_newState);
  }

  function TEST_HOOK_isValidTriggerStateTransition(TriggerState _oldState, TriggerState _newState)
    public
    returns (bool)
  {
    return _isValidTriggerStateTransition(_oldState, _newState);
  }
}
