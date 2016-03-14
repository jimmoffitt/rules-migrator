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
  
  **NOTE:** 2.0 → 1.0 migrations are not supported. 

 
## User-stories

+ As a real-time PowerTrack 1.0 customer, I want a tool to copy those rules to a PowerTrack 2.0 stream.
+ As a Replay customer, I want to clone my real-time rules to my Replay stream.


## Features

+ Translates rules when necessary. 
+ Manages POST request payload limits, 1 MB with version 1.0, 5 MB with version 2.0.


## 1.0 → 2.0 Rule Translations

There are many PowerTrack Operator changes with 2.0. New Operators have been introduced, some have been deprecated, and some ave had a grammar/name update. When migrating 1.0 rules to 2.0, this application attempts to translate when it can, although there will be cases in the case of deprecated Operators that the translation can not be performed. In all cases, the rules that can and can not be translated are logged. Also, in the cases where a rule can not be translated the 2.0 Rules API will respond with a list of rules that could not be added. This list will be presented to the user and logged.
 
### lang: Operator changes.
 
 PowerTrack 1.0 supported two language classifications: the Gnip classification with the lang: Operators, and the Twitter classification with the twitter_lang: Operator. With PowerTrack 2.0, the Gnip language enrichment is being deprecated. The Twitter classification supports more languages and in some cases was more accurate. 
 
  + If just *lang:*
    + Any gnip language keys not in Twitter?
    + Nothing
  + If just *twitter_lang:*
    + Replace with *lang:*
  + If *lang:* and *twitter_lang:* used: 
    + Scans rule for most common patterns: 
          + ```lang:XX OR twitter_lang:XX``` and ```twitter_lang:xx OR lang:xx```
          + ```lang:XX twitter_lang:XX``` and ```twitter_lang:xx lang:xx```
      and replaces those with a ```lang:xx``` clause
    
    + With more complicated patterns, occurances of ```twitter_lang:xx``` are replaced with ```lang:xx```.   
    Note that this may result in rules with redundant ```lang:xx``` clauses.
          
  + *has:lang* is not supported in 2.0, and instead -lang:und can be used.
    + *has:lang* will be replaced with *-lang:und*. Note that standalone negations are not supported. If rule translation results in a standaline ```-lang:und``` clause, the rule will be rejected by the Rules API. Rejected rules will be logged and output to the rule. These rejected rules will need to be assessed separated by the user.
    
    
### Operator Replacements  
    
  Several PowerTrack 1.0 Operators are being replaced with 2.0 Operators with identical functionality.  
                
+ ```country_code:``` and ```profile_country_code:``` Operators:

    The grammar for these Operators is being updated to be more concise and logical.

    + ```country_code:xx``` clauses will be translated to ```place_country:xx```
    + ```profile_country_code:xx``` clauses will be translated to ```profile_country:xx```
    
    + ```*_contains``` Operators. The following Operators are being replaced with equivalent Operators that perform a keyword/phrase match. With these Operators, the ```*_contains:``` PowerTrack 1.0 Operators are no longer necessary:
        
    + ```place_contains:``` → ```place:```
    + ```bio_location_contains:``` → ```bio_location:```
    + ```bio_contains:``` → ```bio:```
    + ```bio_name_contains:``` → ```bio_name:```
    + ```profile_region_contains:``` → ```profile_region:```
    + ```profile_locality_contains:``` → ```profile_locality:```
    + ```profile_subregion_contains:``` → ```profile_subregion:```
    
### Klout Operators:

+ __klout_score:__ This Operator is not yet supported in 2.0. No removal or translation will be attempted, and rules with this clause will not be added to 2.0.
+ __klout_topic_id:__ This Operator is not yet supported in 2.0. No removal or translation will be attempted, and rules with this clause will not be added to 2.0.

+ __klout_topic:__ This Operator is deprecated in 2.0. No removal or translation will be attempted, and rules with this clause will not be added to 2.0.
+ __klout_topic_contains:__ This Operator is deprecated in 2.0. No removal or translation will be attempted, and rules with this clause will not be added to 2.0.   
    
    
### Other Deprecated Operators.
    
    The following Operators are deprecated in 2.0. No removal or translation will be attempted, and rules with these Operators will not be added to 2.0 streams.   
    
    + bio_lang:
    + has:profile_geo_region
    + has:profile_geo_subregion
    + has:profile_geo_locality

      

## Getting Started


### Configuration details


## Other Details

+ Rules formats: JSON and Ruby hashes.
  + Internal rules ‘currency’ is hashes.
  + External rules ‘currency’ is JSON.
  
  + API → JSON → get_rules() → hash
  + APP → hash → post_rules() → JSON



