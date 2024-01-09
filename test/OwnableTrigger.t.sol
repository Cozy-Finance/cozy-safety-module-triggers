// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.22;

import {OwnableTrigger} from "../src/OwnableTrigger.sol";
import {OwnableTriggerFactory} from "../src/OwnableTriggerFactory.sol";
import {Ownable} from "../src/lib/Ownable.sol";
import {TriggerState} from "../src/structs/StateEnums.sol";
import {TriggerTestSetup} from "./utils/TriggerTestSetup.sol";

contract OwnableTriggerTest is TriggerTestSetup {
  OwnableTriggerFactory factory = new OwnableTriggerFactory();

  address owner = address(0xBEEF);

  function testFuzz_deployOwnableTriggerWithFactory(address _owner, bytes32 _salt) public {
    vm.assume(_owner != address(0));
    address _computedAddress = factory.computeTriggerAddress(_owner, _salt);
    OwnableTrigger trigger = factory.deployTrigger(_owner, _salt);
    assertEq(trigger.owner(), _owner);
    assertEq(_computedAddress, address(trigger));
  }

  function test_deployOwnableTrigger_revertsOnZeroAddress() public {
    vm.expectRevert(Ownable.InvalidAddress.selector);
    new OwnableTrigger(address(0));
  }

  function test_triggerOwnableTrigger() public {
    OwnableTrigger trigger = new OwnableTrigger(owner);
    assertEq(trigger.state(), TriggerState.ACTIVE);

    vm.prank(owner);
    trigger.trigger();
    assertEq(trigger.state(), TriggerState.TRIGGERED);
  }

  function test_triggerOwnableTriggerUnauthorized() public {
    OwnableTrigger trigger = new OwnableTrigger(owner);
    assertEq(trigger.state(), TriggerState.ACTIVE);

    vm.expectRevert(Ownable.Unauthorized.selector);
    trigger.trigger();
    assertEq(trigger.state(), TriggerState.ACTIVE);
  }

  function test_transferOwnership() public {
    OwnableTrigger trigger = new OwnableTrigger(owner);
    assertEq(trigger.owner(), owner);

    address _newOwner = _randomAddress();

    vm.prank(owner);
    trigger.transferOwnership(_newOwner);
    assertEq(trigger.owner(), owner);
    assertEq(trigger.pendingOwner(), _newOwner);

    vm.prank(_newOwner);
    trigger.acceptOwnership();
    assertEq(trigger.owner(), _newOwner);
    assertEq(trigger.pendingOwner(), address(0));
  }

  function test_transferOwnershipUnauthorized() public {
    OwnableTrigger trigger = new OwnableTrigger(owner);
    assertEq(trigger.owner(), owner);

    address _newOwner = _randomAddress();

    vm.expectRevert(Ownable.Unauthorized.selector);
    trigger.transferOwnership(_newOwner);

    vm.prank(owner);
    trigger.transferOwnership(_newOwner);
    assertEq(trigger.owner(), owner);
    assertEq(trigger.pendingOwner(), _newOwner);

    vm.expectRevert(Ownable.Unauthorized.selector);
    trigger.acceptOwnership();

    vm.prank(_newOwner);
    trigger.acceptOwnership();
    assertEq(trigger.owner(), _newOwner);
    assertEq(trigger.pendingOwner(), address(0));
  }
}
