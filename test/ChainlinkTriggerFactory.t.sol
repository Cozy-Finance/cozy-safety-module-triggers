// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.22;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {ChainlinkTriggerFactory} from "../src/ChainlinkTriggerFactory.sol";
import {FixedPriceAggregator} from "../src/FixedPriceAggregator.sol";
import {IChainlinkTrigger} from "../src/interfaces/IChainlinkTrigger.sol";
import {TriggerState} from "../src/structs/StateEnums.sol";
import {TriggerMetadata} from "../src/structs/Triggers.sol";
import {TriggerTestSetup} from "./utils/TriggerTestSetup.sol";
import {MockChainlinkOracle} from "./utils/MockChainlinkOracle.sol";

contract ChainlinkTriggerFactoryTestBaseSetup is TriggerTestSetup {
  uint256 constant ZOC = 1e4;

  address constant ethUsdOracleMainnet = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; //   ETH / USD on mainnet
  address constant stEthUsdOracleMainnet = 0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8; // stETH / USD on mainnet
  address constant usdcUsdOracleMainnet = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6; //  USDC / USD on mainnet
  address constant bnbEthOracleMainnet = 0xc546d2d06144F9DD42815b8bA46Ee7B8FcAFa4a2; //   BNB / ETH on mainnet

  address constant ethUsdOracleOptimism = 0x13e3Ee699D1909E989722E753853AE30b17e08c5; //   ETH / USD on Optimism
  address constant stEthUsdOracleOptimism = 0x41878779a388585509657CE5Fb95a80050502186; // stETH / USD on Optimism
  address constant usdcUsdOracleOptimism = 0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3; //  USDC / USD on Optimism
  address constant linkEthOracleOptimism = 0x464A1515ADc20de946f8d0DEB99cead8CEAE310d; //  LINK / ETH on Optimism

  ChainlinkTriggerFactory factory;

  event TriggerDeployed(
    address trigger,
    bytes32 indexed triggerConfigId,
    address indexed truthOracle,
    address indexed trackingOracle,
    uint256 priceTolerance,
    uint256 truthFrequencyTolerance,
    uint256 trackingFrequencyTolerance,
    string name,
    string description,
    string logoURI,
    string extraData
  );

  function setUp() public virtual override {
    super.setUp();
    factory = new ChainlinkTriggerFactory();
    vm.makePersistent(address(factory));
  }
}

contract ChainlinkTriggerFactoryTestSetup is ChainlinkTriggerFactoryTestBaseSetup {
  function setUp() public override {
    super.setUp();

    // This is needed b/c we check that the oracle pair's decimals match during deploy.
    vm.etch(ethUsdOracleMainnet, address(new FixedPriceAggregator(8, 1e8)).code);
    vm.etch(stEthUsdOracleMainnet, address(new FixedPriceAggregator(8, 1e8)).code);
    vm.etch(usdcUsdOracleMainnet, address(new FixedPriceAggregator(8, 1e8)).code);
  }
}

