// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.22;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ChainlinkTrigger} from "../src/ChainlinkTrigger.sol";
import {TriggerTestSetup} from "./utils/TriggerTestSetup.sol";
import {MockChainlinkOracle} from "./utils/MockChainlinkOracle.sol";
import {TriggerState} from "../src/structs/StateEnums.sol";

contract MockChainlinkTrigger is ChainlinkTrigger {
  constructor(
    AggregatorV3Interface truthOracle_,
    AggregatorV3Interface targetOracle_,
    uint256 priceTolerance_,
    uint256 truthFrequencyTolerance_,
    uint256 trackingFrequencyTolerance_
  )
    ChainlinkTrigger(truthOracle_, targetOracle_, priceTolerance_, truthFrequencyTolerance_, trackingFrequencyTolerance_)
  {}

  function TEST_HOOK_programmaticCheck() public view returns (bool) {
    return programmaticCheck();
  }

  function TEST_HOOK_setState(TriggerState newState_) public {
    state = newState_;
  }
}

abstract contract ChainlinkTriggerUnitTest is TriggerTestSetup {
  uint256 constant ZOC = 1e4;
  uint256 constant basePrice = 1_945_400_000_000; // The answer for BTC/USD at block 15135183.
  uint256 priceTolerance = 0.15e4; // 15%.
  uint256 truthFrequencyTolerance = 60;
  uint256 trackingFrequencyTolerance = 80;

  MockChainlinkTrigger trigger;
  MockChainlinkOracle truthOracle;
  MockChainlinkOracle targetOracle;

  function setUp() public override {
    super.setUp();

    truthOracle = new MockChainlinkOracle(basePrice, 8);
    targetOracle = new MockChainlinkOracle(1_947_681_501_285, 8); // The answer for WBTC/USD at block 15135183.

    trigger = new MockChainlinkTrigger(
      truthOracle, targetOracle, priceTolerance, truthFrequencyTolerance, trackingFrequencyTolerance
    );
  }
}

contract ChainlinkTriggerConstructorTest is ChainlinkTriggerUnitTest {
  function testConstructorRunProgrammaticCheck() public {
    truthOracle = new MockChainlinkOracle(basePrice, 8);

    // Truth oracle has a base price of 1945400000000 and the price tolerance is 0.15e4, so with a target oracle price
    // of 1e12, runProgrammaticCheck() should result in the trigger becoming triggered.
    targetOracle = new MockChainlinkOracle(1e12, 8);
    trigger = new MockChainlinkTrigger(
      truthOracle, targetOracle, priceTolerance, truthFrequencyTolerance, trackingFrequencyTolerance
    );

    // The trigger constructor should have executed runProgrammaticCheck() which should have transitioned
    // the trigger into the triggered state.
    assertEq(trigger.state(), TriggerState.TRIGGERED);
  }

  function testFuzzConstructorInvalidPriceTolerance(uint256 priceTolerance_) public {
    priceTolerance_ = bound(priceTolerance_, ZOC, type(uint256).max);

    vm.expectRevert(ChainlinkTrigger.InvalidPriceTolerance.selector);
    trigger = new MockChainlinkTrigger(
      truthOracle, targetOracle, priceTolerance_, truthFrequencyTolerance, trackingFrequencyTolerance
    );
  }

  function testConstructorOraclesDifferentDecimals() public {
    MockChainlinkOracle truthOracle_ = new MockChainlinkOracle(19_454_000_000_000_000_000_000, 18);
    MockChainlinkOracle targetOracle_ = new MockChainlinkOracle(1_947_681_501_285, 8); // The answer for WBTC/USD at
      // block
      // 15135183.

    trigger = new MockChainlinkTrigger(
      truthOracle_, targetOracle_, priceTolerance, truthFrequencyTolerance, trackingFrequencyTolerance
    );
    assertEq(trigger.scaleFactor(), 1e10);
    assertEq(uint256(trigger.oracleToScale()), uint256(ChainlinkTrigger.OracleToScale.TRACKING));

    truthOracle_ = new MockChainlinkOracle(1_945_400_000_000, 8);
    targetOracle_ = new MockChainlinkOracle(19_476_815_012_850_000_000_000, 18); // The answer for WBTC/USD at block
      // 15135183.
    trigger = new MockChainlinkTrigger(
      truthOracle_, targetOracle_, priceTolerance, truthFrequencyTolerance, trackingFrequencyTolerance
    );
    assertEq(trigger.scaleFactor(), 1e10);
    assertEq(uint256(trigger.oracleToScale()), uint256(ChainlinkTrigger.OracleToScale.TRUTH));

    truthOracle_ = new MockChainlinkOracle(19_454, 0);
    targetOracle_ = new MockChainlinkOracle(19_476_815_012_850_000_000_000, 18); // The answer for WBTC/USD at block
      // 15135183.
    trigger = new MockChainlinkTrigger(
      truthOracle_, targetOracle_, priceTolerance, truthFrequencyTolerance, trackingFrequencyTolerance
    );
    assertEq(trigger.scaleFactor(), 1e18);
    assertEq(uint256(trigger.oracleToScale()), uint256(ChainlinkTrigger.OracleToScale.TRUTH));

    truthOracle_ = new MockChainlinkOracle(194_540, 1);
    targetOracle_ = new MockChainlinkOracle(19_476_815_012_850_000_000_000, 18); // The answer for WBTC/USD at block
      // 15135183.
    trigger = new MockChainlinkTrigger(
      truthOracle_, targetOracle_, priceTolerance, truthFrequencyTolerance, trackingFrequencyTolerance
    );
    assertEq(trigger.scaleFactor(), 1e17);
    assertEq(uint256(trigger.oracleToScale()), uint256(ChainlinkTrigger.OracleToScale.TRUTH));

    truthOracle_ = new MockChainlinkOracle(19_454_000_000_000_000_000_000, 18);
    targetOracle_ = new MockChainlinkOracle(1_947_681_501_285_000_000_000_000, 20); // The answer for WBTC/USD at block
      // 15135183.
    trigger = new MockChainlinkTrigger(
      truthOracle_, targetOracle_, priceTolerance, truthFrequencyTolerance, trackingFrequencyTolerance
    );
    assertEq(trigger.scaleFactor(), 1e2);
    assertEq(uint256(trigger.oracleToScale()), uint256(ChainlinkTrigger.OracleToScale.TRUTH));

    truthOracle_ = new MockChainlinkOracle(1_945_400_000_000, 8);
    targetOracle_ = new MockChainlinkOracle(1_947_681_501_285, 8); // The answer for WBTC/USD at block 15135183.
    trigger = new MockChainlinkTrigger(
      truthOracle_, targetOracle_, priceTolerance, truthFrequencyTolerance, trackingFrequencyTolerance
    );
    assertEq(trigger.scaleFactor(), 0);
    assertEq(uint256(trigger.oracleToScale()), uint256(ChainlinkTrigger.OracleToScale.NONE));
  }
}

