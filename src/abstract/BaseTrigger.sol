// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.22;

import {ITrigger} from "../interfaces/ITrigger.sol";
import {TriggerState} from "../structs/StateEnums.sol";

/**
 * @dev Core trigger interface and implementation. All triggers should inherit from this to ensure they conform
 * to the required trigger interface.
 */
abstract contract BaseTrigger is ITrigger {
  /// @notice Current trigger state.
  TriggerState public state;

  /// @dev Thrown when a state update results in an invalid state transition.
  error InvalidStateTransition();

  /// @dev Thrown when the caller is not authorized to perform the action.
  error Unauthorized();

  /// @dev Child contracts should use this function to handle Trigger state transitions.
  function _updateTriggerState(TriggerState _newState) internal returns (TriggerState) {
    if (!_isValidTriggerStateTransition(state, _newState)) revert InvalidStateTransition();
    state = _newState;
    emit TriggerStateUpdated(_newState);
    return _newState;
  }

  /// @dev Reimplement this function if different state transitions are needed.
  function _isValidTriggerStateTransition(TriggerState _oldState, TriggerState _newState)
    internal
    virtual
    returns (bool)
  {
    // | From / To | ACTIVE      | FROZEN      | PAUSED   | TRIGGERED |
    // | --------- | ----------- | ----------- | -------- | --------- |
    // | ACTIVE    | -           | true        | false    | true      |
    // | FROZEN    | true        | -           | false    | true      |
    // | PAUSED    | false       | false       | -        | false     | <-- PAUSED is a safety module-level state
    // | TRIGGERED | false       | false       | false    | -         | <-- TRIGGERED is a terminal state

    if (_oldState == TriggerState.TRIGGERED) return false;
    // If oldState == newState, return true since the safety module will convert that into a no-op.
    if (_oldState == _newState) return true;
    if (_oldState == TriggerState.ACTIVE && _newState == TriggerState.FROZEN) return true;
    if (_oldState == TriggerState.FROZEN && _newState == TriggerState.ACTIVE) return true;
    if (_oldState == TriggerState.ACTIVE && _newState == TriggerState.TRIGGERED) return true;
    if (_oldState == TriggerState.FROZEN && _newState == TriggerState.TRIGGERED) return true;
    return false;
  }
}