contract DeployTriggerForkTest is ChainlinkTriggerFactoryTestBaseSetup {
  uint256 mainnetForkId_;
  uint256 optimismForkId_;

  function setUp() public override {
    super.setUp();

    uint256 mainnetForkBlock = 15_181_633; // The mainnet block number at the time this test was written.
    uint256 optimismForkBlock = 25_582_446; // The optimism block number
    mainnetForkId_ = vm.createFork(vm.envString("MAINNET_RPC_URL"), mainnetForkBlock);
    optimismForkId_ = vm.createFork(vm.envString("OPTIMISM_RPC_URL"), optimismForkBlock);
  }

  function testFork_DeployTriggerRevertsWithMismatchedOracles(
    uint256 forkId_,
    address truthOracle_,
    address trackingOracle_
  ) internal {
    vm.selectFork(forkId_);

    assertNotEq(AggregatorV3Interface(truthOracle_).decimals(), AggregatorV3Interface(trackingOracle_).decimals());

    vm.expectRevert(ChainlinkTriggerFactory.InvalidOraclePair.selector);

    factory.deployTrigger(
      AggregatorV3Interface(truthOracle_),
      AggregatorV3Interface(trackingOracle_),
      0.1e4, // priceTolerance.
      45, // truthFrequencyTolerance.
      45, // trackingFrequencyTolerance
      TriggerMetadata(
        "Peg Protection Trigger",
        "A trigger that protects from something depegging",
        "https://via.placeholder.com/150",
        "$category: Peg"
      )
    );
  }

  function testFork_DeployTriggerChainlinkIntegration(
    uint256 forkId_,
    address truthOracle_,
    address trackingOracle_,
    int256 pegPrice_,
    uint8 pegDecimals_
  ) internal {
    vm.selectFork(forkId_);

    // While running this test, none of the prices of the used feed pairs differ by over 0.6e4.
    // We want to ensure that the trigger isn't deployed and updated to the triggered state in
    // the trigger constructor.
    uint256 priceTolerance_ = 0.6e4;

    // This value is fairly arbitrary. We set it to 24 hours, which should be longer than the
    // "heartbeat" for all feeds used in this test. New price data is written when the off-chain
    // price moves more than the feed's deviation threshold, or if the heartbeat duration elapses
    // without other updates. We set the tracking oracle to 1 hour longer to ensure they don't match for testing.
    uint256 truthFrequencyTolerance_ = 24 hours;
    uint256 trackingFrequencyTolerance_ = 25 hours;

    IChainlinkTrigger trigger_;
    if (pegPrice_ == 0 && pegDecimals_ == 0) {
      // We are NOT deploying a peg trigger.
      trigger_ = factory.deployTrigger(
        AggregatorV3Interface(truthOracle_),
        AggregatorV3Interface(trackingOracle_),
        priceTolerance_,
        truthFrequencyTolerance_,
        trackingFrequencyTolerance_,
        TriggerMetadata(
          "Chainlink Trigger",
          "A trigger that compares prices on Chainlink against a threshold",
          "https://via.placeholder.com/150",
          "Extra data"
        )
      );
      assertEq(trigger_.truthFrequencyTolerance(), truthFrequencyTolerance_);
    } else {
      // We are deploying a peg trigger.
      trigger_ = factory.deployTrigger(
        pegPrice_,
        pegDecimals_,
        AggregatorV3Interface(trackingOracle_),
        priceTolerance_,
        trackingFrequencyTolerance_,
        TriggerMetadata(
          "Peg Protection Trigger",
          "A trigger that protects from something depegging",
          "https://via.placeholder.com/150",
          "$category: Peg"
        )
      );
      AggregatorV3Interface pegOracle_ = trigger_.truthOracle();
      (, int256 priceInt_,,,) = pegOracle_.latestRoundData();
      assertEq(priceInt_, pegPrice_);
      assertEq(pegOracle_.decimals(), pegDecimals_);
      truthOracle_ = address(pegOracle_);

      // For peg triggers, we set the frequency tolerance to 0 for the truth FixedPriceAggregator peg oracle.
      assertEq(trigger_.truthFrequencyTolerance(), 0);
    }

    assertEq(trigger_.state(), TriggerState.ACTIVE);
    assertEq(trigger_.truthOracle(), AggregatorV3Interface(truthOracle_));
    assertEq(trigger_.trackingOracle(), AggregatorV3Interface(trackingOracle_));
    assertEq(trigger_.priceTolerance(), priceTolerance_);
    assertEq(trigger_.trackingFrequencyTolerance(), trackingFrequencyTolerance_);

    // Mock the tracking oracle's price to 0.
    vm.mockCall(
      address(trackingOracle_),
      abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
      abi.encode(uint80(1), int256(0), 0, block.timestamp, uint80(1))
    );

    // `runProgrammaticCheck` should trigger if the oracle data is fetched, because the tracking oracle's
    // price has been mocked to 0 which results in a price delta greater than _priceTolerance between the
    // truth and tracking oracles.
    vm.expectEmit(true, true, true, true);
    emit TriggerStateUpdated(TriggerState.TRIGGERED);
    assertEq(trigger_.runProgrammaticCheck(), TriggerState.TRIGGERED);
  }

  function testFork_DeployTriggerChainlinkIntegration(uint256 forkId_, address truthOracle_, address trackingOracle_)
    internal
  {
    testFork_DeployTriggerChainlinkIntegration(forkId_, truthOracle_, trackingOracle_, 0, 0);
  }

  function testFork1_DeployTriggerChainlinkIntegration() public {
    testFork_DeployTriggerChainlinkIntegration(mainnetForkId_, ethUsdOracleMainnet, stEthUsdOracleMainnet);
    testFork_DeployTriggerChainlinkIntegration(mainnetForkId_, address(0), usdcUsdOracleMainnet, 1e8, 8);
    testFork_DeployTriggerRevertsWithMismatchedOracles(mainnetForkId_, ethUsdOracleMainnet, bnbEthOracleMainnet);
  }

  function testFork10_DeployTriggerChainlinkIntegration() public {
    testFork_DeployTriggerChainlinkIntegration(optimismForkId_, ethUsdOracleOptimism, stEthUsdOracleOptimism);
    // We're using a peg price of $2 because the oracle price for USDC is exactly 1e8 at the block we've forked from
    // and the test presupposes that the spot price will not match the peg.
    testFork_DeployTriggerChainlinkIntegration(optimismForkId_, address(0), usdcUsdOracleOptimism, 2e8, 8);
    testFork_DeployTriggerRevertsWithMismatchedOracles(optimismForkId_, ethUsdOracleOptimism, linkEthOracleOptimism);
  }
}

