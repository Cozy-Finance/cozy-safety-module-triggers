// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.22;

import {SafeTransferLib} from "./lib/SafeTransferLib.sol";
import {UMATrigger} from "./UMATrigger.sol";
import {TriggerMetadata} from "./structs/Triggers.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IUMATriggerFactory} from "./interfaces/IUMATriggerFactory.sol";
import {OptimisticOracleV2Interface} from "./interfaces/OptimisticOracleV2Interface.sol";

/**
 * @notice This is a utility contract to make it easy to deploy UMATriggers for
 * the Cozy Safety Module protocol.
 * @dev Be sure to approve the trigger to spend the rewardAmount before calling
 * `deployTrigger`, otherwise the latter will revert. Funds need to be available
 * to the created trigger within its constructor so that it can submit its query
 * to the UMA oracle.
 */
contract UMATriggerFactory {
  using SafeTransferLib for IERC20;

  /// @notice The UMA Optimistic Oracle.
  OptimisticOracleV2Interface public immutable oracle;

  /// @notice Maps the triggerConfigId to whether a trigger has been deployed with that config.
  mapping(bytes32 => bool) public exists;

  /// @dev Emitted when the factory deploys a trigger.
  /// @param trigger The address at which the trigger was deployed.
  /// @param triggerConfigId See the function of the same name in this contract.
  /// @param oracle The address of the UMA Optimistic Oracle.
  /// @param query The query that the trigger submitted to the UMA Optimistic Oracle.
  /// @param rewardToken The token used to pay the reward to users that successfully propose answers to the query.
  /// @param rewardAmount The amount of rewardToken that will be paid as a reward to anyone who successfully proposes an
  /// answer to the query.
  /// @param refundRecipient Default address that will recieve any leftover rewards at UMA query settlement time.
  /// @param bondAmount The amount of `rewardToken` that must be staked by a user wanting to propose or dispute an
  /// answer to the query.
  /// @param proposalDisputeWindow The window of time in seconds within which a proposed answer may be disputed.
  /// @param name The human-readble name of the trigger.
  /// @param description A human-readable description of the trigger.
  /// @param logoURI The URI of a logo image to represent the trigger.
  /// For other attributes, see the docs for the params of `deployTrigger` in
  /// this contract.
  /// @param extraData Extra metadata for the trigger.
  event TriggerDeployed(
    address trigger,
    bytes32 indexed triggerConfigId,
    address indexed oracle,
    string query,
    address indexed rewardToken,
    uint256 rewardAmount,
    address refundRecipient,
    uint256 bondAmount,
    uint256 proposalDisputeWindow,
    string name,
    string description,
    string logoURI,
    string extraData
  );

  /// @dev Thrown when the trigger address computed by the factory does not match deployed address.
  error TriggerAddressMismatch();

  /// @dev Thrown when the trigger has already been deployed with the given config.
  error AlreadyDeployed();

  constructor(OptimisticOracleV2Interface _oracle) {
    oracle = _oracle;
  }

  struct DeployTriggerVars {
    bytes32 configId;
    bytes32 salt;
    address triggerAddress;
    UMATrigger trigger;
  }

  /// @notice Call this function to deploy a UMATrigger.
  /// @param _query The query that the trigger will send to the UMA Optimistic
  /// Oracle for evaluation.
  /// @param _rewardToken The token used to pay the reward to users that propose
  /// answers to the query. The reward token must be approved by UMA governance.
  /// Approved tokens can be found with the UMA AddressWhitelist contract on each
  /// chain supported by UMA.
  /// @param _rewardAmount The amount of rewardToken that will be paid as a
  /// reward to anyone who proposes an answer to the query.
  /// @param _refundRecipient Default address that will recieve any leftover
  /// rewards at UMA query settlement time.
  /// @param _bondAmount The amount of `rewardToken` that must be staked by a
  /// user wanting to propose or dispute an answer to the query. See UMA's price
  /// dispute workflow for more information. It's recommended that the bond
  /// amount be a significant value to deter addresses from proposing malicious,
  /// false, or otherwise self-interested answers to the query.
  /// @param _proposalDisputeWindow The window of time in seconds within which a
  /// proposed answer may be disputed. See UMA's "customLiveness" setting for
  /// more information. It's recommended that the dispute window be fairly long
  /// (12-24 hours), given the difficulty of assessing expected queries (e.g.
  /// "Was protocol ABCD hacked") and the amount of funds potentially at stake.
  /// @param _metadata See TriggerMetadata for more info.
  function deployTrigger(
    string memory _query,
    IERC20 _rewardToken,
    uint256 _rewardAmount,
    address _refundRecipient,
    uint256 _bondAmount,
    uint256 _proposalDisputeWindow,
    TriggerMetadata memory _metadata
  ) external returns (UMATrigger) {
    // We need to do this because of stack-too-deep errors; there are too many
    // inputs/internal-vars to this function otherwise.
    DeployTriggerVars memory _vars;

    _vars.configId =
      triggerConfigId(_query, _rewardToken, _rewardAmount, _refundRecipient, _bondAmount, _proposalDisputeWindow);
    if (exists[_vars.configId]) revert AlreadyDeployed();

    exists[_vars.configId] = true;
    _vars.salt = _getSalt(_vars.configId, _rewardAmount);

    _vars.triggerAddress =
      computeTriggerAddress(_query, _rewardToken, _rewardAmount, _refundRecipient, _bondAmount, _proposalDisputeWindow);

    _rewardToken.safeTransferFrom(msg.sender, _vars.triggerAddress, _rewardAmount);

    _vars.trigger = new UMATrigger{salt: _vars.salt}(
      oracle, _query, _rewardToken, _refundRecipient, _bondAmount, _proposalDisputeWindow
    );

    if (address(_vars.trigger) != _vars.triggerAddress) revert TriggerAddressMismatch();

    emit TriggerDeployed(
      address(_vars.trigger),
      _vars.configId,
      address(oracle),
      _query,
      address(_rewardToken),
      _rewardAmount,
      _refundRecipient,
      _bondAmount,
      _proposalDisputeWindow,
      _metadata.name,
      _metadata.description,
      _metadata.logoURI,
      _metadata.extraData
    );

    return _vars.trigger;
  }

  /// @notice Call this function to determine the address at which a trigger
  /// with the supplied configuration would be deployed. See `deployTrigger` for
  /// more information on parameters and their meaning.
  function computeTriggerAddress(
    string memory _query,
    IERC20 _rewardToken,
    uint256 _rewardAmount,
    address _refundRecipient,
    uint256 _bondAmount,
    uint256 _proposalDisputeWindow
  ) public view returns (address _address) {
    bytes memory _triggerConstructorArgs =
      abi.encode(oracle, _query, _rewardToken, _refundRecipient, _bondAmount, _proposalDisputeWindow);

    // https://eips.ethereum.org/EIPS/eip-1014
    bytes32 _bytecodeHash = keccak256(bytes.concat(type(UMATrigger).creationCode, _triggerConstructorArgs));

    bytes32 _salt = _getSalt(
      triggerConfigId(_query, _rewardToken, _rewardAmount, _refundRecipient, _bondAmount, _proposalDisputeWindow),
      _rewardAmount
    );
    bytes32 _data = keccak256(bytes.concat(bytes1(0xff), bytes20(address(this)), _salt, _bytecodeHash));
    _address = address(uint160(uint256(_data)));
  }

  /// @notice Call this function to find triggers with the specified
  /// configurations that can be used for safety modules. See `deployTrigger` for more information on parameters
  /// and their meaning.
  function findAvailableTrigger(
    string memory _query,
    IERC20 _rewardToken,
    uint256 _rewardAmount,
    address _refundRecipient,
    uint256 _bondAmount,
    uint256 _proposalDisputeWindow
  ) public view returns (address) {
    bytes32 _configId =
      triggerConfigId(_query, _rewardToken, _rewardAmount, _refundRecipient, _bondAmount, _proposalDisputeWindow);
    return exists[_configId]
      ? computeTriggerAddress(_query, _rewardToken, _rewardAmount, _refundRecipient, _bondAmount, _proposalDisputeWindow)
      : address(0); // If none is found, return zero address.
  }

  /// @notice Call this function to determine the identifier of the supplied
  /// trigger configuration. This identifier is used both to track if there is an
  /// UMATrigger deployed with this configuration (see `exists`) and is
  /// emitted as a part of the TriggerDeployed event when triggers are deployed.
  /// @dev This function takes the rewardAmount as an input despite it not being
  /// an argument of the UMATrigger constructor nor it being held in storage by
  /// the trigger. This is done because the rewardAmount is something that
  /// deployers could reasonably differ on. Deployer A might deploy a trigger
  /// that is identical to what Deployer B wants in every way except the amount
  /// of rewardToken that is being offered, and it would still be reasonable for
  /// Deployer B to not want to re-use A's trigger for their own Safety Module.
  function triggerConfigId(
    string memory _query,
    IERC20 _rewardToken,
    uint256 _rewardAmount,
    address _refundRecipient,
    uint256 _bondAmount,
    uint256 _proposalDisputeWindow
  ) public view returns (bytes32) {
    bytes memory _triggerConfigData =
      abi.encode(oracle, _query, _rewardToken, _rewardAmount, _refundRecipient, _bondAmount, _proposalDisputeWindow);
    return keccak256(_triggerConfigData);
  }

  function _getSalt(bytes32 _triggerConfigId, uint256 _rewardAmount) private pure returns (bytes32) {
    // We use the reward amount in the salt so that triggers that are the same
    // except for their reward amount will still be deployed to different
    // addresses and can be differentiated. A trigger deployment with the same
    // _rewardAmount and _triggerCount should be the same across chains.
    return keccak256(bytes.concat(_triggerConfigId, bytes32(_rewardAmount)));
  }
}
