# rules-migrator

+ [Introduction](#introduction)
+ [User-stories](#user-stories)
+ [Features](#features)
+ [Migration Example](#example)
+ [1.0 → 2.0 Rule Translations](#translations)
+ [Getting Started](#getting-started)
+ [Rule Translations](#translations)

### tl;dr

To port your PowerTrack 1.0 rules to 2.0, run the following command:

```
$ruby rule_migrator_app.rb -w "api" -s "{my 1.0 Rules API 1.0 URL}" -t "{my Rules API 2.0 URL}" 

```

And see a report like this:

```
Source system:
 	Source[:url] = https://api.gnip.com:443/accounts/snowman/publishers/twitter/streams/track/prod/rules.json
 	Source system has 37576 rules.
 	Source system has 35654 rules ready for version 2.
 	Source system has 1907 rules that were translated to version 2.
  Source system has 15 rules with version 1.0 syntax not supported in version 2.0.
  Target system already had 0 rules from Source system.
 
 Target system:
    	Target[:url] = https://gnip-api.twitter.com/rules/powertrack/accounts/snowman/publishers/twitter/prod.json
    	Target system had 0 rules before, and 37561 rules after.
     Number of rules translated: 1907
 ```

## Introduction <a id="introduction" class="tall">&nbsp;</a>

This tool migrates PowerTrack rules from one stream to another. It uses the Rules API to get rules from a **```Source```** stream, and adds those rules to a **```Target```** stream. There is also an option to write the JSON payloads to a local file for review, and later loading into the 'Target' system.

This tool has three main use-cases:
+ Provides feedback on your rule readiness for real-time PowerTrack 2.0.
+ Clones PowerTrack version 1.0 (PT 1.0) rules to PowerTrack version 2.0 (PT 2.0).
+ Clones real-time rules to Replay streams. 
+ Clones rules between real-time streams, such as 'dev' to 'prod' streams.

If you are deploying a new PowerTrack 2.0 stream, this tool can be use to create your 2.0 ruleset, translating syntax when necessary, dropping rules when necessary, then either writing directly to the Rules API 2.0 endpoint or writing to a file for verification.
 
Given the potential high volumes of real-time Twitter data, it is a best practice to review any and all rules before adding to a live production stream. It is highly recommended that you initially build your ruleset on a non-production stream before moving to a production stream. Most Gnip customers have a development/sandbox stream deployed for their internal testing. If you have never had a 'dev' stream for development and testing, they come highly recommended. If you are migrating to PowerTrack 2.0, you have the option to use the new PowerTrack 2.0 stream as a development stream during the 30-day migration period. 

After testing your rules on your development stream, you can also use this tool to copy them to your 2.0 production stream.

For more information on migrating PowerTrack rules from one stream to another, see [this Gnip support article](http://support.gnip.com/articles/migrating-powertrack-rules.html).

The rest of this document focuses on the Ruby example app developed to migrate rules.

## User-stories  <a id="user-stories" class="tall">&nbsp;</a>

Here are some common user-stories that drove the development of this tool:

+ As a real-time PowerTrack 1.0 customer, I want to know what shape my ruleset is in w.r.t. Gnip 2.0.
+ As a real-time PowerTrack 1.0 customer, I want a tool to copy those rules to a PowerTrack 2.0 stream.
+ As a real-time PowerTrack (1.0 or 2.0) customer, I want a tool to copy my 'dev' rules to my 'prod' stream.
+ As a Replay customer, I want to clone my real-time rules to my Replay stream.

## Migration Tool Features  <a id="features" class="tall">&nbsp;</a>

+ Supports generating a rules report, providing feedback on readiness for PowerTrack 2.0.  
+ When migrating rules from version 1.0 to 2.0, this tool translates rules when possible.
  + Version 1.0 rules with [deprecated Operators](http://support.gnip.com/apis/powertrack2.0/transition.html#DeprecatedOperators) can not be translated. These rules are called out in the 'rule migration summary' output.  
+ Migrates rules tags.
+ Manages POST request payload limits, 1 MB with version 1.0, 5 MB with version 2.0.
+ Provides two 'output' options:
  + Writing write rules JSON to a local file.
  + POSTing rules to the target system using the PowerTrack Rules API.
  
Note that this tool does not currently save the potentially batched JSON payloads, and only single complete ruleset files are ever written. (This functionality is needed, add it to the RuleMigrator's ```create_post_requests``` method, where the batched payloads are created in memory.)
  
  
## An Example of Migrating Rules from 1.0 to 2.0 <a id="example" class="tall">&nbsp;</a>  
  
To help illustrate how to use this tool, we'll migrate an example PowerTrack 1.0 ruleset to 2.0. Our example PT 1.0 ruleset consists of a variety of rules to highlight different tool functionality. These include rules that are already completely compatible with PT 2.0, along with some that contain deprecated Operators, and some that require some sort of translation before adding to 2.0:
   
  + Rules that are ready for 2.0 (Note: the vast majority of rules should be in this category) 
    + "this long rule is ready for 2.0" (snow OR #Winning) has:profile_geo @snowman friends_count:100
    + lang:en (rain OR flood OR storm)
  
  + Rules that require translation to 2.0
    + (twitter_lang:es OR twitter_lang:pt) (nieve OR lluvia OR tiempo OR viento OR tormenta OR granizada)
    + (twitter_lang:es OR lang:es) playa sol
    + -has:lang (sol OR sun)
    + (country_code:US OR profile_country_code:US) snow
    + bio_contains:"developer advocate"
    + place_contains:boulder OR bio_location_contains:boulder
    + bio_name_contains:jim
    + profile_region_contains:colorado OR profile_subregion_contains:weld OR profile_locality_contains:Greely
  
  + Rules with deprecated Operators (complete list of Operators with *no* replacement are included [HERE](http://support.gnip.com/apis/powertrack2.0/transition.html#DeprecatedOperators).
    + has:profile_geo_region (snow OR water)
    + has:profile_geo_subregion (coffee OR tea)
    + has:profile_geo_locality (motel OR hotel)
    + bio_lang:es "vamos a la playa"
    + klout_score:40 klout_topic_contains:coffee
  
  
For this example, our version 1.0 *```Source```* rules will be available at the following Rules API 1.0 endpoint:
   
```
https://api.gnip.com/accounts/snowman/publishers/twitter/streams/track/prod/rules.json

```
   
We'll port these rules to the following Rules API 2.0 *```Target```* endpoint:    

```
https://gnip-api.twitter.com/rules/powertrack/accounts/snowman/publishers/twitter/prod.json

```
  
First, let's get some feedback on the readiness of this version 1.0 ruleset for 2.0. When you pass in the ```-r``` command-line option, the tool will run in a 'report' mode. The 'report' mode will not make any changes to your Target ruleset, and will report on how many rules are ready for 2.0, how many need translations and what the translated rules will look like, as well as how many can not be migrated to 2.0 due to deprecated Operators with no 2.0 equivalents.  
  
To run a rules report on our example Source system, run the tool with the ```-r``` option, along with specifying the Source Rules API endpoint with the ```-s Rules-API_URL``` option:
  
  ```
  $ruby rule_migrator_app.rb -r -s "https://api.gnip.com/accounts/snowman/publishers/twitter/streams/track/prod/rules.json"
  
  ```
  
For our example ruleset, the tool will output the following rule summary:  
   
```
  Starting process at 2016-08-11 12:55:40 -0600
  Getting rules from Source system. Making Request to Rules API...
      ... got 15 rules from Source system.
  
   ******************
  Checking 15 rules for translation...
  Processed 10 rules...
  
  Running in 'report' mode, no changes will be made.
  
  ---------------------
  Rule Migrator summary
  
  ---------------------
  Source system:
  	Source[:url] = https://api.gnip.com:443/accounts/jim/publishers/twitter/streams/track/testv1/rules.json
  	Source system has 15 rules.
  	Source system has 3 rules ready for version 2.
  	Source system has 7 rules that were translated to version 2.
    Source system has 5 rules with version 1.0 syntax not supported in version 2.0.
    Target system already has 0 rules from Source system.
 
  ---------------------
  7 Source rules were translated:
     '(twitter_lang:es OR lang:es) playa sol' ----> '(lang:es) playa sol'
     'bio_contains:"developer advocate"' ----> 'bio:"developer advocate"'
     'profile_region_contains:colorado OR profile_subregion_contains:weld OR profile_locality_contains:Greely' ----> 'profile_region:colorado OR profile_subregion:weld OR profile_locality:Greely'
     '(country_code:US OR profile_country_code:US) snow' ----> '(place_country:US OR profile_country:US) snow'
     'place_contains:boulder OR bio_location_contains:boulder' ----> 'place:boulder OR bio_location:boulder'
     'bio_name_contains:jim' ----> 'bio_name:jim'
     '-has:lang (sol OR sun)' ----> 'lang:und (sol OR sun)'
  
  ---------------------
  5 Source rules contain deprecated Operators with no equivalent in version 2.0:.
     has:profile_geo_region (snow OR water)
     bio_lang:es "vamos a la playa"
     has:profile_geo_subregion (coffee OR tea)
     klout_score:40 klout_topic_contains:coffee
     has:profile_geo_locality (motel OR hotel)
  
  ---------------------
  
  Finished at 2016-08-11 12:55:42 -0600
  
```

Now, let's go ahead and migrate this ruleset to 2.0. To do this we will remove the ```-r``` options, set the ```-w "api"``` option (write to the API, rather than write a JSON file), and provide the Target Rules API 2.0 endpoint:

 ```
  $ruby rule_migrator_app.rb -w "api" -s "https://api.gnip.com/accounts/snowman/publishers/twitter/streams/track/prod/rules.json" -t "https://gnip-api.twitter.com/rules/powertrack/accounts/snowman/publishers/twitter/prod.json"
  
  ```
  
  After running that command we now have the following rules assigned to our 2.0 stream:
  
  + Rules that migrated with no changes:
    + "this long rule is ready for 2.0" (snow OR #Winning) has:profile_geo @snowman friends_count:100
    + lang:en (rain OR flood OR storm)
   
  + Rules that were translated to 2.0
    + (lang:es OR lang:pt) (nieve OR lluvia OR tiempo OR viento OR tormenta OR granizada)
    + (lang:es) playa sol
    + lang:und (sol OR sun)
    + (place_country:US OR profile_country:US) snow
    + bio:"developer advocate"
    + place:boulder OR bio_location:boulder
    + bio_name:jim
    + profile_region:colorado OR profile_subregion:weld OR profile_locality:Greely  
   
Notice that the five version 1.0 rules containing deprecated Operators could not be migrated to 2.0 (and are noted in the 'ruile migration summary'). 

Note that the Rule Migration tool also supports *writing the 2.0 ruleset to a JSON file*, allowing you to review them before writing them to your 2.0 system. To do this you can change the 'write mode' to 'file' with the ```-w "files"``` command-line option. 

This command will prepare your 2.0 rules, and write them to a 'Source_rules.json' JSON file:

```
  $ruby rule_migrator_app.rb -w "file" -s "https://api.gnip.com/accounts/snowman/publishers/twitter/streams/track/prod/rules.json" 
  
```

By default this writes the JSON rules file to a ```./rules``` folder, and automatically creates the folder if needed. Note that you can specify an alternate folder with the ```-d DIRECTORY``` option.

If, after review, this rules file looks ready to migration, you can then have the tool load its rules JSON contents to your Target system:

```
  $ruby rule_migrator_app.rb -w "api" -f "/Source_rules.json" 
```

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

File name and location defaults to ./config/account.yaml.

```
 account:
   account_name: my_account_name
   user_name: my_username_email
   password: NotMyPassword
```

#### Application Options <a id="application-options" class="tall">&nbsp;</a>

File name and location defaults to ./config/options.yaml


```
 source:
   url: https://api.gnip.com:443/accounts/{ACCOUNT_NAME}/publishers/twitter/streams/track/{STREAM_LABEL}/rules.json

 target:
   url: https://gnip-api.twitter.com/rules/powertrack/accounts/{ACCOUNT_NAME}/publishers/twitter/{STREAM_LABEL}.json

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


```
Usage: rule_migrator_app [options]
    -a, --account ACCOUNT            Account configuration file (including path) that provides OAuth settings.
    -c, --config CONFIG              Settings configuration file (including path) that provides API settings.
    -s, --source SOURCE              Rules API URL for GETting 'Source' rules.
    -t, --target TARGET              Rules API URL for POSTing rules to 'Target' system.
    -w, --write WRITE                Write rules to either 'files' or Target Rules 'api'
    -l, --load                       If inbox has files, load them into 'Target' system
    -v, --verbose                    When verbose, output all kinds of things, each request, most responses, etc.
    -h, --help                       Display this screen.
```


TODO: documentation - example calls:
rule_migrator_app -r -s "https://api.gnip.com:443/accounts/jim/publishers/twitter/streams/track/dev/rules.json"
rule_migrator_app -w "files" -s "https://api.gnip.com:443/accounts/jim/publishers/twitter/streams/track/dev/rules.json"

Cloned URL
rule_migrator_app -w "api" -s "https://api.gnip.com:443/accounts/jim/publishers/twitter/streams/track/dev/rules.json" -t "clone"

Verbose URLs
rule_migrator_app -w "api" -s "https://api.gnip.com:443/accounts/jim/publishers/twitter/streams/track/dev/rules.json" -t "https://gnip-api.twitter.com/rules/powertrack/accounts/jim/publishers/twitter/prod.json"

rule_migrator_app -l - -t "https://gnip-api.twitter.com/rules/powertrack/accounts/jim/publishers/twitter/prod.json"



Rule Migration Summaries

 
 
 ```
 ---------------------
 Rule Migrator summary
 
 ---------------------
 Source system:
 	Source[:url] = https://api.gnip.com:443/accounts/snowman/publishers/twitter/streams/track/testv1/rules.json
 	Source system has 15 rules.
 	Source system has 3 rules ready for version 2.
 	Source system has 7 rules that were translated to version 2.
  Source system has 5 rules with version 1.0 syntax not supported in version 2.0.
  Target system already had 0 rules from Source system.
 
 Target system:
    	Target[:url] = https://gnip-api.twitter.com/rules/powertrack/accounts/snowman/publishers/twitter/prod.json
    	Target system had 0 rules before, and 10 rules after.
     Number of rules translated: 7
 
 ---------------------
 7 Source rules were translated:
    '(twitter_lang:es OR lang:es) playa sol' ----> '(lang:es) playa sol'
    'bio_contains:"developer advocate"' ----> 'bio:"developer advocate"'
    'profile_region_contains:colorado OR profile_subregion_contains:weld OR profile_locality_contains:Greely' ----> 'profile_region:colorado OR profile_subregion:weld OR profile_locality:Greely'
    '(country_code:US OR profile_country_code:US) snow' ----> '(place_country:US OR profile_country:US) snow'
    'place_contains:boulder OR bio_location_contains:boulder' ----> 'place:boulder OR bio_location:boulder'
    'bio_name_contains:jim' ----> 'bio_name:jim'
    '-has:lang (sol OR sun)' ----> 'lang:und (sol OR sun)'
 
 ---------------------
 
 
 ---------------------
 5 Source rules contain deprecated Operators with no equivalent in version 2.0:.
    has:profile_geo_region (snow OR water)
    bio_lang:es "vamos a la playa"
    has:profile_geo_subregion (coffee OR tea)
    klout_score:40 klout_topic_contains:coffee
    has:profile_geo_locality (motel OR hotel)
 
 
 ---------------------
 ```







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






