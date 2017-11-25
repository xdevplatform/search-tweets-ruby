# Ruby Tweet search API client

This Ruby client is written to work with the Twitter premium and enterprise versions of Tweet Search.  This client is a command-line app that supports the following features:

+ Can manage an array of filters, making requests for each.
+ Returns total count for entire request period.`
+ Flexible ways to specify search period. E.g., -s 7d specifies the past week.
+ Writes to files or standard out. 
+ Works with:
	+ Premium Search Tweets: 30-day API
	+ Enterprise 30-Day Search API
	+ Enterprise Full-Archive API



+ [Getting started](#getting-started)
+ [Example calls](#example-calls)
+ [Details](#details)
  + [Configuring the client](#configuring)
  + [Command-line arguments](#arguments)
  + [Specifying search period start and end times](#specifying-times)
  + [Rules files](#rules)
+ [Other details](#other)


## Getting started <a id="getting-started" class="tall">&nbsp;</a>

+ Establish access to, and authentication, for the search API of your choice. See product documentation authentication details. 
+ Clone respository.
+ bundle install. See project Gem file. Need some basic gems like 'json', 'yaml', and 'zlib'. 
+ Configure the config.yaml.
+ Test it out by running ```$ruby search_app.rb -h```. You should see a help menu. 
+ Make your first request: ```$ruby search_app.rb -r "from:TwitterDev -s 14d"```. Look for API JSON responses in app's standard out or outbox. 

Other important documentation and resources:
+ Learn about building search filters: https://developer.twitter.com/en/docs/tweets/rules-and-filtering/guides/using-premium-operators
+ Jump into the API references: [Premium search APIs](https://developer.twitter.com/en/docs/tweets/search/api-reference/premium-search), [Enterprise search APIs](https://developer.twitter.com/en/docs/tweets/search/api-reference/enterprise-search) .


## Example calls <a id="example-calls" class="tall">&nbsp;</a>

This command-line app supports a simple set of arguments with which the filter and search period are specified. Important application configuration details are stored in a YAML file. 

This first example illustrates how to pass in a single filter. These fiters can be 2,048 characters long. Since this call does not specify a configuration file, the app looks for one at ```./config/config.yaml```.

```$ruby ./search-app.rb -r "snow profile_region:colorado has:media"```

The following call specifies a non-default configuration file, and illustrates one of several time 'helper' formats.

```$ruby ./search-app.rb -c "./config/my_config.yaml" -r "snow has:video -s 14d```

The following call illustrates how to make a 'counts' request with the -l parameter ("l" is for "look before you leap") and passing in a rule JSON file (YAML format also supported). These rules files can contain multiple rules. 

```$ruby ./search-app.rb -c "./config/my_config.yaml" -r "./rules/my_curated_rule.json" -s 12h``` -l


## Details <a id="details" class="tall">&nbsp;</a>


### Configuring the client <a id="configuring" class="tall">&nbsp;</a>

{{{{{ To start making search requests you will need to configure the client's configuration file. This file specifies what search API it should make requests from (it supports 4 versions), and stores settings for many important details such as authentication and file handling.



```
options:
  search: premium #or enterprise
  archive: 30day
  write_mode: standard-out #options: files, datastore, so/standard/standard-out --> Store activities in local files, in database. or print to system out?
  out_box: ./output #Folder where retrieved data goes.
  counts_to_standard_out: true
  compress_files: false #[] TODO: compressing output is largely untested. 

#Search configuration details:

auth:
  app_token:  #Either username or app-only bearer token.
  password: 
  
labels:
  environment: dev
  account_name:
```

### Command-line arguments <a id="arguments" class="tall">&nbsp;</a>



```
Usage: search-app [options]
    -c, --config CONFIG              Configuration file (including path) that provides account and download settings.
                                       Config files include username, password, account name and stream label/name.
    -r, --rule RULE                  Rule details.  Either a single rule passed in, or a file containing either a
                                   YAML or JSON array of rules.
    -s, --start_date START           UTC timestamp for beginning of Search period.
                                         Specified as YYYYMMDDHHMM, "YYYY-MM-DD HH:MM", YYYY-MM-DDTHH:MM:SS.000Z or use ##d, ##h or ##m.
    -e, --end_date END               UTC timestamp for ending of Search period.
                                      Specified as YYYYMMDDHHMM, "YYYY-MM-DD HH:MM", YYYY-MM-DDTHH:MM:SS.000Z or use ##d, ##h or ##m.
    -t, --tag TAG                    Optional. Gets included in the  payload if included. Alternatively, rules files can contain tags.
    -w, --write WRITE                'files', 'standard-out' (or 'so' or 'standard'), 'store' (database)
    -o, --outbox OUTBOX              Optional. Triggers the generation of files and where to write them.
    -z, --zip                        Optional. If writing files, compress the files with gzip.
    -l, --look                       "Look before you leap..."  Triggers the return of counts only.
    -d, --duration DURATION          The 'bucket size' for counts, minute, hour (default), or day
    -m, --max MAXRESULTS             Specify the maximum amount of data results.  10 to 500, defaults to 100.
    -h, --help                       Display this screen.
```



### Specifying search period start and end times <a id="specifying-times" class="tall">&nbsp;</a>


{{{{
When making search requests, if no "start" and "end" parameters are specified, the APIs default to the most recent 30 days. The request parameters, ```fromDate``` and ```toDate```, are used to specify the time frame of interest (with a minute granularity).

IF not specified, the "fromDate" time defaults to 30 days ago from now, and "toDate" time defaults to "now".  

The search APIs use a ```YYYMMDDHHMM``` timestamp format

Start and End times are specified using the UTC time standard. 
}}}}}


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

Multiple rules can be specified in JSON or YAML files.  Below is an example of each. Note that an individual rule can be specified on the command-line. 

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




## Other details <a id="other" class="tall">&nbsp;</a>

This third iteration is based on a previous version developed for the enterprise full-archive search API. That client was in turn based on the initial example developed for the enterprise 30-day search API.


### Updates 

This iteration has the following updates from the [full-archive version](https://github.com/gnip/gnip-fas-ruby):

+ Supports two flavors of Auth: Basic, Bearer App-only
+ Iterated HTTP, Logging common classes
+ Counts requests default to standard out. Must config to write to files (even as writing data to files).
+ "so" = "standard_out"

### Next
+ Stubs for data store writing
	+ Add in queuing system, with timed clean-up
+ Drops support for Activity Stream Tweet JSON format? 
+ New common classes: utilities














