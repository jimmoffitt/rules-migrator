# Migrating PowerTrack 1.0 Rules to 2.0

### Introduction

As announced last [date], a new version of Gnip's real-time PowerTrack is [in the works]. Everyone using real-time. PowerTrack will need to migrate their filtering rules from their version 1.0 systems over to version 2.0 systems. 

This process is pretty  straightforward, although there are some nuanes. Moving to 2.0 provides new methods for matching on Tweets of interest. More filtering metadata on linked URLs is available. There is also new ways to fine-tune what media is linked to in Tweets. Are you only interested only in videos or photos? Now you can be more specific...

This article discusses several topics related to that effort:

+ New PowerTrack Operators.
+ Changes in PowerTrack Operators.
+ Updates to the Rules API.
+ Writing code for the Rules API.
+ Example "Rules Migrator" application.   
 

    
### Changes in PowerTrack Operators  

PowerTrack 2.0 introduces a variety of changes to the Operators available for filtering Tweets of interest from the firehose. First, PowerTrack 2.0 introduces a set of new Operators, including emoji filterings, new expanded URL enrichments, and the ability to fine-tune media matching with Operators such as has:video and has:photo. See [HERE] for a complete list of what's new.

Other changes include updates in simple grammar and language classification details, as well as a set of Operators that are being deprecated. 

##### New Operators

##### Grammar Updates

A few PowerTrack Operators are changing only in name:

+ ```country_code``` --> ```place_country```
+ ```profile_country_code``` --> ```profile_country```
 
So, if you have any rules that use these Operators, rule syntax updates will be necessary. 


##### Tweet Language Operator Updates

In PowerTrack 1.0, there was two different language classification systems and corresponding Operators. Gnip first introduced its language classification and the ```lang:``` Operator in March, 2012. Twitter launched its language classification in [DATE?], and the ```twitter_lang:``` Operator was introduced to PowerTrack. The Twitter language classification handles many more languages, and also indicates when a language was could not be identified. 

As with all Gnip 2.0 products (along with [Full-Archive Search](http://support.gnip.com/apis/search_full_archive_api/)), PowerTrack 2.0 supports only the Twitter language classification. Since there is only one classification source now, there is only one PowerTrack Operator, ```lang:```. 

As noted below in the next section, the version 1.0 ```has:geo``` is being deprecated. With PowerTrack 2.0, this Operator is replaced with the ```-lang:und``` negation clause (indicating that a language classification was made).

##### Deprecated Operators

As documentated [HERE], some Operators are being deprecated, partly due to lack of use.

[TODO]
        
        
### Updates to the Rules API   

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
 

### Writing code for the Rules API.

Many reasons to do so... Synching systems... between your system and Gnip's. Between real-time and Replay streams. Or, 
as in an upcoming example, migrating 1.0 rules to a 2.0 stream.  

#### Fundamentals

The Rules API is a RESTful API used to manage PowerTrack real-time filters. It supports a small set of methods used to 
list, add and delete rules. 

##### Loading rules from PowerTrack

##### Posting rules to PowerTrack


### Example 'Rule Migrator' Application

As a group focused on supporting Gnip customers, we are avid 'in-house' users of real-time PowerTrack. As a developer advocate I get to write and code about data stories, and have curatored many sets of operators that often have a greographic focus. So I sat down to write a tool that could help us translate and migrate PowerTrack 1.0 rules to version 2.0. The following sections discuss developing and working with this tool.

This tool is very much a prototype, a 'talking point' in the broader discussion of filtering the firehose with PowerTrack. If you improve or extend or refactor, or whatever, this code base, please share your efforts.

[https://github.com/jimmoffitt/rules-migrator]

### Rule Translations

###Rule Migrations


Examples:

+ Realtime 1.0 to 2.0
+ Real-time to Replay streams
+ Tumblr dev to prod stream