contract RunProgrammaticCheckTest is ChainlinkTriggerUnitTest {
  using FixedPointMathLib for uint256;

  function runProgrammaticCheckAssertions(uint256 targetPrice_, TriggerState expectedTriggerState_) public {
    // Setup.
    trigger.TEST_HOOK_setState(TriggerState.ACTIVE);
    targetOracle.TEST_HOOK_setPrice(targetPrice_);

    // Exercise.
    assertEq(trigger.runProgrammaticCheck(), expectedTriggerState_);
    assertEq(trigger.state(), expectedTriggerState_);
  }

  function testRunProgrammaticCheckUpdatesTriggerState() public {
    uint256 overBaseOutsideTolerance_ = basePrice.mulDivDown(1e4 + priceTolerance, 1e4) + 1e9;
    runProgrammaticCheckAssertions(overBaseOutsideTolerance_, TriggerState.TRIGGERED);

    uint256 overBaseAtTolerance_ = basePrice.mulDivDown(1e4 + priceTolerance, 1e4);
    runProgrammaticCheckAssertions(overBaseAtTolerance_, TriggerState.ACTIVE);

    uint256 overBaseWithinTolerance_ = basePrice.mulDivDown(1e4 + priceTolerance, 1e4) - 1e9;
    runProgrammaticCheckAssertions(overBaseWithinTolerance_, TriggerState.ACTIVE);

    runProgrammaticCheckAssertions(basePrice, TriggerState.ACTIVE); // At base exactly.

    uint256 underBaseWithinTolerance_ = basePrice.mulDivDown(1e4 - priceTolerance, 1e4) + 1e9;
    runProgrammaticCheckAssertions(underBaseWithinTolerance_, TriggerState.ACTIVE);

    uint256 underBaseAtTolerance_ = basePrice.mulDivDown(1e4 - priceTolerance, 1e4);
    runProgrammaticCheckAssertions(underBaseAtTolerance_, TriggerState.ACTIVE);

    uint256 underBaseOutsideTolerance_ = basePrice.mulDivDown(1e4 - priceTolerance, 1e4) - 1e9;
    runProgrammaticCheckAssertions(underBaseOutsideTolerance_, TriggerState.TRIGGERED);
  }
}