contract DeployTriggerTest is ChainlinkTriggerFactoryTestSetup {
  function testFuzz_DeployTriggerDeploysAChainlinkTriggerWithDesiredSpecs(
    uint256 priceTolerance_,
    uint256 truthFrequencyTolerance_,
    uint256 trackingFrequencyTolerance_
  ) public {
    priceTolerance_ = bound(priceTolerance_, 0, ZOC - 1);
    IChainlinkTrigger trigger_ = factory.deployTrigger(
      AggregatorV3Interface(ethUsdOracleMainnet),
      AggregatorV3Interface(stEthUsdOracleMainnet),
      priceTolerance_,
      truthFrequencyTolerance_,
      trackingFrequencyTolerance_,
      TriggerMetadata(
        "Chainlink Trigger",
        "A trigger that compares prices on Chainlink against a threshold",
        "https://via.placeholder.com/150",
        "$category: Threshold"
      )
    );

    assertEq(trigger_.truthOracle(), AggregatorV3Interface(ethUsdOracleMainnet));
    assertEq(trigger_.trackingOracle(), AggregatorV3Interface(stEthUsdOracleMainnet));
    assertEq(trigger_.priceTolerance(), priceTolerance_);
    assertEq(trigger_.truthFrequencyTolerance(), truthFrequencyTolerance_);
    assertEq(trigger_.trackingFrequencyTolerance(), trackingFrequencyTolerance_);
  }

  function testFuzz_DeployTriggerEmitsAnEvent(
    uint256 priceTolerance_,
    uint256 truthFrequencyTolerance_,
    uint256 trackingFrequencyTolerance_
  ) public {
    priceTolerance_ = bound(priceTolerance_, 0, ZOC - 1);
    address triggerAddr_ = factory.computeTriggerAddress(
      AggregatorV3Interface(stEthUsdOracleMainnet),
      AggregatorV3Interface(ethUsdOracleMainnet),
      priceTolerance_,
      truthFrequencyTolerance_,
      trackingFrequencyTolerance_,
      0 // This is the first trigger of its kind.
    );
    bytes32 triggerConfigId_ = factory.triggerConfigId(
      AggregatorV3Interface(stEthUsdOracleMainnet),
      AggregatorV3Interface(ethUsdOracleMainnet),
      priceTolerance_,
      truthFrequencyTolerance_,
      trackingFrequencyTolerance_
    );

    vm.expectEmit(true, true, true, true);
    emit TriggerDeployed(
      triggerAddr_,
      triggerConfigId_,
      stEthUsdOracleMainnet,
      ethUsdOracleMainnet,
      priceTolerance_,
      truthFrequencyTolerance_,
      trackingFrequencyTolerance_,
      "Chainlink Trigger",
      "A trigger that compares prices on Chainlink against a threshold",
      "https://via.placeholder.com/150",
      "$category: Peg"
    );

    factory.deployTrigger(
      AggregatorV3Interface(stEthUsdOracleMainnet),
      AggregatorV3Interface(ethUsdOracleMainnet),
      priceTolerance_,
      truthFrequencyTolerance_,
      trackingFrequencyTolerance_,
      TriggerMetadata(
        "Chainlink Trigger",
        "A trigger that compares prices on Chainlink against a threshold",
        "https://via.placeholder.com/150",
        "$category: Peg"
      )
    );
  }

  function testFuzz_DeployTriggerDeploysANewTriggerEachTime(
    uint256 priceTolerance_,
    uint256 truthFrequencyTolerance_,
    uint256 trackingFrequencyTolerance_
  ) public {
    priceTolerance_ = bound(priceTolerance_, 0, ZOC - 1);
    bytes32 triggerConfigId_ = factory.triggerConfigId(
      AggregatorV3Interface(ethUsdOracleMainnet),
      AggregatorV3Interface(stEthUsdOracleMainnet),
      priceTolerance_,
      truthFrequencyTolerance_,
      trackingFrequencyTolerance_
    );

    assertEq(factory.triggerCount(triggerConfigId_), 0);

    IChainlinkTrigger triggerA_ = factory.deployTrigger(
      AggregatorV3Interface(ethUsdOracleMainnet),
      AggregatorV3Interface(stEthUsdOracleMainnet),
      priceTolerance_,
      truthFrequencyTolerance_,
      trackingFrequencyTolerance_,
      TriggerMetadata(
        "Chainlink Trigger",
        "A trigger that compares prices on Chainlink against a threshold",
        "https://via.placeholder.com/150",
        "$category: Peg"
      )
    );

    assertEq(factory.triggerCount(triggerConfigId_), 1);

    IChainlinkTrigger triggerB_ = factory.deployTrigger(
      AggregatorV3Interface(ethUsdOracleMainnet),
      AggregatorV3Interface(stEthUsdOracleMainnet),
      priceTolerance_,
      truthFrequencyTolerance_,
      trackingFrequencyTolerance_,
      TriggerMetadata(
        "Chainlink Trigger",
        "A trigger that compares prices on Chainlink against a threshold",
        "https://via.placeholder.com/150",
        "$category: Peg"
      )
    );

    assertEq(factory.triggerCount(triggerConfigId_), 2);

    assertNotEq(address(triggerA_), address(triggerB_));
  }

  function testFuzz_DeployTriggerDeploysToDifferentAddressesOnDifferentChains(uint8 chainId_) public {
    vm.assume(chainId_ != block.chainid);

    uint256 priceTolerance_ = 0.42e4;
    uint256 truthFrequencyTolerance_ = 42;
    uint256 trackingFrequencyTolerance_ = 43;

    IChainlinkTrigger triggerA_ = factory.deployTrigger(
      AggregatorV3Interface(ethUsdOracleMainnet),
      AggregatorV3Interface(stEthUsdOracleMainnet),
      priceTolerance_,
      truthFrequencyTolerance_,
      trackingFrequencyTolerance_,
      TriggerMetadata(
        "Chainlink Trigger",
        "A trigger that compares prices on Chainlink against a threshold",
        "https://via.placeholder.com/150",
        "$category: Peg"
      )
    );

    vm.chainId(chainId_);

    IChainlinkTrigger triggerB_ = factory.deployTrigger(
      AggregatorV3Interface(ethUsdOracleMainnet),
      AggregatorV3Interface(stEthUsdOracleMainnet),
      priceTolerance_,
      truthFrequencyTolerance_,
      trackingFrequencyTolerance_,
      TriggerMetadata(
        "Chainlink Trigger",
        "A trigger that compares prices on Chainlink against a threshold",
        "https://via.placeholder.com/150",
        "$category: Peg"
      )
    );

    assertNotEq(address(triggerA_), address(triggerB_));
  }
}

