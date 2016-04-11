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

For more information on migrating PowerTrack rules from one stream to another, see [this Gnip support article](http://support.gnip.com/articles/rules-migrator.html).

The rest of this document focuses on the Ruby example app used to migrate rules.

## User-stories  <a id="user-stories" class="tall">&nbsp;</a>

Here are some common user-stories that drove the development of this app:

+ As a real-time PowerTrack 1.0 customer, I want a tool to copy those rules to a PowerTrack 2.0 stream.
+ As a real-time PowerTrack (1.0 or 2.0) customer, I want a tool to copy my 'dev' rules to my 'prod' stream.
+ As a Replay customer, I want to clone my real-time rules to my Replay stream.

## Features  <a id="features" class="tall">&nbsp;</a>

+ When migrating rules from version 1.0 to 2.0, translates rules when possible.
  + Version 1.0 rules with [deprecated Operators](http://support.gnip.com/apis/powertrack2.0/transition.html#DeprecatedOperators) can not be translated, and are instead logged.  
+ Migrates rules tags.
+ Manages POST request payload limits, 1 MB with version 1.0, 5 MB with version 2.0.
+ Provides 'output' options for:
  + Writing write rules JSON to a local file.
  + POSTing rules to the target system using the PowerTrack Rules API.

### Fundamental Details <a id="fundamental-details" class="tall">&nbsp;</a>

+ No rules are deleted.
+ Code disallows adding rules to the Source system.
+ Supported version migrations:
  + 1.0 → 1.0
    + supports all Publishers, all others are Twitter only.
  + 1.0 → 2.0 
  + 2.0 → 2.0
  
  **NOTE:** 2.0 → 1.0 migrations are not supported. 
  
+ Process can either: 
  + Add rules to the Target system using the Rules API.
  + Output Target rules JSON to a local file for review.  


## Example Usage Patterns

+ Translate a set of version 1.0 rules, write them to a local JSON file, and review.

+ Load a generated JSON file to a 'Target' stream.

+ Translate a set of version 1.0 rules straight to a version 2.0 'Target' stream.

+ Migrate a set of PowerTrack rules from a 'dev' stream straight to a 'prod' stream.

+ I had a client-side network operational problem and want to use Replay to recover data I missed in real-time.  


## Getting Started  <a id="getting-started" class="tall">&nbsp;</a>

+ Get some Gnip PowerTrack streams and rule sets you need to manage!
+ Deploy client code
    + Clone this repository.
    + Using the Gemfile, run bundle.
+ Configure both the Accounts and Options configuration files.
    + Config ```accounts.yaml``` file with account name, username, and password.
    + Config ```options.yaml``` file with processing options, including the Rules API URLs for the 'Source' and 'Target' systems. 
        + See the [Configuration Details](#configuration-details) section for the details.
+ Execute the Client using [command-line options](#command-line-options).
    + To confirm everything is ready to go, you can run the following command:
    
    ```
    $ruby rule_migrator.rb -h
    ```
    
    If you see a help 'screen' with command-line options, you should be good to go.
    
    
### Configuration details <a id="configuration-details" class="tall">&nbsp;</a>

There are two files used to configure the Rule Migrator. The ```account.yaml``` contains your 
Gnip account name, username, and password. The ```options.yaml``` file contains all the application options, including the Rule API URLs of your Source and Target streams, along with logging settings.

There are also a set of [command-line parameters](#command-line-options) that will override settings from the ```options.yaml``` file. See the 

#### Account credentials <a id="account-credentials" class="tall">&nbsp;</a>

```
 account:
   account_name: my_account_name
   user_name: my_username_email
   password:
```

#### Application Options <a id="application-options" class="tall">&nbsp;</a>



```
 source:
   url: https://api.gnip.com:443/accounts/<ACCOUNT_NAME>/publishers/twitter/streams/track/<LABEL>/rules.json

 target:
   url: https://gnip-api.twitter.com/rules/powertrack/accounts/<ACCOUNT_NAME>/publishers/twitter/<LABEL>.json

 options:
   write_rules_to: files         #options: files, api
   rules_folder: ./rules         #If generating rule files, where to write them.
   load_files: false             #If we find files in 'rules_folder' load those into Target system.
   verbose: true                 #When true, the app writes more to system out.
  
 logging:
   name: rule_migrator.log
   log_path: ./log
   warn_level: debug
   size: 1 #MB
   keep: 2
```

#### Command-line Options <a id="command-line-options" class="tall">&nbsp;</a>















## 1.0 → 2.0 Rule Translations  <a id="translations" class="tall">&nbsp;</a>

There are many PowerTrack Operator changes with 2.0. New Operators have been introduced, some have been deprecated, and some have had a grammar/name update. See [HERE](http://support.gnip.com/apis/powertrack2.0/transition.html) and [HERE](http://support.gnip.com/articles/rules-migrator.html) for more details.

When migrating 1.0 rules to 2.0, this application attempts to translate when it can, although there will be cases when the automatic translation will not be performed. For example, no version 1.0 rule which includes a deprecated Operator will be translated. In all cases, the rules that can and can not be translated are logged. 












 
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






### Code Details <a id="code-details" class="tall">&nbsp;</a>




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



