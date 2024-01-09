// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.22;

import {Ownable} from "../src/lib/Ownable.sol";
import {TriggerTestSetup} from "./utils/TriggerTestSetup.sol";

contract OwnableHarness is Ownable {
  constructor(address _owner) Ownable(_owner) {}
}

contract OwnableTestSetup is TriggerTestSetup {
  OwnableHarness ownable;

  address owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
  event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

  function setUp() public virtual override {
    owner = _randomAddress();
    ownable = new OwnableHarness(owner);
  }
}

contract OwnableConstructorTest is OwnableTestSetup {
  function test_OwnableConstructor() public {
    _expectEmit();
    emit OwnershipTransferred(address(0), owner);
    ownable = new OwnableHarness(owner);
    assertEq(ownable.owner(), owner);
  }
}

contract OwnableInitializedTest is OwnableTestSetup {
  function setUp() public override {
    super.setUp();
  }

  function test_TransferOwnership() public {
    address newOwner_ = _randomAddress();
    _expectEmit();
    emit OwnershipTransferStarted(owner, newOwner_);
    vm.prank(owner);
    ownable.transferOwnership(newOwner_);

    // Owner is not updated yet, but the pending owner is.
    assertEq(ownable.pendingOwner(), newOwner_);
    assertEq(ownable.owner(), owner);

    _expectEmit();
    emit OwnershipTransferred(owner, newOwner_);
    vm.prank(newOwner_);
    ownable.acceptOwnership();

    // Owner is updated, and the pending owner is reset.
    assertEq(ownable.pendingOwner(), address(0));
    assertEq(ownable.owner(), newOwner_);
  }

  function test_TransferOwnershipUnauthorized() public {
    address newOwner_ = _randomAddress();
    address caller_ = _randomAddress();

    vm.expectRevert(Ownable.Unauthorized.selector);
    vm.prank(caller_);
    ownable.transferOwnership(newOwner_);
  }

  function test_TransferOwnershipRevertsIfNewOwnerIsZeroAddress() public {
    vm.prank(owner);
    vm.expectRevert(Ownable.InvalidAddress.selector);
    ownable.transferOwnership(address(0));
  }

  function test_AcceptOwnershipUnauthorized() public {
    address newOwner_ = _randomAddress();
    address caller_ = _randomAddress();

    _expectEmit();
    emit OwnershipTransferStarted(owner, newOwner_);
    vm.prank(owner);
    ownable.transferOwnership(newOwner_);

    vm.expectRevert(Ownable.Unauthorized.selector);
    vm.prank(caller_);
    ownable.acceptOwnership();
  }
}
