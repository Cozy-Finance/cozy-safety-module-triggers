// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.22;

import {Test, stdStorage, StdStorage} from "forge-std/Test.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {BaseTrigger} from "../../src/abstract/BaseTrigger.sol";
import {IERC20} from "../../src/interfaces/IERC20.sol";
import {ITrigger} from "../../src/interfaces/ITrigger.sol";
import {TriggerState} from "../../src/structs/StateEnums.sol";

contract TriggerTestSetup is Test {
  using stdStorage for StdStorage;

  bytes32 constant salt = bytes32(uint256(1234)); // Arbitrary default salt value.

  address localOwner;
  address localPauser;
  IERC20 asset;

  /// @dev Emitted when a trigger's state is updated.
  event TriggerStateUpdated(TriggerState indexed state);

  function setUp() public virtual {
    // Create addresses.
    asset = IERC20(makeAddr("asset"));
    localOwner = makeAddr("localOwner");
    localPauser = makeAddr("localPauser");
  }

  // -----------------------------------
  // -------- Cheatcode Helpers --------
  // -----------------------------------

  // Helper methods.
  function updateTriggerState(ITrigger _trigger, TriggerState _val) public {
    stdstore.target(address(_trigger)).sig("state()").checked_write(uint256(_val));
    assertEq(_trigger.state(), _val);
  }

  function _expectEmit() internal {
    vm.expectEmit(true, true, true, true);
  }

  // ---------------------------------------
  // -------- Additional Assertions --------
  // ---------------------------------------

  function assertEq(AggregatorV3Interface a, AggregatorV3Interface b) internal {
    assertEq(address(a), address(b));
  }

  function assertEq(TriggerState a, TriggerState b) internal {
    if (a != b) {
      emit log("Error: a == b not satisfied [TriggerState]");
      emit log_named_uint("  Expected", uint256(b));
      emit log_named_uint("    Actual", uint256(a));
      fail();
    }
  }

  function assertNotEq(ITrigger a, ITrigger b) internal {
    if (a == b) {
      emit log("Error: a != b not satisfied [ITrigger]");
      emit log_named_address("    Both values", address(a));
      fail();
    }
  }

  function assertNotEq(AggregatorV3Interface a, AggregatorV3Interface b) internal {
    if (a == b) {
      emit log("Error: a != b not satisfied [AggregatorV3Interface]");
      emit log_named_address("    Both values", address(a));
      fail();
    }
  }

  // -----------------------------------
  // -------- Randomizer Functions --------
  // -----------------------------------

  function _randomBytes32() internal view returns (bytes32) {
    return keccak256(
      abi.encode(block.timestamp, blockhash(0), gasleft(), tx.origin, keccak256(msg.data), address(this).codehash)
    );
  }

  function _randomAddress() internal view returns (address payable) {
    return payable(address(uint160(_randomUint256())));
  }

  function _randomUint256() internal view returns (uint256) {
    return uint256(_randomBytes32());
  }
}
