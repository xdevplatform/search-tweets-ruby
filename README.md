# Ruby Tweet Search Client

This Ruby client is written to work with the Twitter premium and enterprise versions of Tweet Search.

+ Manages an array of filters, making requests for each.
+ Writes to files or standard out. 
+ Returns total count for entire request period.`

This third iteration is based on a previous client developed for the enterprise full-archive search API. That client was in turn based on the initial client developed for the enterprise 30-day search API.


## Getting Started

+ Establish access to, and authentication, for the search API of your choice. See product documentation authentication details. 
+ Clone respository.
+ bundle install. See project Gem file. Need some basic gems like 'json', 'yaml', and 'zlib'. 
+ Configure the config.yaml. 
+ Test it out by running $ruby search_app.rb -r "from:TwitterDev" -s 14d
+ Look for API JSON responses in app's standard out, outbox, or in the configured database. 

### New features

+ supports three flavors of Auth: Basic, Bearer, App-only OAuth

+ Stubs for data store writing
	+ Add in queuing system, with timed clean-up

This iteration has the following updates from the full-archive version:

+ Drops support for Activity Stream Tweet JSON format.
+ Iterated HTTP, Logging common classes
+ Add new common classes: utilities, config
+ Counts requests default to standard out. Must config to write to files (even as writing data to files).
+ "so" = "standard_out"



### Specifying Search Start and End Times

If no "start" and "end" parameters are specified, search APIs default to the most recent 30 days. "Start" time defaults to 30 days ago from now, and "End" time default to "now". Start (-s) and end (-e) parameters can be specified in a variety of ways:

* Standard premium/enterprise format, YYYYMMDDHHmm (UTC)
   * -s 201511070700 -e 201511080700 --> Search 2013-11-07 MST. 
   * -s 201511090000 --> Search since 2015-11-09 00:00 UTC.
* A combination of an integer and a character indicating "days" (#d), "hours" (#h) or "minutes" (#m).  Some examples:
   * -s 1d --> Start one day ago (i.e., search the last day)
   * -s 14d -e 7d --> Start 14 days ago and end 7 days ago (i.e. search the week before last)  
   * -s 6h --> Start six hours ago (i.e. search the last six hours) 
* "YYYY-MM-DD HH:mm" (UTC, use double-quotes please)
   * -s "2015-11-04 07:00" -e "2015-11-07 06:00" --> Search 2015-11-04 and 2015-11-05 MST.
* "YYYY-MM-DDTHH:MM:SS.000Z" (ISO 8061 timestamps as used by Twitter, in UTC)
   * -s 2015-11-20T15:39:31.000Z --> Search beginning at 2015-11-20 22:39 MST (note that seconds are dropped).




 




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



