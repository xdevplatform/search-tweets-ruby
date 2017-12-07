```
[] Add ENV credential options, move details to new Configuration class.
[] Add url option, to simply configuration? Current design makes switching APIs easier?
```

-------------------------------------

# Ruby Tweet search client

This Ruby client is written to work with the Twitter premium and enterprise versions of Tweet Search.  This client is a command-line app that supports the following features:

+ Works with:
	+ Premium Search Tweets: 30-day API
	+ Enterprise 30-Day Search API
	+ Enterprise Full-Archive API
+ Can manage an array of filters, making requests for each.
+ Returns total count for entire request period.
+ Supports flexible ways to specify search period. E.g., ```-s 7d``` specifies the past week. Other patterns such as ```YYYY-MM-DD HH:mm```, standard Twitter ISO timestamps, and the enterprise ```YYYYMMDDhhmm``` pattern are also supported.
+ Writes to files or standard out. When writing files, one file is written for every API response. File names are based on query syntax, and are serialized. (Writing to a datastore... coming soon?)
+ Can stop making requests after a specified number. If your search query and period match millions of Tweets that would require hundreds of requests, you could have the client stop after four requests by adding the ```-x 4``` argument. 
	
[Premium](https://developer.twitter.com/en/docs/tweets/search/overview/premium) and [enterprise](https://developer.twitter.com/en/docs/tweets/search/overview/enterprise) search APIs are nearly identical but have some important differences. See the linked documents for more information. 

----------------
Jump to:

+ [Getting started](#getting-started)
+ [Selecting API](#selecting-api)
+ [Example calls](#example-calls)
+ [Fundamental Details](#details)
  + [Configuring the client](#configuring)
  + [Command-line arguments](#arguments)
  + [Specifying search period start and end times](#specifying-times)
  + [Rules files](#rules)
+ [Other details](#other)
--------------------

## Getting started <a id="getting-started" class="tall">&nbsp;</a>

+ Establish access to, and authentication, for the search API of your choice. See product documentation authentication details. 
+ Clone respository.
+ bundle install. See project Gem file. Need some basic gems like 'json', 'yaml', and 'zlib'. 
+ Configure the client. Specify the search API to request from, provide API credentials, and set app options. These are stored in a configuration YAML file.
+ Review how to pass in search request options via the command-line. Search filters are specified with the ```-r``` parameter, and search period start and end times are specified with the ```-s``` and ```-e``` parameters. Some common patterns:
   + ```-r "from:TwitterDev" -s 14d``` --> Request all Tweets posted by the @TwitterDev account over the past 14 days.
   + ```-r "snow profile_region:co has:media" -s "2017-12-01 06:00" -e "2017-12-02 06:00" -x 3``` --> Request Tweets matching the specified rule, but stop after three requests. Set the search period to December 1, 2017 in the MST (UTC−6:00) timezone. This example rule translates to "match Tweets with keyword 'snow', posted by someone who calls Colorado home, and had a photo, video, or GIF attached 'natively' with Twitter app."
+ Test it out by running ```$ruby search-app.rb -h```. You should see a help menu. 
+ Make your first request: ```$ruby search-app.rb -r "from:TwitterDev -s 14d" -x 1```. 
+ Look for API JSON responses in app's standard out or outbox. 

### Other important documentation and resources:
+ Learn about building search filters: https://developer.twitter.com/en/docs/tweets/rules-and-filtering/guides/using-premium-operators
+ Review the list of premium operators: https://developer.twitter.com/en/docs/tweets/search/guides/premium-operators
+ Jump into the API references: [Premium search APIs](https://developer.twitter.com/en/docs/tweets/search/api-reference/premium-search), [Enterprise search APIs](https://developer.twitter.com/en/docs/tweets/search/api-reference/enterprise-search).

## Selecting search API <a id="selecting-api" class="tall">&nbsp;</a>

You specify target search API in the YAML configuration file (```./config/config.yaml``` by default) with the following settings:

+ ```search_type```: Set to either ```premium``` or ```enterprise```.
+ ```archive```: Set to either ```30day``` or ```fullarchive```.

+ ```environment```: Either the premium environment name you selected with the [dev portal](https://developer.twitter.com/en/dashboard), or your enterprise search label (typically 'dev' or 'prod'). 
+ ```account_name```: If an enterprise customer, this is your subscription account name (case-sensitive).

For example, if you are working with the premium 30-day search API and an environment named 'dev', the settings should be:

```
options:
  search_type: premium
  archive: 30day
  
labels:
  environment: dev
```  

If you are working with the enterprise full-archive search API, have an account name of 'ThinkSnow' and a search label of 'prod', the settings should be:

```
options:
  search_type: enterprise
  archive: fullarchive
  
labels:
  environment: prod
  account_name: ThinkSnow
```  

## Setting credentials <a id="credentials" class="tall">&nbsp;</a>

You specify credentials  in the YAML configuration file (```./config/config.yaml``` by default) with the following settings:

+ ```search_type```: Set to either ```premium``` or ```enterprise```.
+ ```archive```: Set to either ```30day``` or ```fullarchive```.

+ ```environment```: Either the premium environment name you selected with the [dev portal](https://developer.twitter.com/en/dashboard), or your enterprise search label (typically 'dev' or 'prod'). 
+ ```account_name```: If an enterprise customer, this is your subscription account name (case-sensitive).

For example, if you are working with premium APIs, your need to supply your Bearer Token in the ```app_token``` field:

```
auth:
  app_token:  AAAAA5n0w5n0w5n0wMyL0ngBe4r4rT0k4n
```  

If you are working with enterprise APIs, you need to supply your user name as the ```app_token```, and your password:

```
auth:
  app_token: username@mycompany.com  
  password: N0tMyRe4lP455w0rd
```  

## Setting Search API Endpoint

Every user of a Twitter premium or enterprise API is provided a unique URL, their own custom *endpoint*. These URLs are made unique by including one or two *tokens* that are specified by the client when setting up their account. For premium APIs this 

### Premium APIs
With premium APIs, there is one token and that is the name given the development environment set up [https://developer.twitter.com/en/dashboard](https://developer.twitter.com/en/dashboard). If you named you development environment to 'dev', then your client configuration file would look like:

```
labels:
  environment: dev   
```  

### Enterprise APIs

With enterprise APIs, there are two tokens. The first is your enterprise account name, which is established when API access is set up by Twitter (and is case-sensitive). The second is the 'label' assigned to the search endpoint, which can be thought of as a name for the environment you want to work in. Most enterprise systems operate with both development and production environments. If you were working on your production system (with a label of 'prod'), then your client configuration file would look like:

```
labels:
  environment: prod  
  account_name: myAcccountName  
```


## Example calls <a id="example-calls" class="tall">&nbsp;</a>

This command-line app supports a simple set of arguments with which the filter and search period are specified. Important application configuration details are stored in a YAML file. 

This first example illustrates how to pass in a single filter. These fiters can be 2,048 characters long. Since this call does not specify a configuration file, the app looks for one at ```./config/config.yaml```.

```$ruby ./search-app.rb -r "snow profile_region:colorado has:media"```

The following call specifies a non-default configuration file, and illustrates one of several time 'helper' formats.

```$ruby ./search-app.rb -c "./config/my_config.yaml" -r "snow has:video -s 14d```

The following call illustrates how to make a 'counts' request with the -l parameter ("l" is for "look before you leap") and passing in a rule JSON file (YAML format also supported). These rules files can contain multiple rules. 

```$ruby ./search-app.rb -c "./config/my_config.yaml" -r "./rules/my_curated_rule.json" -s 12h``` -l


## Fundamental details <a id="details" class="tall">&nbsp;</a>

### Configuring the client <a id="configuring" class="tall">&nbsp;</a>

This client relies on a YAML configuration file for some fundamental settings, such as the search API you are working with. This file also contains your credentials for authenticating with your search API of choice.

By default, this file has a path of ```./config/config.yaml```. You can overwrite this default with the ```-c``` command-line option.

Here are the default configuration settings with descriptions of each option:

```
#Client options.
options:
  search_type: premium # or enterprise
  archive: 30day # or fullarchive
  write_mode: standard-out # options: files, so/standard/standard-out --> Store activities in local files or print to system out?
  out_box: ./output # Folder where retrieved data goes.
  counts_to_standard_out: true # Always write 'counts' endpoint responses to standard out. Force to file with '-w' option.

#Credentials.
auth:
  app_token:  #Either enterprise username or premium app-only bearer token.
  password:   #Enterprise only.
  
#Labels used for endpoint URL. Client generates URL with these.  
labels:
  environment: dev   #Premium environment name or enterprise endpoint 'label'.
  account_name:      #Enterprise only. 

```




### Command-line arguments <a id="arguments" class="tall">&nbsp;</a>

Once you have the configuration file set up, you can start making requests. Search API request parameters (identical across all premium and enterprise APIs) are specified as arguments via the command line. 

[] TODO: update anchors.
For making Tweet requests ('data') see our request parameter documentation [HERE](https://developer.twitter.com/en/docs/tweets/search/api-reference/enterprise-search).
For making *number of Tweets* ('counts') see our request parameter documentation [HERE](https://developer.twitter.com/en/docs/tweets/search/api-reference/enterprise-search).

#### Command-line options:

```
Usage: search-app [options]
    -c, --config CONFIG              Configuration file (including path) that provides account and option selections.
                                       Config file specifies which search api, includes credentials, and sets app options.
    -r, --rule RULE                  Rule details (maps to API "query" parameter).  Either a single rule passed in, or a file containing either a
                                   YAML or JSON array of rules.
    -t, --tag TAG                    Optional. Gets included in the  payload if included. Alternatively, rules files can contain tags.
    -s, --start_date START           UTC timestamp for beginning of Search period (maps to "fromDate").
                                         Specified as YYYYMMDDHHMM, \"YYYY-MM-DD HH:MM\", YYYY-MM-DDTHH:MM:SS.000Z or use ##d, ##h or ##m.
    -e, --end_date END               UTC timestamp for ending of Search period (maps to "toDate").
                                      Specified as YYYYMMDDHHMM, \"YYYY-MM-DD HH:MM\", YYYY-MM-DDTHH:MM:SS.000Z or use ##d, ##h or ##m.
    -m, --max MAXRESULTS             Specify the maximum amount of data results (maps to "maxResults").  10 to 500, defaults to 100.
    -l, --look                       "Look before you leap..."  Triggers the return of counts only via the "/counts.json" endpoint.
    -d, --duration DURATION          The "bucket size" for counts, minute, hour (default), or day. (maps to "bucket")
    -x, --exit EXIT                  Specify the maximum amount of requests to make. "Exit app after this many requests."
    -w, --write WRITE                'files', 'standard-out' (or 'so' or 'standard'), 'store' (database)
    -o, --outbox OUTBOX              Optional. Triggers the generation of files and where to write them.
    -z, --zip                        Optional. If writing files, compress the files with gzip.
    -h, --help                       Display this screen.
```

### Specifying search period start and end times <a id="specifying-times" class="tall">&nbsp;</a>

By default the premium and enterprise search APIs will search from the previous 30 days. However, most search requests will have a more specific period of interest. With these search APIs the start of the search period is specified with the ```fromDate``` parameter, and the end with ```toDate``` request parameter. 

Both timestamps assume the UTC timezone. If you are making search requests based on a local timezone, you'll need to convert these timestamps to UTC. These search APIs require these timestamps to have the 'YYYYMMDDHHMM' format. As that format suggests, search request periods can have a minute granularity. 

This client uses the 'start' and 'end' aliases for ```fromDate``` and ```toDate``` parameters, and supports additional timestamp formats.

Start ```-s``` and end ```-e``` parameters can be specified in a variety of ways:

+ Standard search API format, YYYYMMDDHHmm (UTC)
	+ -s 201602010700 --> Metrics starting 2016-02-01 00:00 MST, ending 30 days later.
	+ -e 201602010700 --> Metrics ending 2016-02-01 00:00, starting 30 days earlier.
+ "YYYY-MM-DDTHH:MM:SS.000Z" (ISO 8061 timestamps as used by Twitter, in UTC)
	+ -s 2017-11-20T15:39:31.000Z --> Tweets posted since 2017-11-20 22:00:00 MST .
+ A combination of an integer and a character indicating "days" (#d), "hours" (#h) or "minutes" (#m). Some examples:
	+ -s 7d --> Start seven days ago (i.e., Tweets from the last week).
	+ -s 14d -e 7d --> Start 14 days ago and end 7 days ago (i.e. Tweets from the week before last).
	+ -s 6h --> Start six hours ago (i.e. Tweets from the last six hours).

+ "YYYY-MM-DD HH:mm" (UTC, use double-quotes please).
	+ -s "2017-11-04 07:00" -e "2017-11-07 07:00" --> Tweets from between 2017-11-04 and 2017-11-06 MST.

### Rules files <a id="rules" class="tall">&nbsp;</a>

Search API requests are based on a single rule or filter. When making requests for a single rule, that rule is passed in via the copmmadn-line with the ```-r``` argument. 

However, this client supports making requests with multiple rules, managing the data retrieval for each individual rule. Multiple rules can be specified in JSON or YAML files.  Below is an example of each. 

JSON rules file:

```json
{
  "rules" :
    [
        {
          "value" : "snow colorado",
          "tag" : "ski_biz"
        },
        {
          "value" : "snow utah",
          "tag" : "ski_biz"
        },
        {
          "value" : "rain washington",
          "tag" : "umbrellas"
        }
    ]
}
```

YAML rules file:

```yaml
rules:
  - value  : "snow colorado"
    tag    : ski_biz
  - value  : "snow utah"
    tag    : ski_biz
  - value  : "rain washington"
    tag    : umbrellas
```

For example, you can pass in a JSON rules file located at ./rules/my-snow-rules.json with the following argument:

```$ruby search_app.rb -r "./rules/my-snow-rules.json" -s 7d" -x 1```  


## Other details <a id="other" class="tall">&nbsp;</a>

This third iteration is based on a previous version developed for the enterprise full-archive search API. That client was in turn based on the initial example developed for the enterprise 30-day search API.


### Updates 

This iteration has the following updates from the [full-archive version](https://github.com/gnip/gnip-fas-ruby):

+ Iterated HTTP class to handle Bearer token authentication.
  + Supports two flavors of Auth: Basic, Bearer App-only
+ ```/counts.json``` requests default to standard out. Must explicitly request to write count responses to a file. Typical workflow is to repeatedly assess queries by making count requests, then switching to the 'data' endpoint when ready. These exploratory count responses typically do not need to be saved, yet the data definitely does. 
+ ```so``` = ```standard_out``` -- adding a shortcut for switching write mode to 'standard out.'
+ Added a ```/common/utilities.rb``` mix-in module that provides simple general tools. Many are time object formatters... 

### Next
+ Stubs for data store writing
  + Reference a ```/common/datastore.rb``` class that marshals Tweets to a datastore: relational db, NoSQL, queue.
  + Add in queuing system, with timed clean-up? E.g., dropped every 15-minutes. 
+ Drops support for Activity Stream Tweet JSON format? Yes, if only to clean-up for blending in TweetParser class that holds all the logic. 
+ New common classes?: logging has been abstracted away into a [AppLogger](https://github.com/twitterdev/engagement-api-client-ruby/blob/master/common/app_logger.rb) class. Haven't plugged into this client yet... 














