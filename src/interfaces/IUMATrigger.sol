// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import {TriggerState} from "../structs/StateEnums.sol";

/**
 * @notice This is an automated trigger contract which will move into a
 * TRIGGERED state in the event that the UMA Optimistic Oracle answers "YES" to
 * a provided query, e.g. "Was protocol ABCD hacked on or after block 42". More
 * information about UMA oracles and the lifecycle of queries can be found here:
 * https://docs.umaproject.org/.
 * @dev The high-level lifecycle of a UMA request is as follows:
 * - someone asks a question of the oracle and provides a reward for someone
 * to answer it
 * - users of the UMA prediction market view the question (usually here:
 * https://oracle.umaproject.org/)
 * - someone proposes an answer to the question in hopes of claiming the
 * reward`
 * - users of UMA see the proposed answer and have a chance to dispute it
 * - there is a finite period of time within which to dispute the answer
 * - if the answer is not disputed during this period, the oracle finalizes
 * the answer and the proposer gets the reward
 * - if the answer is disputed, the question is sent to the DVM (Data
 * Verification Mechanism) in which UMA token holders vote on who is right
 * There are four essential players in the above process:
 * 1. Requester: the account that is asking the oracle a question.
 * 2. Proposer: the account that submits an answer to the question.
 * 3. Disputer: the account (if any) that disagrees with the proposed answer.
 * 4. The DVM: a DAO that is the final arbiter of disputed proposals.
 * This trigger plays the first role in this lifecycle. It submits a request for
 * an answer to a yes-or-no question (the query) to the Optimistic Oracle.
 * Questions need to be phrased in such a way that if a "Yes" answer is given
 * to them, then this contract will go into a TRIGGERED state. For
 * example, if you wanted to create a safety module for protecting Compound
 * users, you might deploy a UMATrigger with a query like "Was Compound hacked
 * after block X?" If the oracle responds with a "Yes" answer, this contract
 * would move into the TRIGGERED state and safety modules  with this trigger
 * registered could transition to the TRIGGERED state and potentially payout
 * Compound users.
 * But what if Compound hasn't been hacked? Can't someone just respond "No" to
 * the trigger's query? Wouldn't that be the right answer and wouldn't it mean
 * the end of the query lifecycle? Yes. For this exact reason, we have enabled
 * callbacks (see the `priceProposed` function) which will revert in the event
 * that someone attempts to propose a negative answer to the question. We want
 * the queries to remain open indefinitely until there is a positive answer,
 * i.e. "Yes, there was a hack". **This should be communicated in the query text.**
 * In the event that a YES answer to a query is disputed and the DVM sides
 * with the disputer (i.e. a NO answer), we immediately re-submit the query to
 * the DVM through another callback (see `priceSettled`). In this way, our query
 * will always be open with the oracle. If/when the event that we are concerned
 * with happens the trigger will immediately be notified.
 */
interface IUMATrigger {
  /// @dev Emitted when a trigger's state is updated.
  event TriggerStateUpdated(TriggerState indexed state);

  /// @notice The current trigger state.
  function state() external returns (TriggerState);

  /// @notice The type of query that will be submitted to the oracle.
  function queryIdentifier() external view returns (bytes32);

  /// @notice The UMA contract used to lookup the UMA Optimistic Oracle.
  function oracleFinder() external view returns (address);

  /// @notice The query that is sent to the UMA Optimistic Oracle for evaluation.
  /// It should be phrased so that only a positive answer is appropriate, e.g.
  /// "Was protocol ABCD hacked on or after block number 42". Negative answers
  /// are disallowed so that queries can remain open in UMA until the events we
  /// care about happen, if ever.
  function query() external view returns (string memory);

  /// @notice The token used to pay the reward to users that propose answers to the query.
  function rewardToken() external view returns (address);

  /// @notice The amount of `rewardToken` that must be staked by a user wanting
  /// to propose or dispute an answer to the query. See UMA's price dispute
  /// workflow for more information. It's recommended that the bond amount be a
  /// significant value to deter addresses from proposing malicious, false, or
  /// otherwise self-interested answers to the query.
  function bondAmount() external view returns (uint256);

  /// @notice The window of time in seconds within which a proposed answer may
  /// be disputed. See UMA's "customLiveness" setting for more information. It's
  /// recommended that the dispute window be fairly long (12-24 hours), given
  /// the difficulty of assessing expected queries (e.g. "Was protocol ABCD
  /// hacked") and the amount of funds potentially at stake.
  function proposalDisputeWindow() external view returns (uint256);

  /// @notice The most recent timestamp that the query was submitted to the UMA oracle.
  function requestTimestamp() external view returns (uint256);

  /// @notice UMA callback for proposals. This function is called by the UMA
  /// oracle when a new answer is proposed for the query. Its only purpose is to
  /// prevent people from proposing negative answers and prematurely closing our
  /// queries. For example, if our query were something like "Has Compound been
  /// hacked since block X?" the correct answer could easily be "No" right now.
  /// But we we don't care if the answer is "No". The trigger only cares when
  /// hacks *actually happen*. So we revert when people try to submit negative
  /// answers, as negative answers that are undisputed would resolve our query
  /// and we'd have to pay a new reward to resubmit.
  /// @param _identifier price identifier being requested.
  /// @param _timestamp timestamp of the original query request.
  /// @param _ancillaryData ancillary data of the original query request.
  function priceProposed(bytes32 _identifier, uint256 _timestamp, bytes memory _ancillaryData) external;

  /// @notice UMA callback for settlement. This code is run when the protocol
  /// has confirmed an answer to the query.
  /// @dev This callback is kept intentionally lean, as we don't want to risk
  /// reverting and blocking settlement.
  /// @param _identifier price identifier being requested.
  /// @param _timestamp timestamp of the original query request.
  /// @param _ancillaryData ancillary data of the original query request.
  /// @param _answer the oracle's answer to the query.
  function priceSettled(bytes32 _identifier, uint256 _timestamp, bytes memory _ancillaryData, int256 _answer) external;

  /// @notice Toggles the trigger if the UMA oracle has confirmed a positive
  /// answer to the query.
  function runProgrammaticCheck() external returns (uint8);

  /// @notice The UMA Optimistic Oracle queried by this trigger.
  function getOracle() external view returns (address);
}
