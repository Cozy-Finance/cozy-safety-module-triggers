// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.22;

import {OwnableTrigger} from "./OwnableTrigger.sol";
import {TriggerMetadata} from "./structs/Triggers.sol";

contract OwnableTriggerFactory {
  /// @dev Emitted when the factory deploys a trigger.
  /// @param trigger The address at which the trigger was deployed.
  /// @param owner The owner of the trigger.
  /// @param name The human-readble name of the trigger.
  /// @param description A human-readable description of the trigger.
  /// @param logoURI The URI of a logo image to represent the trigger.
  /// For other attributes, see the docs for the params of `deployTrigger` in
  /// this contract.
  /// @param extraData Extra metadata for the trigger.
  event TriggerDeployed(
    address trigger, address indexed owner, string name, string description, string logoURI, string extraData
  );

  /// @notice Deploys a new OwnableTrigger contract with the supplied owner and deploy salt.
  /// @param _owner The owner of the trigger.
  /// @param _metadata The metadata of the trigger.
  /// @param _salt Used during deployment to compute the address of the new OwnableTrigger.
  function deployTrigger(address _owner, TriggerMetadata memory _metadata, bytes32 _salt)
    external
    returns (OwnableTrigger _trigger)
  {
    _trigger = new OwnableTrigger{salt: _salt}(_owner);
    emit TriggerDeployed(
      address(_trigger), _owner, _metadata.name, _metadata.description, _metadata.logoURI, _metadata.extraData
    );
  }

  /// @notice Call this function to determine the address at which a trigger
  /// with the supplied configuration would be deployed. See `deployTrigger` for
  /// more information on parameters and their meaning.
  function computeTriggerAddress(address _owner, bytes32 _salt) external view returns (address _address) {
    // https://eips.ethereum.org/EIPS/eip-1014
    bytes32 _bytecodeHash = keccak256(bytes.concat(type(OwnableTrigger).creationCode, abi.encode(_owner)));
    bytes32 _data = keccak256(bytes.concat(bytes1(0xff), bytes20(address(this)), _salt, _bytecodeHash));
    _address = address(uint160(uint256(_data)));
  }
}
