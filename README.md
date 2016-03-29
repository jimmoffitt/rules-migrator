# rules-migrator

+ [Introduction](#introduction)
+ [User-stories](#user-stories)
+ [Features](#features)
+ [1.0 → 2.0 Rule Translations](#translations)
+ [Getting Started](#getting-started)

## Introduction <a id="introduction" class="tall">&nbsp;</a>

This tool migrates PowerTrack rules from one stream to another. It uses the Rules API to get rules from a **‘Source’** stream, and adds those rules to a **‘Target’** stream. There is also an option to write the JSON payloads to a local file for review, and later loading into the 'Target' system.

This tool has three main use-cases:
+ Clones PowerTrack version 1.0 (PT 1.0) rules to PowerTrack version 2.0 (PT 2.0).
+ Clones real-time rules to Replay streams. 
+ Clones rules between real-time streams, such as 'dev' to 'prod' streams.
 
Given the high volumes of real-time Twitter data, it is highly recommended that rules are reviewed before adding to a live stream. If you are deploying a new PowerTrack stream, this tool can be use to migrate the rules, then verify your ruleset before connecting to the new stream 

For more information on migrating PowerTrack rules from one stream to another, see [this Gnip soppurt article].

The rest of this document focuses on the Ruby example app used to migrate rules.

## User-stories  <a id="user-stories" class="tall">&nbsp;</a>

Here are some common user-stories in mind when writing this app:

+ As a real-time PowerTrack 1.0 customer, I want a tool to copy those rules to a PowerTrack 2.0 stream.
+ As a real-time PowerTrack customer, I want a tool to copy my 'dev' rules to my 'prod' stream.
+ As a Replay customer, I want to clone my real-time rules to my Replay stream.

## Features  <a id="features" class="tall">&nbsp;</a>

+ Translates rules when necessary. 
+ Migrates rules tags.
+ Manages POST request payload limits, 1 MB with version 1.0, 5 MB with version 2.0.
+ Provides options for:
  + Writing write rules JSON to a local file.
  + POSTing rules to the target system using the PowerTrack Rules API.

### Fundamental Details

+ No rules are deleted.
+ Code disallows adding rules to the Source system.
+ Supported version migrations:
  + 1.0 → 1.0
    + supports all Publishers, all others are Twitter only.
  + 1.0 → 2.0 
  + 2.0 → 2.0
  
  **NOTE:** 2.0 → 1.0 migrations are not supported. 
  
+ Process can either 
    + Add rules to the Target system using the Rules API.
    + Output Target rules JSON to a local file for review.  

## 1.0 → 2.0 Rule Translations  <a id="translations" class="tall">&nbsp;</a>

There are many PowerTrack Operator changes with 2.0. New Operators have been introduced, some have been deprecated, and some have had a grammar/name update. When migrating 1.0 rules to 2.0, this application attempts to translate when it can, although there will be cases when the automatic translation will not be performed. [TODO: what cases? itemize?] 
+ Deprecated Operators. 

In all cases, the rules that can and can not be translated are logged. Also, in the cases where a rule can not be translated the 2.0 Rules API will respond with a list of rules that could not be added. This list will be presented to the user and logged. [Test/code 
 
 
 In PowerTrack 1.0, there were two different language classification systems and corresponding Operators. Gnip first introduced its language classification and the ```lang:``` Operator in March, 2012. Twitter launched its language classification in [DATE?], and the ```twitter_lang:``` Operator was introduced to PowerTrack. The Twitter language classification handles many more languages, and also indicates when a language was could not be identified by assigning a 'und' result. 

As with all Gnip 2.0 products (along with [Full-Archive Search](http://support.gnip.com/apis/search_full_archive_api/)), PowerTrack 2.0 supports only the Twitter language classification. Since there is only one classification source now, there is only one PowerTrack Operator, ```lang:```. 

Since the Twitter classifications cover *all* of the Gnip languages, and use the identical two-character codes, all ```lang:``` version 1.0 rule clauses will translate smoothly to version 2.0. Since the introduction of the Twitter classification, many PowerTrack users have introduced the ```twitter_lang:``` Operator to their rule set. When moving to version 2.0, these rule clauses need to be re-written as ```lang:```.

As noted below in the next section, the version 1.0 ```has:geo``` is being deprecated. With PowerTrack 2.0, this Operator is replaced with the ```-lang:und``` negation clause (indicating that a language classification was made).
 

### Operator Replacements  
    
  Two PowerTrack 1.0 Operators are being replaced with renamed 2.0 Operators with identical functionality:
  + ```country_code:``` is replaced with ```place_country:```
  + ```profile_country_code:``` is replaced with ```profile_country:```

The grammar for these Operators is being updated to be more concise and logical.

[TODO: examples]

Other substring matching Operators are being equivalent token-based Operators. This group is made up of the ```*_contains``` Operators: 

+ ```place_contains:``` → ```place:```
+ ```bio_location_contains:``` → ```bio_location:```
+ ```bio_contains:``` → ```bio:```
+ ```bio_name_contains:``` → ```bio_name:```
+ ```profile_region_contains:``` → ```profile_region:```
+ ```profile_locality_contains:``` → ```profile_locality:```
+ ```profile_subregion_contains:``` → ```profile_subregion:```

[TODO: examples]
    
### Klout Operators

+ __klout_score:__ This Operator is not yet supported in 2.0. No removal or translation will be attempted, and rules with this clause will not be added to 2.0.
+ __klout_topic_id:__ This Operator is not yet supported in 2.0. No removal or translation will be attempted, and rules with this clause will not be added to 2.0.

+ __klout_topic:__ This Operator is deprecated in 2.0. No removal or translation will be attempted, and rules with this clause will not be added to 2.0.
+ __klout_topic_contains:__ This Operator is deprecated in 2.0. No removal or translation will be attempted, and rules with this clause will not be added to 2.0.   
    
    
### Other Deprecated Operators
    
    The following Operators are deprecated in 2.0. No removal or translation will be attempted, and rules with these Operators will not be added to 2.0 streams.   
    
+ bio_lang:
+ has:profile_geo_region
+ has:profile_geo_subregion
+ has:profile_geo_locality


## Example Usage Patterns

+ Translate a set of vesion 1.0 rules, write them to a local JSON file, and review.


+ Migrate a set of PowerTrack rules from a 'dev' stream to a 'prod' stream.


+ I had a client-side network operational problem and want to use Replay to recover data I missed in real-time.  


## Getting Started  <a id="getting-started" class="tall">&nbsp;</a>

+ Get some Gnip PowerTrack streams and rul esets you need to manage!
+ Deploy client code
    + Clone this repository.
    + Using the Gemfile, run bundle.
+ Configure both the Accounts and Options configuration files.
    + Config ```accounts.yaml``` file with OAuth keys and tokens.
    + Config ```options.yaml``` file with processing options, Engagement Types, and Engagement Groupings.
    + See the [Configuring Client](#configuring-client) section for the details.
+ Execute the Client using [command-line options](#command-line-options).
    + To confirm everything is ready to go, you can run the following command:
    ```
    $ruby rule_migrator.rb -test 
    ```
    The following output is at least a sign that the code is ready to go:
    
    ```
Testing rule_migrator, ready to use...
    ```
### Configuration details


#### Account credentials

```
account:
  account_name: my_account_name
  user_name: my_username_email
  password:
```

#### Options

```
source:
  url: https://api.gnip.com:443/accounts/<ACCOUNT_NAME>/publishers/twitter/streams/track/<LABEL>/rules.json

target:
  url: https://gnip-api.twitter.com/rules/powertrack/accounts/<ACCOUNT_NAME>/publishers/twitter/<LABEL>.json

options:
  write_rules_to: files #options: files, api
  inbox: ./inbox
  verbose: true
  
logging:
  name: rule_migrator.log
  log_path: ./log
  warn_level: debug
  size: 1 #MB
  keep: 2
```

##### Source and Target Systems

```

source:
  url: https://api.gnip.com:443/accounts/<ACCOUNT_NAME>/publishers/twitter/streams/track/prod/rules.json

target:
  url: https://gnip-api.twitter.com/rules/powertrack/accounts/<ACCOUNT_NAME>/publishers/twitter/prod.json

```

#### Options

```
options:
  write_rules_to: files #options: files, api
  inbox: ./inbox
  verbose: true
```

### Code Details



#### Rule Translations


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


## Other Details

+ Rules formats: JSON and Ruby hashes.
  + Internal rules ‘currency’ is hashes.
  + External rules ‘currency’ is JSON.
  
  + API → JSON → get_rules() → hash
  + APP → hash → post_rules() → JSON