contract ComputeTriggerAddressTest is ChainlinkTriggerFactoryTestSetup {
  function testFuzz_ComputeTriggerAddressMatchesDeployedAddress(
    uint256 priceTolerance_,
    uint256 truthFrequencyTolerance_,
    uint256 trackingFrequencyTolerance_
  ) public {
    priceTolerance_ = bound(priceTolerance_, 0, ZOC - 1);
    address expectedAddress_ = factory.computeTriggerAddress(
      AggregatorV3Interface(stEthUsdOracleMainnet),
      AggregatorV3Interface(ethUsdOracleMainnet),
      priceTolerance_,
      truthFrequencyTolerance_,
      trackingFrequencyTolerance_,
      0 // This is the first trigger of its kind.
    );

    IChainlinkTrigger trigger_ = factory.deployTrigger(
      AggregatorV3Interface(stEthUsdOracleMainnet),
      AggregatorV3Interface(ethUsdOracleMainnet),
      priceTolerance_,
      truthFrequencyTolerance_,
      trackingFrequencyTolerance_,
      TriggerMetadata(
        "Chainlink Trigger",
        "A trigger that compares prices on Chainlink against a threshold",
        "https://via.placeholder.com/150",
        "$category: Peg"
      )
    );

    assertEq(expectedAddress_, address(trigger_));
  }

  function testFuzz_ComputeTriggerAddressComputesSameAddressesOnDifferentChains(uint8 chainId_) public {
    vm.assume(chainId_ != block.chainid);

    address addressA_ = factory.computeTriggerAddress(
      AggregatorV3Interface(ethUsdOracleMainnet),
      AggregatorV3Interface(stEthUsdOracleMainnet),
      0.2e4, // priceTolerance.
      360, // frequencyTolerance.
      390,
      42 // This is the 42nd trigger of its kind.
    );

    vm.chainId(chainId_);

    address addressB_ = factory.computeTriggerAddress(
      AggregatorV3Interface(ethUsdOracleMainnet),
      AggregatorV3Interface(stEthUsdOracleMainnet),
      0.2e4, // priceTolerance.
      360, // frequencyTolerance.
      390,
      42 // This is the 42nd trigger of its kind.
    );

    assertEq(addressA_, addressB_);
  }
}

