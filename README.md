# rules-migrator

+ [Introduction](#introduction)
+ [User-stories](#user-stories)
+ [Features](#features)
+ [Migration Example](#example)
+ [Getting Started](#getting-started)
+ [More Examples](#more-examples)
+ [Rule Translations](#translations)

### tl;dr

To port your PowerTrack rules to Filtered stream v2, run the following command:

```
$ruby rule_migrator_app.rb -w "api" -s "{my PowerTrack Rules endpoint URL}" -t "{my v2 Filtered stream rules endpoint}" 

```

For example, say you have an enterprise account name of ```snowman``` with a ```prod``` stream label, and you want to migrate your rules to your v2 Filtered stream, the command would look like (all on one line): 

```
$ruby rule_migrator_app.rb -w "api" 
            -s "https://gnip-api.twitter.com/rules/powertrack/accounts/snowman/publishers/twitter/prod.json"  
            -t "https://api.twitter.com/2/tweets/search/stream/rules"
```

The script can also work with files, either loading rules from a JSON file, and/or writing the new rules to a file. Writing the rules to a file enables you to review the them before loading into your v2 Filtered stream system. 

The script can also generate a report that provides information about your rule sets. 

Reports look like this:

```
Source system:
 	Source[:url] = https://gnip-api.twitter.com/rules/powertrack/accounts/snowman/publishers/twitter/prod.json 
 	Source system has 37576 rules.
 	Source system has 35654 rules ready for Filtered stream v2.
 	Source system has 1907 rules that were translated to version 2.
            Source system has 15 rules with Operators not supported in the Twitter API v2 Filtered stream endpoint.
    
 Target system:
    Target[:url] = https://api.twitter.com/2/tweets/search/stream/rules
    Target system had 0 rules before, and 37561 rules after.
    Number of rules translated: 1907
 ```

## Introduction <a id="introduction" class="tall">&nbsp;</a>

This tool migrates PowerTrack rules to the Twitter API v2 Filtered stream endpoint. It can also move rules from one Filtered stream to another, as well as from one PowerTrack stream to another. It uses the rule endpoints to get rules from a **```Source```** stream, and adds those rules to a **```Target```** stream. There is also an option to write the JSON payloads to a local file for review, and later loading into the 'Target' system.

This tool has four main use-cases:
+ Provides feedback on your PowerTrack ruleset's readiness for the Twitter API v2 Filtered stream endpoint.
+ Clones PowerTrack rules to the Twitter API v2 Filtered stream endpoint.
+ Clones real-time rules to Replay streams. 
+ Clones rules between real-time streams, such as 'dev' to 'prod' streams.

If you are deploying a new Twitter API v2 Filtered stream, this tool can be use to create your v2 ruleset, translating syntax when possible, dropping rules when necessary, then either writing directly to the Filtered stream rules endpoint or writing to a file for verification.
 
Given the potential high volumes of real-time Twitter data, it is a best practice to review any and all rules before adding to a live production stream. It is highly recommended that you initially build your ruleset on a non-production stream before moving to a production stream. Many stream consumers have a development/sandbox stream deployed for their internal testing. If you have never had a 'dev' stream for development and testing, they come highly recommended. If you are migrating to the Filtered stream endpoint, you have the option to use the new stream as a development stream during your migration period. 

After testing your rules on your v2 development stream, you can also use this tool to copy them to your v2 production stream.

For more information on migrating Twitter API v2 rules from one stream to another, see TODO: WHERE?.

The rest of this document focuses on the Ruby example app developed to migrate rules.

## User-stories  <a id="user-stories" class="tall">&nbsp;</a>

Here are some common user-stories that drove the development of this tool:

+ As a real-time PowerTrack customer, I want to know what shape my ruleset is in for migrating to the Twitter API v2 Filtered stream endpoint.
+ As a real-time PowerTrack customer, I want a tool to copy those rules to the Twitter API v2 Filtered stream endpoint.
+ As a real-time streaming user, I want a tool to copy my 'dev' rules to my 'prod' stream.
+ As a Replay user, I want to clone my real-time rules to my Replay stream.

## Migration Tool Features  <a id="features" class="tall">&nbsp;</a>

By design this tool relies on rule validation results, even when only producing a rules report and not actually posting rules to the ```Target``` rules endpoint. The v2 rules endpoint already does a lot of rule validation, and this tool was designed to take advantage of that. For example, the rules endpoint disallows rules with explicit ANDs and lowercase ors, two of the most common syntactic mistakes when constructing Filtered stream rules. So rather than write new code for those validations, the rules endpoint is asked to validate all rules, even when just generating a rules report. When in report mode, it calls the new rule validation endpoint. This endpoint exercises the rule validation logic, but does not apply any rule updates.

Another key detail of the rules endpoint that drove the design of this tool is the fact that with the v2 Fitlered stream rules endpoint you receive detailed information on what rules were added, and what rules failed validation. (With our previous version, one bad rule would cause no rules to be added).   


{TODO: Since we are not going from PT 1.0 to 2.0, we can drop the ability to remove invalid rules for the retry}

Here are some other features:

+ Supports generating a rules report, providing feedback on readiness for the Twitter API v2 Filtered stream endpoint.
+ When migrating rules from PowerTrack to Filtered stream, this tool translates rules when possible.
  + PowerTrack rules with [deprecated Operators](http://WHERE?) can not be translated. These rules are called out in the 'rule migration summary' output.  
+ Migrates rules tags.
+ Manages POST request payload limits, 5 MB payload size (with a 5K rule limit).  TODO: confirm
+ Provides two 'write mode' options:
  + ```file```: writing write rules JSON to a local file.
  + ```api```: POSTing rules to the target system using the PowerTrack Rules API.
+ When running with ```file``` write mode, the tool will produce a set of files up to 5 MB in size and write them to the ./rules folder.   
     
## An Example of Migrating Rules from PowerTrack to the Twitter API v2 Filtered stream endpoint <a id="example" class="tall">&nbsp;</a>  
  
To help illustrate how to use this tool, we'll migrate an example PowerTrack ruleset to the Twitter API v2 Filtered stream endpoint. Our example PowerTrack ruleset consists of a variety of rules to highlight different tool functionality. These include rules that are already completely compatible with Filtered stream, along with some that contain deprecated Operators, and some that require some sort of translation before adding to Filtered stream:
   
  + Rules that are ready for Filtered stream (Note: the vast majority of rules should be in this category) 
    + "this long rule is ready for Filtere stream" (snow OR #Winning) has:profile_geo @snowman friends_count:100
    + lang:en (rain OR flood OR storm)
  
  [TODO]
  + Rules that require translation to 2.0
    + retweet_of_status_id: 
  
  + Rules with deprecated Operators (complete list of Operators with *no* replacement are included [HERE](http://where)).
    + has:profile_geo (snow OR rain)
    + profile_country:us (coffee OR tea)
    + profile_regionLcolorado (ski OR snowboard) has:media
    + profile_locality:minneapolis (motel OR hotel)
  
For this example, our version PowerTrack ```Source``` rules will be available at the following Rules API 1.0 endpoint:
   
```
https://api.gnip.com/accounts/snowman/publishers/twitter/streams/track/prod/rules.json

```
   
We'll port these rules to the following v2 Filtered stream ```Target``` endpoint:    

```
https://api.twitter.com/2/tweets/search/stream/rules

```
  
First, let's get some feedback on the readiness of this PowerTrack ruleset for Filtered stream. When you pass in the ```-r``` command-line option, the tool will run in a 'report' mode. The 'report' mode will not make any changes to your Target ruleset, and will report on how many rules are ready for 2.0, how many need translations and what the translated rules will look like, as well as how many can not be migrated to Filtered stream due to deprecated Operators with no Filtered stream equivalents. When running in 'report' mode, the tool makes a call to the rules endpoint **rule validation endpoint** and reports on any rules that fails. Since we are making a request to that endpoint, you need to specify your ```Target``` rules endpoint, even though we are not posting any rules to it. 
  
To run a rules report on our example Source system, run the tool with the ```-r``` option, along with specifying the Source rules endpoint with the ```-s Rules-API_URL``` option:
  
  ```
  $ruby rule_migrator_app.rb -r -s "https://api.gnip.com/accounts/snowman/publishers/twitter/streams/track/prod/rules.json" -t "https://api.twitter.com/2/tweets/search/stream/rules"
  
  ```
  
[TODO: stopping updates here!!!!!]  
  
  
For our example ruleset, the tool will output the following rule summary:  
   
```
  Starting process at 2016-08-11 12:55:40 -0600
  Getting rules from Source system. Making Request to Rules API...
      ... got 18 rules from Source system.
  
   ******************
  Checking 18 rules for translation...
   
  Running in 'report' mode, no changes will be made.
  
  ---------------------
  Rule Migrator summary
  
 ---------------------
 Source system:
 	Source[:url] = https://api.gnip.com:443/accounts/jim/publishers/twitter/streams/track/testv1/rules.json
 	Source system has 18 rules.
 	Source system has 3 rules ready for version 2.
 	Source system has 7 rules that were translated to version 2.
 	Source system has 5 rules that contain deprecated Operators with no equivalent in version 2.0.
    Source system has 3 rules with version 1.0 syntax not supported in version 2.0.
 
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
 3 Source rules that have version 1.0 syntax not supported in version 2.0:
    (#THIS or #THAT) and lang:en
    (this rule) or (is no longer valid)
    (this rule) AND (is no longer valid)
  
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

Now, let's go ahead and migrate this ruleset to 2.0. To do this we will remove the ```-r``` options, set the ```-w "api"``` option (write to the API, rather than write a JSON file):

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

Note that the Rule Migration tool also supports *writing the 2.0 ruleset to a JSON file*, enabling you to review them before writing them to your 2.0 system. To do this you can change the 'write mode' to 'file' with the ```-w "file"``` command-line option. 

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
    + supports all Publishers, all others are Twitter only since Gnip 2.0 is specific to Twitter endpoints/products.
  + 1.0 → 2.0 
  + 2.0 → 2.0
  
  **NOTE:** 2.0 → 1.0 migrations are not supported. 
  
+ Process can either: 
  + Add rules to the Target system using the Rules API (write_mode = 'api').
  + Output Target rules JSON to a local file for review (write_mode = 'file').  


## Getting Started  <a id="getting-started" class="tall">&nbsp;</a>

The Rule Migrator tool is written in Ruby. It is based on Ruby 2.0, and uses very vanilla gems. If you are on Linux or MacOS, it should work out-of-the-box with the Ruby environment you already have (subject to running bundler with the supplied Gem file). This code has not been tested on Windows, but it should work assuming you have a Ruby 2.0 environment installed. 

+ Get some Gnip PowerTrack streams and rule sets you need to manage!
+ Deploy client code
    + Clone this repository.
    + Using the Gemfile, run bundle. This tool used two basic gems, 'json' and 'logging'. 
+ Configure both the Accounts and Options configuration files.
    + Config ```accounts.yaml``` file with account name, username, and password.
    + Provide the details for the migration you want to perform.
     + You can provide these details in the ```options.yaml``` file, but you can also provide the details via the command-line.
     + The fundamental information you need to provide is:
      + Rules API URL of your ```Source``` system.
      + Rules API URL of your ```Target``` system.
      + Specify the ```write_mode```, either 'api' or 'file'. 
    + See the [Configuration Details](#configuration-details) section for the details.
 
+ Note for Windows installs:
  + May need to install the 'certified' gem (or add it to the Gemfile and run bundler), and add ```require 'certified'``` to the /common/restful.rb class.
  
+ To confirm everything is ready to go, you can run the following command:
    
    ```
    $ruby rule_migrator_app.rb -h
    ```
    If you see a help 'screen' with command-line options, you should be good to go.
    
### Configuration details <a id="configuration-details" class="tall">&nbsp;</a>

There are two files used to configure the Rule Migrator. The ```account.yaml``` contains your Gnip account name, username, and password. This configuration file is mandatory.

The ```options.yaml``` file contains all the application options, including the Rule API URLs of your Source and Target streams, along with logging settings. Note that all of these options (except for the app logging details) can be passed in via  [command-line parameters](#command-line-options), and any that are passed in will override any values set in the ```options.yaml``` file.

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
   write_rules_to: file          #options: file, api
   rules_folder: ./rules         #If generating rule files, where to write them.
   rules_json_to_post: ''        #JSON file (path and name) to load into Target system via Rules API.
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
    -a, --account ACCOUNT            Account configuration file (including path) that provides Gnip account details.
    -c, --config CONFIG              Settings configuration file (including path) that specify migration tool options.
    -s, --source SOURCE              Rules API URL for GETting 'Source' rules.
    -t, --target TARGET              Rules API URL for POSTing rules to 'Target' system.
    -r, --report                     Just generate rule migration report, do not make any updates.'
    -d, --directory DIRECTORY        Specify directory/folder for storing rule set JSON files. Default is './rules'.
    -w, --write WRITE                Write rules to either JSON file or POST to Target Rules API. Choices: "file" or "api".
    -f, --file FILE                  Specify a file to load into 'Target' system.
    -v, --verbose                    When verbose, output all kinds of things, each request, most responses, etc.
    -h, --help                       Display this screen.
```

## More Examples <a id="more-examples" class="tall">&nbsp;</a>

For the example use-cases listed above, here are some more examples of how to perform these rule migrations. For all these examples we are assuming that the Gnip account details are in a ```config``` subfolder and in a file called ```accounts.yaml``` (the default location and name). Remember you can specific any path and filename with the ```-a``` command-line option, as in ```$ruby rule_migrator_app.rb -a "./configurations/private_account_details.yaml```. Also, for these examples, you would replace the ```{ACCOUNT_NAME}``` token with your Gnip account name (which is case sensitive), and the ```{STREAM_LABEL}``` with the appropriate stream label (these can be set to anything, but are commonly set to 'prod' or 'dev').

+ As a real-time PowerTrack 1.0 customer, I want to know what shape my ruleset is in w.r.t. Gnip 2.0.

```
$ruby rule_migrator_app.rb -r -s "https://api.gnip.com:443/accounts/{ACCOUNT_NAME}/publishers/twitter/streams/track/{STREAM_LABEL}/rules.json" -t "https://gnip-api.twitter.com/rules/powertrack/accounts/{ACCOUNT_NAME}/publishers/twitter/{STREAM_LABEL}.json"
```

+ Before I write my rules to my ```Target``` system via the Rules API 2.0, I want to write out a JSON file containing the candidate rules (including 2.0 translations) for review. Note that by default, the tool will write to a ```./rules``` subfolder by default. You can specify a different folder with the ```-d``` (directory) command-line option, or by setting the ```rules_folder``` setting in the ```options.yaml``` file.

```
$ruby rule_migrator_app.rb 
         -w 'file' 
         -s "https://api.gnip.com:443/accounts/{ACCOUNT_NAME}/publishers/twitter/streams/track/{STREAM_LABEL}/rules.json" 
```
+ After review, I want to write the rules in that file to my ```Target``` system via the Rules API.

```
$ruby rule_migrator_app.rb -f "/my_rules_file.json" 
        -w "api" 
        -t "https://gnip-api.twitter.com/rules/powertrack/accounts/{ACCOUNT_NAME}/publishers/twitter/{STREAM_LABEL}.json"
```
 
+ Next, I want to go straight from my ```Source``` 1.0 system to my ```Target``` 2.0 system.

```
$ruby rule_migrator_app.rb 
        -w "api" 
        -s "https://api.gnip.com/accounts/{ACCOUNT_NAME}/publishers/twitter/streams/track/{STREAM_LABEL}/rules.json" 
        -t "https://gnip-api.twitter.com/rules/powertrack/accounts/{ACCOUNT_NAME}/publishers/twitter/{STREAM_LABEL}.json" 
```

+ As a real-time PowerTrack (1.0 or 2.0) customer, I want a tool to copy my 'dev' rules to my 'prod' stream.

```
$ruby rule_migrator_app.rb 
        -w "api" 
        -s "https://gnip-api.twitter.com/rules/powertrack/accounts/{ACCOUNT_NAME}/publishers/twitter/dev.json"  
        -t "https://gnip-api.twitter.com/rules/powertrack/accounts/{ACCOUNT_NAME}/publishers/twitter/prod.json" 
```

+ As a Replay customer, I want to clone my real-time rules to my Replay stream.

```
$ruby rule_migrator_app.rb 
         -w "api" 
         -s "https://gnip-api.twitter.com/rules/powertrack/accounts/{ACCOUNT_NAME}/publishers/twitter/{STREAM_LABEL}.json"            
         -t "https://gnip-stream.gnip.com/replay/powertrack/accounts/{ACCOUNT_NAME}/publishers/twitter/{STREAM_LABEL}.json
```

## PowerTrack to v2 Filtered stream Rule Translations  <a id="translations" class="tall">&nbsp;</a>

There are many PowerTrack Operator changes with 2.0. New Operators have been introduced, some have been deprecated, and some have had a grammar/name update. See [HERE](http://support.gnip.com/apis/powertrack2.0/transition.html) and [HERE](http://support.gnip.com/articles/rules-migrator.html) for more details.

When migrating 1.0 rules to 2.0, this application attempts to translate when it can, although there will be cases when the automatic translation will not be performed. For example, no version 1.0 rule which includes a deprecated Operator will be translated. In all cases, the rules that can and can not be translated are logged. 

All rule translations are encapsualated in [THIS CLASS](https://github.com/jimmoffitt/rules-migrator/blob/master/lib/rules/rule_translator.rb).


### Deprecated Operators
    
The following Operators are deprecated in v2 Filtered stream. No removal or translation will be attempted, and rules with these Operators will not be added to v2 Filtered streams.   
    
+ 
+ 





