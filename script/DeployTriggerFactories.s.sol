// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "uma-protocol/packages/core/contracts/data-verification-mechanism/interfaces/FinderInterface.sol";
import {console2} from "forge-std/console2.sol";
import {stdJson} from "forge-std/Script.sol";
import {ChainlinkTriggerFactory} from "../src/ChainlinkTriggerFactory.sol";
import {OwnableTriggerFactory} from "../src/OwnableTriggerFactory.sol";
import {UMATriggerFactory} from "../src/UMATriggerFactory.sol";
import {OptimisticOracleV2Interface} from "../src/interfaces/OptimisticOracleV2Interface.sol";
import {ScriptUtils} from "./ScriptUtils.sol";

/**
 * @notice Purpose: Local deploy, testing, and production.
 *
 * This script deploys Cozy Safety Module trigger factories.
 * Before executing, the input json file `script/input/<chain-id>/deploy-trigger-factories-<test or production>.json`
 * should be reviewed.
 *
 * To run this script:
 *
 * ```sh
 * # Start anvil, forking from the current state of the desired chain.
 * anvil --fork-url $OPTIMISM_RPC_URL
 *
 * # In a separate terminal, perform a dry run the script.
 * forge script script/DeployTriggerFactories.s.sol \
 *   --sig "run(string)" "deploy-trigger-factories-<test or production>" \
 *   --rpc-url "http://127.0.0.1:8545" \
 *   -vvvv
 *
 * # Or, to broadcast transactions with etherscan verification.
 * forge script script/DeployTriggerFactories.s.sol \
 *   --sig "run(string)" "deploy-trigger-factories-<test or production>" \
 *   --rpc-url "http://127.0.0.1:8545" \
 *   --private-key $OWNER_PRIVATE_KEY \
 *   --etherscan-api-key $ETHERSCAN_KEY \
 *   --verify \
 *   --broadcast \
 *   -vvvv
 * ```
 */
contract DeployTriggerFactories is ScriptUtils {
  using stdJson for string;

  // -----------------------------------
  // -------- Configured Inputs --------
  // -----------------------------------

  // -------- UMA Trigger Factory --------

  // The UMA oracle finder on Optimism
  // https://github.com/UMAprotocol/protocol/blob/f011a6531fbd7c09d22aa46ef04828cf98f7f854/packages/core/networks/10.json
  FinderInterface umaOracleFinder;

  // ---------------------------
  // -------- Execution --------
  // ---------------------------

  function run(string memory _fileName) public {
    // -------- Read Inputs --------

    string memory _json = readInput(_fileName);

    umaOracleFinder = FinderInterface(_json.readAddress(".umaOracleFinder"));

    OptimisticOracleV2Interface _umaOracle =
      OptimisticOracleV2Interface(umaOracleFinder.getImplementationAddress(bytes32("OptimisticOracleV2")));

    // -------- Deploy Factories --------

    console2.log("Deploying ChainlinkTriggerFactory...");
    vm.broadcast();
    address factory = address(new ChainlinkTriggerFactory());
    console2.log("ChainlinkTriggerFactory deployed", factory);

    console2.log("====================");

    console2.log("Deploying OwnableTriggerFactory...");
    vm.broadcast();
    factory = address(new OwnableTriggerFactory());
    console2.log("OwnableTriggerFactory deployed", factory);

    console2.log("====================");

    console2.log("Deploying UMATriggerFactory...");
    console2.log("    umaOracle", address(_umaOracle));
    vm.broadcast();
    factory = address(new UMATriggerFactory(_umaOracle));
    console2.log("UMATriggerFactory deployed", factory);

    console2.log("====================");
  }
}