contract ProgrammaticCheckTest is ChainlinkTriggerUnitTest {
  using FixedPointMathLib for uint256;

  function testProgrammaticCheckAtDiscretePoints() public {
    // 0.00000001e18
    targetOracle.TEST_HOOK_setPrice(basePrice.mulDivDown(1e4 + priceTolerance, 1e4) + 1e9); // Over base outside
      // tolerance.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), true);

    targetOracle.TEST_HOOK_setPrice(basePrice.mulDivDown(1e4 + priceTolerance, 1e4)); // Over base at tolerance.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), false);

    targetOracle.TEST_HOOK_setPrice(basePrice.mulDivDown(1e4 + priceTolerance, 1e4) - 1e9); // Over base within
      // tolerance.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), false);

    targetOracle.TEST_HOOK_setPrice(basePrice); // At base exactly.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), false);

    targetOracle.TEST_HOOK_setPrice(basePrice.mulDivDown(1e4 - priceTolerance, 1e4) + 1e9); // Under base within
      // tolerance.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), false);

    targetOracle.TEST_HOOK_setPrice(basePrice.mulDivDown(1e4 - priceTolerance, 1e4)); // Under base at tolerance.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), false);

    targetOracle.TEST_HOOK_setPrice(basePrice.mulDivDown(1e4 - priceTolerance, 1e4) - 1e9); // Under base outside
      // tolerance.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), true);
  }

  function testTruthOracleZeroPrice() public {
    truthOracle.TEST_HOOK_setPrice(0);
    assertEq(trigger.TEST_HOOK_programmaticCheck(), true);
  }

  function testFuzzProgrammaticCheckRevertsIfUpdatedAtExceedsBlockTimestamp(
    uint256 truthOracleUpdatedAt_,
    uint256 targetOracleUpdatedAt_
  ) public {
    uint256 currentTimestamp_ = 165_738_985; // When this test was written.
    // Warp to the current timestamp to avoid Arithmetic over/underflow with dates.
    vm.warp(currentTimestamp_);

    truthOracleUpdatedAt_ =
      bound(truthOracleUpdatedAt_, block.timestamp - truthFrequencyTolerance, block.timestamp + 1 days);
    targetOracleUpdatedAt_ =
      bound(targetOracleUpdatedAt_, block.timestamp - trackingFrequencyTolerance, block.timestamp + 1 days);

    truthOracle.TEST_HOOK_setUpdatedAt(truthOracleUpdatedAt_);
    targetOracle.TEST_HOOK_setUpdatedAt(targetOracleUpdatedAt_);

    if (truthOracleUpdatedAt_ > block.timestamp || targetOracleUpdatedAt_ > block.timestamp) {
      vm.expectRevert(ChainlinkTrigger.InvalidTimestamp.selector);
    }

    trigger.TEST_HOOK_programmaticCheck();
  }

  function testFuzzProgrammaticCheckRevertsIfEitherOraclePriceIsStale(
    uint256 truthOracleUpdatedAt_,
    uint256 targetOracleUpdatedAt_
  ) public {
    uint256 currentTimestamp_ = 165_738_985; // When this test was written.
    truthOracleUpdatedAt_ = bound(truthOracleUpdatedAt_, 0, currentTimestamp_);
    targetOracleUpdatedAt_ = bound(targetOracleUpdatedAt_, 0, currentTimestamp_);

    truthOracle.TEST_HOOK_setUpdatedAt(truthOracleUpdatedAt_);
    targetOracle.TEST_HOOK_setUpdatedAt(targetOracleUpdatedAt_);

    vm.warp(currentTimestamp_);
    if (
      truthOracleUpdatedAt_ + truthFrequencyTolerance < block.timestamp
        || targetOracleUpdatedAt_ + trackingFrequencyTolerance < block.timestamp
    ) vm.expectRevert(ChainlinkTrigger.StaleOraclePrice.selector);

    trigger.TEST_HOOK_programmaticCheck();
  }

  function testFuzzProgrammaticCheckRoundUpDeltaPercentageBelowTolerance(uint128 truthPrice_) public {
    // In this test we subtract 1 from the value that is at the price tolerance from the truth
    // price, and confirm the trigger will not become triggered from a programmatic check. For any
    // truth price less than 7, any tracking value different than the truth price would result in
    // a delta greater than the tolerance (the setup price tolerance is 0.15e4, 15%).
    vm.assume(truthPrice_ >= 7);

    truthOracle.TEST_HOOK_setPrice(truthPrice_);

    uint256 trackingPrice_ = uint256(truthPrice_) + (uint256(truthPrice_) * priceTolerance / 1e4) - 1;
    targetOracle.TEST_HOOK_setPrice(trackingPrice_);

    // Confirm the calculation in ChainlinkTrigger.programmaticCheck to determine the percentage
    // delta, which rounds up, does not cause the state of the trigger to become triggered.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), false);
  }

  function testFuzzProgrammaticCheckRoundUpDeltaPercentageEqualTolerance(uint128 truthPrice_) public {
    vm.assume(truthPrice_ != 0);

    truthOracle.TEST_HOOK_setPrice(truthPrice_);

    uint256 trackingPrice_ = uint256(truthPrice_) + (uint256(truthPrice_) * priceTolerance / 1e4);
    targetOracle.TEST_HOOK_setPrice(trackingPrice_);

    // Confirm the calculation in ChainlinkTrigger.programmaticCheck to determine the percentage
    // delta, which rounds up, does not cause the state of the trigger to become triggered.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), false);
  }

  function testFuzzProgrammaticCheckRoundUpDeltaPercentageAboveTolerance(uint128 truthPrice_) public {
    // In this test we add 1 to the value that is at the price tolerance from the truth price, and
    // confirm the trigger will not become triggered from a programmatic check. For any truth price
    // less than 7, any tracking value different than the truth price
    // would result in a delta greater than the tolerance (the setup price tolerance is 0.15e4, 15%).
    vm.assume(truthPrice_ >= 7);

    truthOracle.TEST_HOOK_setPrice(truthPrice_);

    uint256 trackingPrice_ = uint256(truthPrice_) + (uint256(truthPrice_) * priceTolerance / 1e4) + 1;
    targetOracle.TEST_HOOK_setPrice(trackingPrice_);

    // Confirm the calculation in ChainlinkTrigger.programmaticCheck to determine the percentage
    // delta, which rounds up, causes the state of the trigger to become triggered.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), true);
  }
}

