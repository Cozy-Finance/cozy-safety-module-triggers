// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.22;

import {OwnableTrigger} from "./OwnableTrigger.sol";

contract OwnableTriggerFactory {
  /// @notice Deploys a new OwnableTrigger contract with the supplied owner and deploy salt.
  /// @param _owner The owner of the trigger.
  /// @param _salt Used during deployment to compute the address of the new OwnableTrigger.
  function deployTrigger(address _owner, bytes32 _salt) external returns (OwnableTrigger) {
    return new OwnableTrigger{salt: _salt}(_owner);
  }

  /// @notice Call this function to determine the address at which a trigger
  /// with the supplied configuration would be deployed. See `deployTrigger` for
  /// more information on parameters and their meaning.
  function computeTriggerAddress(address _owner, bytes32 _salt) public view returns (address _address) {
    // https://eips.ethereum.org/EIPS/eip-1014
    bytes32 _bytecodeHash = keccak256(bytes.concat(type(OwnableTrigger).creationCode, abi.encode(_owner)));
    bytes32 _data = keccak256(bytes.concat(bytes1(0xff), bytes20(address(this)), _salt, _bytecodeHash));
    _address = address(uint160(uint256(_data)));
  }
}