contract TriggerConfigIdTest is ChainlinkTriggerFactoryTestSetup {
  function testFuzz_TriggerConfigIdIsDeterministic(
    uint256 priceTolerance_,
    uint256 truthFrequencyTolerance_,
    uint256 trackingFrequencyTolerance_
  ) public {
    priceTolerance_ = bound(priceTolerance_, 0, ZOC - 1);
    bytes32 configIdA_ = factory.triggerConfigId(
      AggregatorV3Interface(stEthUsdOracleMainnet),
      AggregatorV3Interface(ethUsdOracleMainnet),
      priceTolerance_,
      truthFrequencyTolerance_,
      trackingFrequencyTolerance_
    );
    bytes32 configIdB_ = factory.triggerConfigId(
      AggregatorV3Interface(stEthUsdOracleMainnet),
      AggregatorV3Interface(ethUsdOracleMainnet),
      priceTolerance_,
      truthFrequencyTolerance_,
      trackingFrequencyTolerance_
    );
    assertEq(configIdA_, configIdB_);
  }

  function testFuzz_TriggerConfigIdCanBeUsedToGetTheTriggerCount(
    uint256 priceTolerance_,
    uint256 truthFrequencyTolerance_,
    uint256 trackingFrequencyTolerance_
  ) public {
    priceTolerance_ = bound(priceTolerance_, 0, ZOC - 1);
    bytes32 triggerConfigId_ = factory.triggerConfigId(
      AggregatorV3Interface(ethUsdOracleMainnet),
      AggregatorV3Interface(stEthUsdOracleMainnet),
      priceTolerance_,
      truthFrequencyTolerance_,
      trackingFrequencyTolerance_
    );

    assertEq(factory.triggerCount(triggerConfigId_), 0);

    factory.deployTrigger(
      AggregatorV3Interface(ethUsdOracleMainnet),
      AggregatorV3Interface(stEthUsdOracleMainnet),
      priceTolerance_,
      truthFrequencyTolerance_,
      trackingFrequencyTolerance_,
      TriggerMetadata(
        "Chainlink Trigger",
        "A trigger that compares prices on Chainlink against a threshold",
        "https://via.placeholder.com/150",
        "$category: Peg"
      )
    );

    assertEq(factory.triggerCount(triggerConfigId_), 1);
  }
}

