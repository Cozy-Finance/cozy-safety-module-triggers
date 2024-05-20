// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IOwnableTrigger} from "./IOwnableTrigger.sol";
import {TriggerMetadata} from "../structs/Triggers.sol";

interface IOwnableTriggerFactory {
  function deployTrigger(address _owner, TriggerMetadata memory _metadata, bytes32 _salt)
    external
    returns (IOwnableTrigger _trigger);

  function computeTriggerAddress(address _owner, bytes32 _salt) external view returns (address _address);
}
