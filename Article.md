# Migrating PowerTrack 1.0 Rules to 2.0

## Introduction

As announced last [date], a new version of Gnip's real-time PowerTrack is [in the works]. Everyone using real-time 
PowerTrack will need to migrate their filtering rules from their version 1.0 systems over to version 2.0 systems. This 
article discusses several topics related to that effort:

+ Changes in PowerTrack Operators.
+ Updates to the Rules API.
+ Writing code for the Rules API.
    + Fundamentals.
    + Example "Rules Migrator" application.   
    
## Changes in PowerTrack Operators  

### Changes in grammar

### Changes in language Operators

### Deprecated Operators
        
        
## Updates to the Rules API   

### Request payload sizes
 
When adding rules to PowerTrack, JSON objects are POSTed to the Rules API. The Rules API limits the size of these JSON 
payloads. Rules API 1.0 has a data request payload size limit of 1 MB. With Rules API 2.0, the data request can be up to 
5 MB. 
 
### Rule IDs 

With version 1.0 a 'rule' has two attributes: 'value' and 'tag'. The value attribute contains the syntax of the rule, 
while the 'tag' is a user-specified string used to provide a UUID (considered a best practice, btw), or a tag/label to 
logically group rules (e.g., 'rule related to weather projects').
  
PowerTrack 2.0 introduces a new rule attribute, a primary key ID generated when rule is created.
      
 
### Rule Validation
 

## Writing code for the Rules API.

Many reasons to do so... Synching systems... between your system and Gnip's. Between real-time and Replay streams. Or, 
as in an upcoming example, migrating 1.0 rules to a 2.0 stream.  

### Fundamentals

The Rules API is a RESTful API used to manage PowerTrack real-time filters. It supports a small set of methods used to 
list, add and delete rules. 

#### Loading rules from PowerTrack

#### Posting rules to PowerTrack




### Example 'Rule Migrator' Application

[https://github.com/jimmoffitt/rules-migrator]