contract FindAvailableTriggerTest is ChainlinkTriggerFactoryTestSetup {
  function test_FindAvailableTriggerWhenNoneExist() public {
    testFuzz_FindAvailableTriggerWhenMultipleExistAndAreAvailable(
      0.5e4, // priceTolerance.
      24 * 60 * 60, // truthFrequencyTolerance.
      25 * 60 * 60, // trackingFrequencyTolerance.
      0 // Do not deploy any triggers.
    );
  }

  function testFuzz_FindAvailableTriggerWhenMultipleExistAndAreAvailable(
    uint256 priceTolerance_,
    uint256 truthFrequencyTolerance_,
    uint256 trackingFrequencyTolerance_,
    uint8 triggersToDeploy_
  ) public {
    priceTolerance_ = bound(priceTolerance_, 0, ZOC - 1);
    // This test is really slow (10+ seconds) without reasonable bounds.
    triggersToDeploy_ = uint8(bound(triggersToDeploy_, 0, 10));

    IChainlinkTrigger initTrigger_;
    for (uint256 i = 0; i < triggersToDeploy_; i++) {
      IChainlinkTrigger trigger_ = factory.deployTrigger(
        AggregatorV3Interface(ethUsdOracleMainnet),
        AggregatorV3Interface(stEthUsdOracleMainnet),
        priceTolerance_,
        truthFrequencyTolerance_,
        trackingFrequencyTolerance_,
        TriggerMetadata(
          "Chainlink Trigger",
          "A trigger that compares prices on Chainlink against a threshold",
          "https://via.placeholder.com/150",
          "$category: Peg"
        )
      );
      if (i == 0) initTrigger_ = trigger_;
    }

    address expectedTrigger_ = factory.findAvailableTrigger(
      AggregatorV3Interface(ethUsdOracleMainnet),
      AggregatorV3Interface(stEthUsdOracleMainnet),
      priceTolerance_,
      truthFrequencyTolerance_,
      trackingFrequencyTolerance_
    );

    // The first available trigger should be returned.
    assertEq(expectedTrigger_, address(initTrigger_));
  }

  function testFuzz_FindAvailableTriggerWhenMultipleExistButAreTriggered(
    uint256 priceTolerance_,
    uint256 truthFrequencyTolerance_,
    uint256 trackingFrequencyTolerance_,
    uint8 triggersToDeploy_
  ) public {
    priceTolerance_ = bound(priceTolerance_, 0, ZOC - 1);

    IChainlinkTrigger trigger_;
    for (uint256 i = 0; i < triggersToDeploy_; i++) {
      trigger_ = factory.deployTrigger(
        AggregatorV3Interface(stEthUsdOracleMainnet),
        AggregatorV3Interface(ethUsdOracleMainnet),
        priceTolerance_,
        truthFrequencyTolerance_,
        trackingFrequencyTolerance_,
        TriggerMetadata(
          "Chainlink Trigger",
          "A trigger that compares prices on Chainlink against a threshold",
          "https://via.placeholder.com/150",
          "$category: Peg"
        )
      );
      // Mock the trigger's state to TRIGGERED.
      vm.mockCall(
        address(trigger_), abi.encodeWithSelector(IChainlinkTrigger.state.selector), abi.encode(TriggerState.TRIGGERED)
      );
    }

    address expectedTrigger_ = factory.findAvailableTrigger(
      AggregatorV3Interface(stEthUsdOracleMainnet),
      AggregatorV3Interface(ethUsdOracleMainnet),
      priceTolerance_,
      truthFrequencyTolerance_,
      trackingFrequencyTolerance_
    );

    // All of the matching triggers are TRIGGERED.
    assertEq(expectedTrigger_, address(0));

    // Deploy another trigger with the same config, but don't mock the state to triggered.
    trigger_ = factory.deployTrigger(
      AggregatorV3Interface(stEthUsdOracleMainnet),
      AggregatorV3Interface(ethUsdOracleMainnet),
      priceTolerance_,
      truthFrequencyTolerance_,
      trackingFrequencyTolerance_,
      TriggerMetadata(
        "Chainlink Trigger",
        "A trigger that compares prices on Chainlink against a threshold",
        "https://via.placeholder.com/150",
        "$category: Peg"
      )
    );
    expectedTrigger_ = factory.findAvailableTrigger(
      AggregatorV3Interface(stEthUsdOracleMainnet),
      AggregatorV3Interface(ethUsdOracleMainnet),
      priceTolerance_,
      truthFrequencyTolerance_,
      trackingFrequencyTolerance_
    );
    assertEq(expectedTrigger_, address(trigger_));
  }
}

