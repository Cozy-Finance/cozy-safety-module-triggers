// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

struct TriggerMetadata {
  // The name that should be used for safety modules that use the trigger.
  string name;
  // A human-readable description of the trigger.
  string description;
  // The URI of a logo image to represent the trigger.
  string logoURI;
  // Extra metadata for the trigger.
  string extraData;
}
