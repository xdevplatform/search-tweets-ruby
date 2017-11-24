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

This third iteration is based on a previous version developed for the enterprise full-archive search API. That client was in turn based on the initial example developed for the enterprise 30-day search API.

## Getting Started

+ Establish access to, and authentication, for the search API of your choice. See product documentation authentication details. 
+ Clone respository.
+ bundle install. See project Gem file. Need some basic gems like 'json', 'yaml', and 'zlib'. 
+ Configure the config.yaml. 
+ Test it out by running $ruby search_app.rb -r "from:TwitterDev" -s 14d
+ Look for API JSON responses in app's standard out or outbox. 

## Introduction






### Specifying search period start and end times <a id="specifying-times" class="tall">&nbsp;</a>

When making search requests, if no "start" and "end" parameters are specified, the APIs default to the most recent 30 days. The request parameters, ```fromDate``` and ```toDate```, are used to specify the time frame of interest (with a minute granularity).

IF not specified, the "fromDate" time defaults to 30 days ago from now, and "toDate" time defaults to "now".  

The search APIs use a ```YYYMMDDHHMM``` timestamp format

Start and End times are specified using the UTC time standard. 

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



### Rules Files

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




## Other details

### Updates 

This iteration has the following updates from the full-archive version:

+ Supports twp flavors of Auth: Basic, Bearer App-only
+ Iterated HTTP, Logging common classes
+ Counts requests default to standard out. Must config to write to files (even as writing data to files).
+ "so" = "standard_out"

### Next
+ Stubs for data store writing
	+ Add in queuing system, with timed clean-up
+ Drops support for Activity Stream Tweet JSON format? 
+ New common classes: utilities