contract DeployPeggedTriggerTest is ChainlinkTriggerFactoryTestSetup {
  function test_DeployTriggerDeploysFixedPriceAggregator() public {
    IChainlinkTrigger trigger_ = factory.deployTrigger(
      1e8, // Fixed price.
      8, // Decimals.
      AggregatorV3Interface(usdcUsdOracleMainnet),
      0.001e4, // 0.1% price tolerance.
      60, // 60s frequency tolerance.
      TriggerMetadata(
        "Peg Protection Trigger",
        "A trigger that protects from something depegging",
        "https://via.placeholder.com/150",
        "$category: Peg"
      )
    );

    assertEq(trigger_.state(), TriggerState.ACTIVE);
    assertEq(trigger_.trackingOracle(), AggregatorV3Interface(usdcUsdOracleMainnet));
    assertEq(trigger_.priceTolerance(), 0.001e4);
    // For peg triggers, we set the frequency tolerance to 0 for the truth FixedPriceAggregator peg oracle.
    assertEq(trigger_.truthFrequencyTolerance(), 0);
    assertEq(trigger_.trackingFrequencyTolerance(), 60);

    (, int256 priceInt_,, uint256 updatedAt_,) = trigger_.truthOracle().latestRoundData();
    assertEq(priceInt_, 1e8);
    assertEq(updatedAt_, block.timestamp);
  }

  function test_DeployTriggerIdempotency() public {
    IChainlinkTrigger triggerA_ = factory.deployTrigger(
      1e8, // Fixed price.
      8, // Decimals.
      AggregatorV3Interface(usdcUsdOracleMainnet),
      0.001e4, // 0.1% price tolerance.
      60, // 60s frequency tolerance.
      TriggerMetadata(
        "Peg Protection Trigger",
        "A trigger that protects from something depegging",
        "https://via.placeholder.com/150",
        "$category: Peg"
      )
    );

    IChainlinkTrigger triggerB_ = factory.deployTrigger(
      1e8, // Fixed price.
      8, // Decimals.
      AggregatorV3Interface(usdcUsdOracleMainnet),
      0.042e4, // 4.2% price tolerance.
      360, // 360s frequency tolerance.
      TriggerMetadata(
        "Peg Protection Trigger",
        "A trigger that protects from something depegging",
        "https://via.placeholder.com/150",
        "$category: Peg"
      )
    );

    assertEq(triggerA_.truthOracle(), triggerB_.truthOracle());

    // Deploy a new trigger with a different peg.
    IChainlinkTrigger triggerC_ = factory.deployTrigger(
      1e18, // Fixed price.
      8, // Decimals.
      AggregatorV3Interface(usdcUsdOracleMainnet),
      0.042e4, // 4.2% price tolerance.
      360, // 360s frequency tolerance.
      TriggerMetadata(
        "Peg Protection Trigger",
        "A trigger that protects from something depegging",
        "https://via.placeholder.com/150",
        "$category: Peg"
      )
    );

    // A new peg oracle would need to have been deployed.
    assertNotEq(triggerB_.truthOracle(), triggerC_.truthOracle());
  }
}

contract DeployFixedPriceAggregatorTest is ChainlinkTriggerFactoryTestSetup {
  function testFuzz_DeployFixedPriceAggregatorIsIdempotent(int256 price_, uint8 decimals_, uint8 chainId_) public {
    AggregatorV3Interface oracleA_ = factory.deployFixedPriceAggregator(price_, decimals_);
    AggregatorV3Interface oracleB_ = factory.deployFixedPriceAggregator(price_, decimals_);

    assertEq(oracleA_, oracleB_);
    assertEq(oracleA_.decimals(), decimals_);

    (, int256 priceInt_,, uint256 updatedAt_,) = oracleA_.latestRoundData();
    assertEq(price_, priceInt_);
    assertEq(updatedAt_, block.timestamp);

    // FixedPriceAggregators are deployed to the same address on different chains.
    vm.chainId(chainId_);
    AggregatorV3Interface oracleC_ = factory.deployFixedPriceAggregator(price_, decimals_);
    assertEq(oracleA_, oracleC_);
  }

  function testFuzz_DeployFixedPriceAggregatorDeploysToComputedAddress(int256 price_, uint8 decimals_) public {
    AggregatorV3Interface oracle_ = factory.deployFixedPriceAggregator(price_, decimals_);
    address expectedAddress_ = factory.computeFixedPriceAggregatorAddress(price_, decimals_);
    assertEq(expectedAddress_, address(oracle_));
  }
}
