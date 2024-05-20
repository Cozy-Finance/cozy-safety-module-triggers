// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {TriggerState} from "../structs/StateEnums.sol";

/**
 * @dev The minimal functions a trigger must implement to work with the Cozy Safety Module protocol.
 */
interface ITrigger {
  /// @dev Emitted when a trigger's state is updated.
  event TriggerStateUpdated(TriggerState indexed state);

  /// @notice The current trigger state.
  function state() external returns (TriggerState);
}
