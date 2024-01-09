// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.22;

import {OwnableTrigger} from "../src/OwnableTrigger.sol";
import {OwnableTriggerFactory} from "../src/OwnableTriggerFactory.sol";
import {Ownable} from "../src/lib/Ownable.sol";
import {TriggerState} from "../src/structs/StateEnums.sol";
import {TriggerTestSetup} from "./utils/TriggerTestSetup.sol";

contract OwnableTriggerTest is TriggerTestSetup {
  OwnableTriggerFactory factory = new OwnableTriggerFactory();

  function testFuzz_deployOwnableTriggerWithFactory(address _owner, bytes32 _salt) public {
    address _computedAddress = factory.computeTriggerAddress(_owner, _salt);
    OwnableTrigger trigger = factory.deployTrigger(_owner, _salt);
    assertEq(trigger.owner(), _owner);
    assertEq(_computedAddress, address(trigger));
  }

  function test_triggerOwnableTrigger() public {
    address _owner = _randomAddress();
    OwnableTrigger trigger = new OwnableTrigger(_owner);
    assertEq(trigger.state(), TriggerState.ACTIVE);

    vm.prank(_owner);
    trigger.runProgrammaticCheck();
    assertEq(trigger.state(), TriggerState.TRIGGERED);
  }

  function test_triggerOwnableTriggerUnauthorized() public {
    address _owner = _randomAddress();
    OwnableTrigger trigger = new OwnableTrigger(_owner);
    assertEq(trigger.state(), TriggerState.ACTIVE);

    vm.expectRevert(Ownable.Unauthorized.selector);
    trigger.runProgrammaticCheck();
    assertEq(trigger.state(), TriggerState.ACTIVE);
  }

  function test_transferOwnership() public {
    address _owner = _randomAddress();
    OwnableTrigger trigger = new OwnableTrigger(_owner);
    assertEq(trigger.owner(), _owner);

    address _newOwner = _randomAddress();

    vm.prank(_owner);
    trigger.transferOwnership(_newOwner);
    assertEq(trigger.owner(), _owner);
    assertEq(trigger.pendingOwner(), _newOwner);

    vm.prank(_newOwner);
    trigger.acceptOwnership();
    assertEq(trigger.owner(), _newOwner);
    assertEq(trigger.pendingOwner(), address(0));
  }

  function test_transferOwnershipUnauthorized() public {
    address _owner = _randomAddress();
    OwnableTrigger trigger = new OwnableTrigger(_owner);
    assertEq(trigger.owner(), _owner);

    address _newOwner = _randomAddress();

    vm.expectRevert(Ownable.Unauthorized.selector);
    trigger.transferOwnership(_newOwner);

    vm.prank(_owner);
    trigger.transferOwnership(_newOwner);
    assertEq(trigger.owner(), _owner);
    assertEq(trigger.pendingOwner(), _newOwner);

    vm.expectRevert(Ownable.Unauthorized.selector);
    trigger.acceptOwnership();

    vm.prank(_newOwner);
    trigger.acceptOwnership();
    assertEq(trigger.owner(), _newOwner);
    assertEq(trigger.pendingOwner(), address(0));
  }
}
