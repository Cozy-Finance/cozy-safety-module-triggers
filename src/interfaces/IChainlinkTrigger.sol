// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {TriggerState} from "src/structs/StateEnums.sol";

/**
 * @notice A trigger contract that takes two addresses: a truth oracle and a tracking oracle.
 * This trigger ensures the two oracles always stay within the given price tolerance; the delta
 * in prices can be equal to but not greater than the price tolerance.
 */
interface IChainlinkTrigger {
  /// @dev Emitted when a trigger's state is updated.
  event TriggerStateUpdated(TriggerState indexed state);

  /// @notice The canonical oracle, assumed to be correct.
  function truthOracle() external view returns (AggregatorV3Interface);

  /// @notice The oracle we expect to diverge.
  function trackingOracle() external view returns (AggregatorV3Interface);

  /// @notice The current trigger state. This should never return PAUSED.
  function state() external returns (TriggerState);

  /// @notice The maximum percent delta between oracle prices that is allowed, expressed as a zoc.
  /// For example, a 0.2e4 priceTolerance would mean the trackingOracle price is
  /// allowed to deviate from the truthOracle price by up to +/- 20%, but no more.
  /// Note that if the truthOracle returns a price of 0, we treat the priceTolerance
  /// as having been exceeded, no matter what price the trackingOracle returns.
  function priceTolerance() external view returns (uint256);

  /// @notice The maximum amount of time we allow to elapse before the truth oracle's price is deemed stale.
  function truthFrequencyTolerance() external view returns (uint256);

  /// @notice The maximum amount of time we allow to elapse before the tracking oracle's price is deemed stale.
  function trackingFrequencyTolerance() external view returns (uint256);

  /// @notice Compares the oracle's price to the reference oracle and toggles the trigger if required.
  /// @dev This method executes the `programmaticCheck()` and makes the
  /// required state changes both in the trigger and the sets.
  function runProgrammaticCheck() external returns (TriggerState);
}
