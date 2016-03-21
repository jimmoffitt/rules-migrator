# Migrating PowerTrack 1.0 Rules to 2.0

### Introduction

As announced last [date], a new version of Gnip's real-time PowerTrack, version 2.0, is [in the works]. Everyone using real-time PowerTrack will need to migrate their filtering rules from their version 1.0 systems over to version 2.0. 

This process is pretty straightforward, although there are some nuances. First, moving to 2.0 provides new methods for matching on Tweets of interest. For example, more filtering metadata on linked URLs is available such as the web site HTML Titles and Descriptions. There is also new ways to fine-tune what media is linked to in Tweets. Are you only interested only in videos or photos? Now you can be more specific. Not to mention that you can now filter and match on emojis. Then there are a number of other 2.0 PowerTrack Operator updates. A few Operators have changed only in name, while others have been deprecated. Finally, there are updates related to language classification.

This article discusses several topics related to that effort:

+ [Changes in PowerTrack Operators](#operator_changes).
+ [Updates to the Rules API](#rules_api_changes).
+ [Writing code for the Rules API](#writing_code).
+ [Example "Rules Migrator" application](#rule_migrator).   
 
### Changes in PowerTrack Operators <a id="operator_changes" class="tall">&nbsp;</a>

PowerTrack 2.0 introduces a variety of changes to the Operators available for filtering Tweets of interest from the firehose. First, PowerTrack 2.0 introduces a set of new Operators, including emoji filterings, new expanded URL enrichments, and the ability to fine-tune media matching with Operators such as has:video and has:photo. See [HERE] for a complete list of what's new.

Other changes include updates in simple grammar and language classification details, as well as a set of Operators that are being deprecated. 

##### New Operators 

PowerTrack 2.0 introduces several new Operators and is the platform for future additions. See [HERE](http://support.gnip.com/apis/powertrack2.0/overview.html#NewFeatures) for the list of new Operators.

The focus of this article, and the [migration tool](#rule_migrator), is how to migrate existing version 1.0 rules to 2.0. While these new Operators are not part of the rule translation discussion, incorporating the new Operators should be considered as you migrate to version 2. Based on the types of matching you are performing with version 1.0, here are some examples of filtering mechanisms that will likely benefir from these new Operators:

+ If your rules use the ```url_contains``` Operator you'll probably want to consider using the new ```url_title``` and ```url_description``` Operators. These new Operators enable you to dig a bit deeper into the included link to match on more than just tokens and patterns of the URL.   
+ The ```has:media``` Operator operators on both native photos and videos. With version 2.0, you can make a distriction between these two media types with the ```has:videos``` and ```has:images``` Operators. 
+ If you are matching on cashtags with version 1.0, you needed to make a choice between matching with quoted phrases ("\$CashTag\") or keyword-type ($CashTag) rule clauses. With version 2.0 there is a cashtag Operator that provides the definitive method for cashtags that part of the Tweet body. These cashtag entities are parsed from the Tweet body and placed in the ```twitter_entities:symbols``` JSON attribute. In this way, the new cashtag Operator is completely analagous to the hashtag Operator.     

##### Grammar Updates

These PowerTrack Operators are changing only in name:

+ ```country_code``` --> ```place_country```
+ ```profile_country_code``` --> ```profile_country```
 
So, if you have any rules that use these Operators, rule syntax updates will be necessary. 

##### Tweet Language Operator Updates

In PowerTrack 1.0, there were two different language classification systems and corresponding Operators. Gnip first introduced its language classification and the ```lang:``` Operator in March, 2012. Twitter launched its language classification in [DATE?], and the ```twitter_lang:``` Operator was introduced to PowerTrack. The Twitter language classification handles many more languages, and also indicates when a language was could not be identified by assigning a 'und' result. 

As with all Gnip 2.0 products (along with [Full-Archive Search](http://support.gnip.com/apis/search_full_archive_api/)), PowerTrack 2.0 supports only the Twitter language classification. Since there is only one classification source now, there is only one PowerTrack Operator, ```lang:```. 

Since the Twitter classifications cover *all* of the Gnip languages, and use the identical two-character codes, all ```lang:``` version 1.0 rule clauses will translate smoothly to version 2.0. Since the introduction of the Twitter classification, many PowerTrack users have introduced the ```twitter_lang:``` Operator to their rule set. When moving to version 2.0, these rule clauses need to be re-written as ```lang:```.

As noted below in the next section, the version 1.0 ```has:geo``` is being deprecated. With PowerTrack 2.0, this Operator is replaced with the ```-lang:und``` negation clause (indicating that a language classification was made).

##### Deprecated Operators

As documentated [HERE](), some Operators are being deprecated, partly because they were never widely adopted.

If your rule set includes any of the following Operators, those clauses will need to be removed since there is no equivalent Operator in version 2.0:

+ ```klout_topic:```
+ ```klout_topic-contains:```
+ ```bio_lang```
+ ```has:profile_geo_region```
+ ```has:profile_geo_subregion```
+ ```has:profile_geo_locality```

There are another set of deprecated version 1.0 Operators where the filtering/matching behavior can be approximated by alternate version Operators. This set is comprise of all of the ```*_contains:``` Operators, and should be replaced with the non-contains version:

+ ```bio_location_contains:``` --> ```bio_location:```
+ ```place_contains:``` --> ```place:```
+ ```profile_region_contains:``` --> ```profile_region:```
+ ```profile_locality_contains:``` --> ```profile_locality:```
+ ```profile_subregion_contains:``` --> ```profile_subregion:```
+ ```bio_name_contains:``` --> ```bio_name:```
+ ```bio_contains:``` -->  ```bio:```
 
We have found that very few customers are using these Operators to match on substrings, but rather are in fact filtering on complete tokens. Therefore we anticipate that the vast majority of PowerTrack users will be able to use the replacement Operators without changing current matching behavior. If you are using a quoted phrase, you will need to break you the clause into separate tokens. For example,
the rule ```bio_contains:"software developer"``` would translate to ```(bio:software bio:developer)```. If on the off chance that you are using any of these Operators with a substring, you will need to rewrite the rule and attempt to match on the multiple complete tokens you want to match. For example, instead of ```Boulder bio_location_contains:co``` could become ```Boulder (bio_location:co OR bio_location:colo OR bio_location:colorado```.

### Updates to the Rules API <a id="rules_api_changes" class="tall">&nbsp;</a>  

Along with PowerTrack Operator updates, there are some important new features arriving with version 2.0 of the Rules API. 

#### Request payload sizes
 
When adding rules to PowerTrack, JSON objects are POSTed to the Rules API. The Rules API limits the size of these JSON 
payloads. Rules API 1.0 has a data request payload size limit of 1 MB. With Rules API 2.0, the data request can be up to 
5 MB. 
 
#### Rule IDs 

With version 1.0 a 'rule' has two attributes: 'value' and 'tag'. The value attribute contains the syntax of the rule, 
while the 'tag' is a user-specified string used to provide a UUID (considered a best practice, btw), or a tag/label to 
logically group rules (e.g., 'rule related to weather projects').
  
PowerTrack 2.0 introduces a new rule attribute, a primary key ID generated when rule is created.
    
#### Rule Validation
 
 https://gnip-api.twitter.com/rules/powertrack/accounts/<accountName>/<streamLabel>/validation.json


### Writing code for the Rules API <a id="writing_code" class="tall">&nbsp;</a>

Many reasons to do so... Synching systems... between your system and Gnip's. Between real-time and Replay streams. Or, 
as in an upcoming example, migrating 1.0 rules to a 2.0 stream.  

The Rules API is a RESTful API used to manage PowerTrack real-time filters. It supports a small set of methods used to 
list, add and delete rules. 


### Example 'Rule Migrator' Application <a id="rule_migrator" class="tall">&nbsp;</a>

As a group focused on supporting Gnip customers, we are avid 'in-house' users of real-time PowerTrack. As a developer advocate I get to write and code about data stories, and have curatored many sets of operators that often have a greographic focus. So I sat down to write a tool that could help us translate and migrate PowerTrack 1.0 rules to version 2.0. The following sections discuss developing and working with this tool.

This tool is very much a prototype, a 'talking point' in the broader discussion of filtering the firehose with PowerTrack. If you improve or extend or refactor, or whatever, this code base, please share your efforts.

[https://github.com/jimmoffitt/rules-migrator]

### Rule Translations

###Rule Migrations


Examples:

+ Realtime 1.0 to 2.0
+ Real-time to Replay streams
+ Tumblr dev to prod stream