abstract contract PegProtectionTriggerUnitTest is TriggerTestSetup {
  MockChainlinkOracle truthOracle;
  MockChainlinkOracle trackingOracle;
  MockChainlinkTrigger trigger;
  uint256 frequencyTolerance = 3600; // 1 hour frequency tolerance.

  function setUp() public override {
    super.setUp();

    truthOracle = new MockChainlinkOracle(1e8, 8); // A $1 peg.
    trackingOracle = new MockChainlinkOracle(1e8, 8);

    trigger = new MockChainlinkTrigger(
      truthOracle,
      trackingOracle,
      0.05e4, // 5% price tolerance.
      1,
      frequencyTolerance
    );
  }
}

contract PegProtectionRunProgrammaticCheckTest is PegProtectionTriggerUnitTest {
  function runProgrammaticCheckAssertions(uint256 price_, TriggerState expectedTriggerState_) public {
    // Setup.
    trigger.TEST_HOOK_setState(TriggerState.ACTIVE);
    trackingOracle.TEST_HOOK_setPrice(price_);

    // Exercise.
    assertEq(trigger.runProgrammaticCheck(), expectedTriggerState_);
    assertEq(trigger.state(), expectedTriggerState_);
  }

  function testRunProgrammaticCheckUpdatesTriggerState() public {
    runProgrammaticCheckAssertions(130_000_000, TriggerState.TRIGGERED); // Over peg outside tolerance.
    runProgrammaticCheckAssertions(104_000_000, TriggerState.ACTIVE); // Over peg but within tolerance.
    runProgrammaticCheckAssertions(105_000_000, TriggerState.ACTIVE); // Over peg at tolerance.
    runProgrammaticCheckAssertions(100_000_000, TriggerState.ACTIVE); // At peg exactly.
    runProgrammaticCheckAssertions(96_000_000, TriggerState.ACTIVE); // Under peg but within tolerance.
    runProgrammaticCheckAssertions(95_000_000, TriggerState.ACTIVE); // Under peg at tolerance.
    runProgrammaticCheckAssertions(90_000_000, TriggerState.TRIGGERED); // Under peg outside tolerance.
  }
}

contract PegProtectionProgrammaticCheckTest is PegProtectionTriggerUnitTest {
  function testProgrammaticCheckAtDiscretePoints() public {
    trackingOracle.TEST_HOOK_setPrice(130_000_000); // Over peg outside tolerance.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), true);

    trackingOracle.TEST_HOOK_setPrice(104_000_000); // Over peg but within tolerance.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), false);

    trackingOracle.TEST_HOOK_setPrice(105_000_000); // Over peg at tolerance.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), false);

    trackingOracle.TEST_HOOK_setPrice(1e8); // At peg exactly.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), false);

    trackingOracle.TEST_HOOK_setPrice(96_000_000); // Under peg but within tolerance.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), false);

    trackingOracle.TEST_HOOK_setPrice(95_000_000); // Under peg at tolerance.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), false);

    trackingOracle.TEST_HOOK_setPrice(90_000_000); // Under peg outside tolerance.
    assertEq(trigger.TEST_HOOK_programmaticCheck(), true);
  }
}
