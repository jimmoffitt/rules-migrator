# rules-migrator

## Introduction
This tool migrates PowerTrack rules from one stream to another. It uses the Rules API to get rules from a ‘Source’ stream, and adds those rules to a ‘Target’ stream.

This tool has two main use-cases:
+ Clones PT 1.0 rules to PT 2.0.
+ Clones realtime rules to Replay streams. 

### Fundamental details

+ No rules are deleted.
+ Code disallows adding rules to the Source system.
+ Supported version migrations:
  + 1.0 → 1.0
    + 1.0 → 1.0 supports all Publishers, all others are Twitter only.
  + 1.0 → 2.0 
  + 2.0 → 2.0
   
  **NOTE:** 2.0 → 1.0 is not supported. 

+ Rules formats: JSON and Ruby hashes.
  + Internal rules ‘currency’ is hashes.
  + External rules ‘currency’ is JSON.
  
  + API → JSON → get_rules() → hash
  + APP → hash → post_rules() → JSON
 
## User-stories:

+ As a real-time PowerTrack 1.0 customer, I want a tool to copy those rules to a PowerTrack 2.0 stream.
+ As a Replay customer, I want to clone my real-time rules to my Replay stream.

## Features

+ Manages POST request payload limit of 1 MB.
+ Handles 2.0 lang: Operator changes.
  + If lang: and twitter_lang: used: 
    + Removes lang:
    + Replaces twitter_lang
  + If just lang:
    + Any gnip language keys not in twitter?
    + Nothing
  + If just twitter_lang
    + Replace with lang:
   
## Getting Started


### Configuration details
