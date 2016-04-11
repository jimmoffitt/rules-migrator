# Migrating PowerTrack Rules from Version 1.0 to 2.0

### Introduction

A new version of Gnip's real-time PowerTrack, version 2.0, is in the works. Everyone using real-time PowerTrack version 1.0 will need to migrate their filtering rules over to version 2.0 in the near future. 

This process is pretty straightforward, although there are many details to consider. PowerTrack 2.0 is the new platform for new features and enhancements. Moving to 2.0 provides [new PowerTrack Operators](http://support.gnip.com/apis/powertrack2.0/transition.html#NewOperators) for matching on Tweets of interest. For example, more URL metadata is available such as the web site HTML Titles and Descriptions. There are also new ways to fine-tune what media is linked to in Tweets. Are you only interested only in videos or photos? Now you can be more specific. Not to mention that you can now filter and match on emojis. 

Beyond [new Operators](#new_operators), there are other rule changes introduced with PowerTrack 2.0:

+ Only 'long' rules, with 2,048 characters, are supported.
+ Gnip ```matching_rules``` array are provided in both 'original' and Activity Stream formats. 
+ All [language classifications](#language_operators) are supplied by a Twitter system, and the Gnip language enrichment is being deprecated.
+ With hopes of providing a more logical grammar, some [Operators have changed in name only](#grammar_updates).
+ Some Operators have been [deprecated](#deprecated_operators).

This article discusses several topics related to moving to PowerTrack version 2.0:

+ [Changes in PowerTrack Operators](#operator_changes).
+ [Updates to the Rules API](#rules_api_changes).
+ [Example "Rules Migrator" application](#rule_migrator).   
 
### Changes in PowerTrack Operators <a id="operator_changes" class="tall">&nbsp;</a>

PowerTrack 2.0 introduces a variety of changes to the Operators available for filtering Tweets of interest from the firehose. First, PowerTrack 2.0 introduces a set of new Operators, including the ability to match on emojis, new expanded URL enrichments, and the ability to fine-tune media matching with Operators such as has:videos and has:images. See [HERE](http://support.gnip.com/apis/powertrack2.0/overview.html#NewFeatures) for a complete list of what's new.

Other changes include updates in simple grammar and language classification details, as well as a set of Operators that are being deprecated. 

#### New Operators <a id="new_operators" class="tall">&nbsp;</a>

PowerTrack 2.0 introduces several new Operators and is the platform for future additions. See [HERE]((http://support.gnip.com/apis/powertrack2.0/transition.html#NewOperators)) for the list of new Operators.

The focus of this article, and the [migration tool](#rule_migrator), is how to migrate existing version 1.0 rules to 2.0. While these new Operators are not part of the rule translation discussion, incorporating the new Operators should be considered as you migrate to version 2. Based on the types of matching you are performing with version 1.0, here are some examples of filtering mechanisms that will likely benefit from these new Operators:

+ If your rules use the ```url_contains:``` Operator you'll probably want to consider using the new ```url_title:``` and ```url_description:``` Operators. These new Operators enable you to dig a bit deeper into the included link to match on more than just tokens and patterns of the URL. The URL itself may not hint at the subject of the linked to web page, and now with these Operators you can match the web page title and description.   
+ The ```has:media``` Operator operates on both native photos and videos. With version 2.0, you can make a distinction between these two media types with the ```has:videos``` and ```has:images``` Operators. 
+ If you are matching on cashtags (e.g. $TWTR) with version 1.0, you needed to make a choice between matching with quoted phrases ("\$CashTag\") or keyword-type ($CashTag) rule clauses. With version 2.0 there is a cashtag ($) Operator that provides the definitive method for cashtags that are included in the Tweet message. These cashtag entities are parsed from the Tweet body and placed in the ```twitter_entities:symbols``` JSON attribute. In this way, the new cashtag Operator is completely analogous to the hashtag Operator.     

#### Language Operator Changes <a id="language_operators" class="tall">&nbsp;</a>
 
PowerTrack 1.0 supported two language classifications: the Gnip classification with the ```lang:``` Operator, and the Twitter classification with the ```twitter_lang:``` Operator. With PowerTrack 2.0, the Gnip language enrichment is being deprecated, and there will be a single ```lang:``` Operator powered by the Twitter system. The Twitter classification supports 40 (!) more languages, assigns a ```und``` (undefined) when no classification can be made (e.g., Tweets with only emojis and URLs), and in some cases is more accurate. 

If you have version 1.0 rules based on language classifications, here are some rule translation details to consider:

+ Since the Twitter system handles all the Gnip languages, and uses the same language codes, you can safely convert all ```twitter_lang:``` operators to ```lang:```.
  + Probably the most common pattern in rules that reference both systems is an OR clause with a common language code, such as:
      ```(lang:es OR twitter_lang:es)```
    When migrating to version 2.0, the equivalent rule clause is ```lang:es```
    
  + Another common pattern is requiring both systems to agree on the language classification:
      ```(lang:es twitter_lang:es)```  
    When migrating to version 2.0, the equivalent rule clause is ```lang:es```

  + Some use-cases are helped by knowing whether the Tweet has a language classification, while there is no need to know (at the filtering level) what the language is.
    + With PT 1.0, there was the ```has:lang``` rule clause to determine whether a classification is available
         ```has:lang (snow OR neige OR neve OR nieve OR snö OR снег)``` 
    + With PT 2.0, there is the ```-lang:und``` rule clause to do the same thing. 
        ```-lang:und (snow OR neige OR neve OR nieve OR snö OR снег)``` 

 + Another common pattern is specifying a specific language or matching on Tweets that could not be classified:
    + Here is a PT 1.0 example of that:  ```(-has:lang OR lang:en OR twitter_lang:en) (snow OR rain OR flood)```
    + When migrating to version 2.0, the equivalent rule clause is  ```(lang:und OR lang:en) (snow OR rain OR flood)```

#### Grammar Updates <a id="grammar_updates" class="tall">&nbsp;</a>

These PowerTrack Operators are changing only in name:

+ ```country_code``` → ```place_country```
+ ```profile_country_code``` → ```profile_country```
 
So, if you have any rules that use these Operators, a simple Operator replacement is necessary. 

+ The version 1.0 rule clause  ```(country_code:us OR profile_country_code:us)``` becomes ```(place_country:us OR profile_country:us)``` with version 2.0.

#### Deprecated Operators <a id="deprecated_operators" class="tall">&nbsp;</a>

As documented [HERE](http://support.gnip.com/apis/powertrack2.0/transition.html#DeprecatedOperators), some Operators are being deprecated, partly because they were never widely adopted.

If your rule set includes any of the following Operators, those clauses will need to be removed since there is no equivalent Operator in version 2.0:

+ ```klout_topic:```
+ ```klout_topic-contains:```
+ ```bio_lang```
+ ```has:profile_geo_region```*
+ ```has:profile_geo_subregion```*
+ ```has:profile_geo_locality```*
       
`* Note that ```has:profile_geo``` is still supported in version 2.0. 

There are another set of deprecated version 1.0 Operators where the filtering/matching behavior can be approximated by similar, alternate Operators. This group is made up of *substring* matching Operators that are being replaced by *token-based* Operators:

+ ```bio_location_contains:``` → ```bio_location:```
+ ```place_contains:``` → ```place:```
+ ```profile_region_contains:``` → ```profile_region:```
+ ```profile_locality_contains:``` → ```profile_locality:```
+ ```profile_subregion_contains:``` → ```profile_subregion:```
+ ```bio_name_contains:``` → ```bio_name:```
+ ```bio_contains:``` →  ```bio:```
 
So, any use of ```*_contains:``` Operators should be replaced with the non-contains version.
 
We have found that very few customers are using these Operators to match on substrings, but rather are in fact filtering on complete tokens. Therefore we anticipate that the vast majority of PowerTrack users will be able to use the replacement Operators without affecting current matching behavior. 

If you are using a quoted phrase, the translation is simply an Operator replacement. For example, the rule ```bio_contains:"software developer"``` would translate to ```(bio:"software developer")```. 

If on the off chance that you are using any of these Operators with a *substring*, you will need to rewrite the rule and attempt to match on the multiple complete tokens or quoted phrases you want to match. For example, the rule of ```Boulder bio_location_contains:co``` could become ```Boulder (bio_location:co OR bio_location:colo OR bio_location:colorado)```.

### Updates to the Rules API <a id="rules_api_changes" class="tall">&nbsp;</a>  

Along with PowerTrack Operator updates, there are some important new features arriving with version 2.0 of the Rules API. 

#### Request payload sizes
 
When adding rules to PowerTrack, JSON objects are POSTed to the Rules API. The Rules API limits the size of these JSON 
payloads. Rules API 1.0 has a data request payload size limit of 1 MB. With Rules API 2.0, the data request can be up to 
5 MB. 
 
#### Rule IDs 

With version 1.0 a 'rule' has two attributes: ```value``` and ```tag```. The ```value``` attribute contains the syntax of the rule, while the ```tag``` is a user-specified string used to either provide a universally-unique ID (UUID) (considered a best practice, btw), or a tag/label to logically group rules (e.g., "rule related to weather projects").
  
PowerTrack 2.0 introduces a new rule attribute, a primary key ```id```, which is auto-generated when a rule is created. Unique Rule IDs are important since with PowerTrack 2.0 only rule IDs and tags are included in the ```gnip.matching_rules``` metadata. (Note that is similar to version 1 'long' rules behavior with only rule tags included.) PowerTrack 2.0 supports only 'long' rules, so the rule syntax (or the rule ```value```) is not returned in the matching rule array. Since the rule syntax is not returned, it is important to have a unique ```id``` so the rule syntax can be looked up on the client-side. 

Since this new ```id``` serves as an UUID, the rule *tag* no longer needs to play that role. Rule tags remain optional, but can be a convenient mechanism to logically group rules into sets, or add other metadata to a rule object. Example uses of rule tags is to group rules by project, campaign or client. 

Here is an example of the new matching rules metadata that is included with all Tweets:

```
{
  "gnip": {
    "matching_rules": [
      {
        "tag": "Weather monitoring project",
        "id": 714923996685316096
      },
      {
        "tag": "Weather monitoring project",
        "id": 714928183628271616
      },
      {
        "tag": "Smart Cities project",
        "id": 713928144542271723
      }
    ]
  }
}
```

#### Rule Validation Endpoint

PowerTrack 2.0 provides a rule validation endpoint: 
 
 ``` https://gnip-api.twitter.com/rules/powertrack/accounts/<accountName>/<streamLabel>/validation.json ```
 
This endpoint enables you to submit candidate rules and check whether the rule has valid syntax or not. 
 
### Example 'Rule Migrator' Application <a id="rule_migrator" class="tall">&nbsp;</a>

As a group focused on supporting Gnip customers, we are avid 'in-house' users of real-time PowerTrack. As developer advocates we work directly with Twitter data and often [write data stories](https://blog.gnip.com/tweeting-rain-part-4-tweets-2013-colorado-flood/). As a result we have curated many sets of operators that often have a geographic focus. So I sat down to write a tool that could help us translate and migrate PowerTrack 1.0 rules to version 2.0. The [Rules Migrator]([https://github.com/jimmoffitt/rules-migrator]) tool is very much a prototype, a 'talking point' in the broader discussion of filtering the firehose with PowerTrack. If you improve or extend or refactor, or whatever, this code base, please share your efforts.

[https://github.com/jimmoffitt/rules-migrator]






###### ----------

### Writing code for the Rules API <a id="writing_code" class="tall">&nbsp;</a>

All real-time PowerTrack customers need to integrate with the Rules API. While the Gnip Console provides a Rules API user-interface, it is not intended for production systems, and is instead provided to enable new customers to quickly create some rules in order to start receiving real-time data. This Rules user-interface does not support the entry or display of rule ```tags``` or ```ids```. It also will not display rules if you have more than 1,000 rules (and the vast majority of PowerTrack users have more than 1,000 rules). 



Many reasons to do so... Synching systems... between your system and Gnip's. Between real-time and Replay streams. Or, 
as in an upcoming example, migrating 1.0 rules to a 2.0 stream.  

The Rules API is a RESTful API used to manage PowerTrack real-time filters. It supports a small set of methods used to 
list, add and delete rules. 





