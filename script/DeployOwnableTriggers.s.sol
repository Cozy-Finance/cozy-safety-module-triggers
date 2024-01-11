// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {console2} from "forge-std/console2.sol";
import {stdJson} from "forge-std/Script.sol";
import {ScriptUtils} from "./ScriptUtils.sol";
import {OwnableTriggerFactory} from "../src/OwnableTriggerFactory.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {TriggerMetadata} from "../src/structs/Triggers.sol";

/**
 * @notice Purpose: Local deploy, testing, and production.
 *
 * This script deploys Ownable triggers for testing using an OwnableTriggerFactory.
 * Before executing, the input json file `script/input/<chain-id>/deploy-ownable-triggers-<test or production>.json`
 * should be reviewed.
 *
 * To run this script:
 *
 * ```sh
 * # Start anvil, forking from the current state of the desired chain.
 * anvil --fork-url $OPTIMISM_RPC_URL
 *
 * # In a separate terminal, perform a dry run the script.
 * forge script script/DeployOwnableTriggers.s.sol \
 *   --sig "run(string)" "deploy-ownable-triggers-<test or production>" \
 *   --rpc-url "http://127.0.0.1:8545" \
 *   -vvvv
 *
 * # Or, to broadcast transactions with etherscan verification.
 * forge script script/DeployOwnableTriggers.s.sol \
 *   --sig "run(string)" "deploy-ownable-triggers-<test or production>" \
 *   --rpc-url "http://127.0.0.1:8545" \
 *   --private-key $OWNER_PRIVATE_KEY \
 *   --etherscan-api-key $ETHERSCAN_KEY \
 *   --verify \
 *   --broadcast \
 *   -vvvv
 * ```
 */
contract DeployOwnableTriggers is ScriptUtils {
  using stdJson for string;

  // -----------------------------------
  // -------- Configured Inputs --------
  // -----------------------------------

  // Note: The attributes in this struct must be in alphabetical order due to `parseJson` limitations.
  struct OwnableTriggerMetadata {
    // The category of the trigger.
    string category;
    // A human-readable description of the intent of the trigger, as it should appear within the Cozy user interface.
    string description;
    // Logo uri that describes the trigger, as it should appear within the Cozy user interface.
    string logoURI;
    // The name of the trigger, as it should appear within the Cozy user interface.
    string name;
    // The owner of the trigger.
    address owner;
    // Arbitrary salt used for Trigger contract deploy. If using the same owner for multiple triggers, this should be
    // unique for each.
    bytes32 salt;
  }

  OwnableTriggerFactory factory;

  // ---------------------------
  // -------- Execution --------
  // ---------------------------

  function run(string memory _fileName) public {
    string memory _json = readInput(_fileName);

    factory = OwnableTriggerFactory(_json.readAddress(".ownableTriggerFactory"));

    OwnableTriggerMetadata[] memory _metadata = abi.decode(_json.parseRaw(".metadata"), (OwnableTriggerMetadata[]));

    for (uint256 i = 0; i < _metadata.length; i++) {
      _deployTrigger(_metadata[i]);
    }
  }

  function _deployTrigger(OwnableTriggerMetadata memory _metadata) internal {
    console2.log("Deploying OwnableTrigger...");
    console2.log("    ownableTriggerFactory", address(factory));
    console2.log("    triggerName", _metadata.name);
    console2.log("    triggerCategory", _metadata.category);
    console2.log("    triggerDescription", _metadata.description);
    console2.log("    triggerLogoURI", _metadata.logoURI);
    console2.log("    owner", _metadata.owner);

    require(_metadata.owner != address(0), "DeployOwnableTriggers: owner cannot be zero address");

    vm.broadcast();
    address _trigger = address(
      factory.deployTrigger(
        _metadata.owner,
        TriggerMetadata(_metadata.name, _metadata.category, _metadata.description, _metadata.logoURI),
        _metadata.salt
      )
    );
    console2.log("OwnableTrigger deployed", _trigger);

    console2.log("========");
  }
}
