![](https://img.shields.io/endpoint?url=https%3A%2F%2Ftwbadges.glitch.me%2Fbadges%2Fv2)

# Ruby client for Twitter API v2 recent search endpoint

Welcome to the main branch of the Ruby search client. This branch supports the [Twitter API v2 recent search](https://developer.twitter.com/en/docs/twitter-api/tweets/search/introduction) 
only, and drops support for the premium and enterprise tiers. 

If you are looking for the original version that works with premium and enterprise versions of search, head on over to the "enterprise-premium" branch.

If you are already familiar with the 'labs' version/branch, it's time to start using the Twitter API v2 version. 

## Features
+ Supports [Twitter API v2 recent search](https://developer.twitter.com/en/docs/twitter-api/tweets/search/introduction).
+ Command-line utility is pipeable to other tools (e.g., jq).
+ Automatically handles pagination of search results with specifiable limits. This enables users to define a *study period* of interest, and the search client code will manage however many requests are required to transverse that period, up to 100 Tweets at a time. 
+ By default, the script writes Tweets to standard out, and can also write to files or return either a hash or JSON string.
+ Flexible usage within a Ruby program.
+ Supports "polling" use cases.  
+ **Note:** the Labs Recent search endpoint *does not* support the ```counts``` endpoint. 

----------------
Jump to:

+ [Overview](#overview)
+ [Getting started](#getting-started)
+ [Configuring client](#config)
   + [Setting credentials](#credentials)
   + [Configuration file](#config-file)
   + [Command-line arguments](#arguments)
+ [Example script commands](#example-calls)
+ [Running in 'polling' mode](#polling)
+ [Specifying search period start and end times](#specifying-times)
+ [Automating multiple queries](#queries)
--------------------

## Overview <a id="overview" class="tall"></a>

This project includes two Ruby scripts (```search.rb``` and ```polling.rb```, both in the /scripts folder) that are written for the Labs Recent search endpoint. These scripts demonstrate how to create an instance of this project's main ```SearchTweets``` class (implemented in searchtweets/search_tweets.rb) and ask it for data. 

These scripts are command-line driven and support the following features:

+ Supports flexible ways to specify the search *study period*. Your study period may be a week, and the example script manages the multiple requests needed to span that period. E.g., ```-s 7d``` specifies the past 7 days. ```-s 12h``` specifies 12 hours, and ```-s 90m``` specifies 90 minutes. Other patterns such as ```YYYY-MM-DD HH:mm```, standard Twitter ISO timestamps, and the legacy 'Gnip' ```YYYYMMDDhhmm``` pattern are also supported. If no ```start-time``` and ```end-time``` details are included, the endpoint defaults to the previous seven days, starting with the most recent Tweets, then going back through time one page at a time. 

+ Supports a "polling" ```-p``` mode. Polling mode is a pattern where a request is made on an interval (defaults to every 10 minutes) Both scripts support polling: 
  + search.rb: This script is designed to make a set of requests and quit. When in 'polling' mode, the script leaves a 'breadcrumb' files with the 'newest' Tweet ID in it. The next time the script runs, it references this 'newest_id.txt' file and asks for Tweets posted since that one, then quits. Designed to be entered as a crontab job.  
  + polling.rb: This script is based on an endless loop that makes requests for new Tweets on an ```--poll-interval``` (in minutes) command-line argument. 

+ Polling also supports 'backfills.' You can initiate a polling session that starts with a backfill period to retrieve Tweets from first, then begins polling for new data. When listening for a topic of interest, it's common to start off with some recent history.

+ Writes to files, standard out, or receives a JSON string or hash from the underlying ```SearchTweets``` class. When writing files, one file is written for every endpoint response. File names are based on query syntax, and are serialized. 

+ The client can stop making requests after a specified number. If your search query and period match millions of Tweets that would require hundreds (or thousands) of requests, you can have the client stop after four requests by adding the ```-x 4``` argument. 

+ Can manage an array of queries, making requests for each. These query files can be written in YAML or JSON. 

+ Queries can be configured with ```tag``` strings, and these are injected into the returned Tweet JSON. Tags can be used to describe why Tweets were matched. If you are building a Tweet collection based on many queries, tags are useful for logically grouping Tweets. 

### SearchTweets class

The ```search.rb``` and ```polling.rb``` scripts both demonstrate creating an instance of the SearchTweets class and calling its ```get_data``` method. 

1) Creating an instance of the TweetsSearch class. 
```ruby
  oSearchClient = SearchTweets.new()
```

2) Calling its ```get_data``` method with a query and getting back an array of Tweets along with the ID of the most recent one returned.

```ruby
  tweet_array, newest_id = oSearchClient.get_data(query)
```
## Getting started <a id="getting-started" class="tall"></a>

Four fundamental steps need to be taken to start using this search client: 

1) Establish access to the Twitter API v2 endpoints at 1) Establish access to the Twitter API v2 endpoints at https://developer.twitter.com/en/docs/labs/overview/whats-new
2) Obtain credentials for authenticating with the search endpoint. You'll need to create a developer App and generate a application/consumer key and secret. You can 
configure the scripts with either the consumer key and secret tokens or a Bearer Token that you have generated. (The Labs Recent search endpoint uses Bearer Token authentication. If you use just the key and secret, the search client will generate the Bearer Token.) For more information, see our authentication documentation [HERE](https://developer.twitter.com/en/docs/basics/authentication/oauth-2-0).
3) Get this Ruby app running in your environment: 
+ Clone respository. 
+ Get gems installed with ```bundle install```. See project Gemfile. The client uses some basic gems like 'json' and 'yaml'. Test it out by running ```$ruby scripts/search.rb -h```. You should see a help menu. 
4) Configure client. See below for more details. 
5) Use command-line arguments to start making search requests (see examples below).

**A few notes:**

+ Recent search supports queries up to 512 characters long.
  + See our [guide on creating search queries](https://developer.twitter.com/en/docs/twitter-api/tweets/search/integrate/build-a-rule).
+ If not request start and end times are specified, the endpoint defaults to that last 7 days, starting with the most recent Tweets, and paginating backwards through time.  
+ For more information on the search endpoint that this client exercises, see our [API Reference[(https://developer.twitter.com/en/docs/twitter-api/tweets/search/api-reference/get-tweets-search-recent).


## Configuring client <a id="config" class="tall"></a>

This client is configured with a combinaton of command-line arguments, environmental variables, and a YAML config file. 
This configuraton file defaults to ```./config/.config.yaml```, although you can specify a different path and name with the 
```--config``` command-line argument. 

In general, command-line arguments are used to set the most frequently changed parameters, such as the query and the start and end times. 
Other parameters, such as the Tweet JSON fields of interest, can be set in the YAML file. Some configuation details, such as 
the output mode and maximum results per response, are setable by both command-line and YAML settings. If these settings are
provided via the command-line, they will overwrite any setting made in the config file.

### Setting credentials <a id="credentials" class="tall"></a>

Twitter endpoint credentials can be configured as *environmental variables* or set up in the YAML file. 

The search client first checks for environmental variables, and if not found there, it then looks in the YAML file. 

#### Setting credentials with environmental variables

To set up your credentials environmental variables, use the following commands. You can set up either the ```TWITTER_CONSUMER_KEY``` 
and ```TWITTER_CONSUMER_SECRET```values or just the ```TWITTER_BEARER_TOKEN``` value. 

```bash
export TWITTER_CONSUMER_KEY=N0TmYC0Nsum4Rk3Y
export TWITTER_CONSUMER_SECRET=N0TmYC0Nsum4Rs3cR3t
```

```bash
export TWITTER_BEARER_TOKEN=AAAAAAAAreallylongBearerT0k4n
```

To have these environmental variables persist between terminal sessions, add these commands to your ~/.bash_profile (at least on Linux/Unix).

#### Setting credentials in YAML configuration file

A ```.config.yaml``` file is used to set script options, and optionally, endpoint credentials. By default, this file is assumed to be in a ```./config``` subfolder of the main project directory. You can store it somewhere else and use the ```--config``` argument to provide the file path. 

In the YAML file there is a ```auth:``` section. You can either set the ```consumer_key``` and ```consumer_token``` values, or the ```bearer_token``` value. 

```yaml
#Credentials.
auth:
  consumer_key: N0TmYC0Nsum4Rk3Y
  consumer_secret: N0TmYC0Nsum4Rs3cR3t
  bearer_token: AAAAAAAAreallylongBearerT0k4n 
```

## Setting client options in YAML configuration file  <a id="config-file" class="tall">&nbsp;</a>

This version of search enables developers to fine-tune the details they want to include in the endpoint's responses, using [expansions](https://developer-staging.twitter.com/en/docs/twitter-api/expansions) 
and [fields](https://developer-staging.twitter.com/en/docs/twitter-api/fields). Since expansions and fields details can be 
very lengthy, these options are set in the YAML configuraion file. The example file below includes all the available options 
for expansions and fields. As you work with the client's output, you may decide to exclude objects and fields that you do
not need. 

Other options configurable in the file include the maximum number of Tweets to include per 'page' of results, ```max_results```, 
and how the data is processed. If the ```write_mode``` is set to 'files', the ```out_box``` is set to where you want files 
to be written.

If the ```write_mode``` is set to 'json' or 'hash', the ```max_tweets_in_returned_hash``` can be used to set a upper limit
on the number of Tweets written to this one data structure. This client is designed to make as many requests as needed to 
retrieve every Tweet that matches your query and study period. Since that number of Tweets can be very large, this can be used 
to limit the amount of memory used to store the payload. 

```yaml
#Client options.
options:
  #Default API request parameters.
  max_results: 50 #For v2 this max is 100. Default is 10.

  expansions: attachments.poll_ids,attachments.media_keys,author_id,entities.mentions.username,geo.place_id,in_reply_to_user_id,referenced_tweets.id,referenced_tweets.id.author_id
  tweet.fields: attachments,author_id,context_annotations,conversation_id,created_at,entities,geo,id,in_reply_to_user_id,lang,possibly_sensitive,promoted_metrics,public_metrics,referenced_tweets,source,text,withheld
  #If you are using user-context authentication, these Tweet field ise available for the authorizing user: non_public_metrics.
  #If that user is promoting Tweets with Twitter Ads, these Tweet fields are available: organic_metrics, promoted_metrics
  user.fields: created_at,description,entities,id,location,name,pinned_tweet_id,profile_image_url,protected,public_metrics,url,username,verified,withheld
  media.fields: duration_ms,height,media_key,preview_image_url,public_metrics,type,url,width
  place.fields: contained_within,country,country_code,full_name,geo,id,name,place_type
  poll.fields: duration_minutes,end_datetime,id,options,voting_status

  write_mode: so  # options: json, files, so/standard/standard-out, hash --> Store Tweets in local files or print to system out?
  out_box: ./output # Folder where retrieved data goes.
  max_tweets_in_returned_hash: 10000

```

## Command-line arguments <a id="arguments" class="tall">&nbsp;</a>

The ```search.rb``` and ```polling.rb``` example scripts support the following commands.

### Command-line options for ```search.rb``` script:

```
Usage: search [options]
    -c, --config CONFIG              Configuration file (including path) that provides account and option selections.
                                       Config file specifies which search api, includes credentials, and sets app options.
    -q, --query QUERY                Maps to API "query" parameter.  Either a single query passed in, or a file containing either a
                                   YAML or JSON array of queries/rules.
    -s, --start-time START           UTC timestamp for beginning of Search period (maps to "fromDate").
                                         Specified as YYYYMMDDHHMM, \"YYYY-MM-DD HH:MM\", YYYY-MM-DDTHH:MM:SS.000Z or use ##d, ##h or ##m.
    -e, --end-time END               UTC timestamp for ending of Search period (maps to "toDate").
                                      Specified as YYYYMMDDHHMM, \"YYYY-MM-DD HH:MM\", YYYY-MM-DDTHH:MM:SS.000Z or use ##d, ##h or ##m.
    -p, --poll                       Sets "polling" mode.
    -i, --since-id SINCEID           All matching Tweets since this Tweet ID was created (exclusive).
    -u, --until-id UNTILID           All matching Tweets up until this ID was created (exclusive).
    -m, --max MAXRESULTS             Specify the maximum amount of Tweets results per response (maps to "max_results"). 10 to 100, defaults to 10.

    -x, --exit EXIT                  Specify the maximum amount of requests to make. "Exit app after this many requests."
    -w, --write WRITE                'files', 'standard-out' (or 'so' or 'standard').
    -o, --outbox OUTBOX              Optional. Triggers the generation of files and where to write them.
    -t, --tag TAG                    Optional. Gets included in the  payload if included. Alternatively, rules files can contain tags.
    -h, --help                       Display this screen.
```

### Command-line options for ```polling.rb``` script:

```
Usage: search [options]
    -c, --config CONFIG              Configuration file (including path) that provides account and option selections.
                                       Config file specifies which search endpoint, includes credentials, and sets app options.
    -q, --query QUERY                Maps to API "query" parameter.  Either a single query passed in, or a file containing either a
                                   YAML or JSON array of queries.
    -s, --start-time START           UTC timestamp for beginning of Search period (maps to "fromDate").
                                         Specified as YYYYMMDDHHMM, \"YYYY-MM-DD HH:MM\", YYYY-MM-DDTHH:MM:SS.000Z or use ##d, ##h or ##m.
    -e, --end-time END               UTC timestamp for ending of Search period (maps to "toDate").
                                      Specified as YYYYMMDDHHMM, \"YYYY-MM-DD HH:MM\", YYYY-MM-DDTHH:MM:SS.000Z or use ##d, ##h or ##m.
    -p, --poll                       Sets "polling" mode.
    -i, --since-id SINCEID           All matching Tweets since this Tweet ID was created (exclusive).
    -u, --until-id UNTILID           All matching Tweets up until this ID was created (exclusive).
    -m, --max MAXRESULTS             Specify the maximum amount of Tweets results per response (maps to "max_results"). 10 to 100, defaults to 10.
    -x, --exit EXIT                  Specify the maximum amount of requests to make. "Exit app after this many requests."
    -w, --write WRITE                'files', 'hash', standard-out' (or 'so' or 'standard').
    -o, --outbox OUTBOX              Optional. Triggers the generation of files and where to write them.
    -t, --tag TAG                    Optional. Gets included in the Tweet payload if included. Also, queries files can contain tags.
    -v, --verbose                    Optional. Turns verbose messaging on.
    -h, --help                       Display this screen.

```

## Example script commands <a id="example-calls" class="tall">&nbsp;</a>

Here are some example commands to help you get started with the Ruby search client:

+ Request all Tweets posted by the @TwitterDev account over the past 5 days:
   + ```$ruby search.rb -q "from:TwitterDev" -s 5d``` 
   
+ Request Tweets matching the specified rule, but stop after three requests. Set the search period to May 8, 2020 in the MDT (UTC−6:00) timezone. This example rule translates to "match Tweets with keyword 'spring' that have a photo, video, or GIF attached 'natively' with Twitter app."   
   + ```$ruby search.rb -q "spring has:media" -s "2020-05-08 06:00" -e "2020-05-09 06:00" -x 3```  

+ Request Tweets and receive a Ruby hash will all matching Tweets:
  + ```$ruby search.rb --query "spring has:media" --start-time 12h --write hash```

+ Request Tweets and have the client write responses to a specified folder:
  + ```$ruby search.rb --query "spring has:media" --start-time 12h --write files --outbox "./output"```

+ Make Requests using a YAML configuration file with a custom name and stored somewhere other than the default location (./config):
  +  ```$ruby ./search.rb -c "~/configs/twitter/my_config.yaml" -q "snow has:videos -s 14d```

## Running in 'polling' mode  <a id="polling" class="tall"></a>

The ```search.rb``` and ```polling.rb``` scripts both support a 'polling' mode. In this mode, the scripts are used to make "any new Tweets since I last asked?" requests on a user-specified interval. As that interval decreases, search endpoints can be used to collect Tweets in a near-real-time fashion. Polling mode depends on the ```since_id``` search request parameter. After collecting some Tweets, this parameter is set to the most recent (the largest) Tweet ID that has been received. 

Both example scripts implement a polling option, and in very different ways. One key difference it that the ```search.rb``` script depends on an external process to trigger the interval calls (e.g. setting up a crontab, or having a separate script that watches the clock), while the ```polling.rb``` script stays reesident and manages its own interval calls.

### Polling with ```search.rb```

The ```search.rb``` script was originally built to manage requests across a *study period* of interest. Search endpoints return a relatively small amount of Tweets per response, and pagination is usually required to compile the Tweet collection of interest. Labs Recent search returns 10 Tweets per response by default, and the client ```--max``` argument is avialable to adjust that up to the maximum number of 100 Tweets.  

The ```search.rb``` script now supports a ```--poll``` command-line argument. When this argument is included, the script knows to leave a 'breadcrumb' ```newest_id.txt``` file after it has completed its set of paginated requests. Search endpoints start with the most recent Tweets first, and paginate backwards through time. So the trick here, which the search client manages for you, is to persist the ```newest_id``` from the *first* request, regardless of how many requests were required to paginate and transverse your *study period*. 

When in polling mode, the ```search.rb``` script looks for this ```newest_id.txt``` file. If you are starting a new polling session, it's important to delete any existing ```newest_id.txt``` file. When starting without a ```newest_id.txt``` file, the ```search.rb``` script does its normal thing of making as many paginated requests as needed, then writes a new ```newest_id.txt``` file. When the script is run again, with the same command-line arguments as before, it finds the file and short-circuits to use the ```since_id``` request parameter in place of any ```start_time``` used for the first ```--poll``` run. 

As an example, the following call triggers the polling mode, and also asks for two days of backfill:

```$ruby search.rb --poll --query "(snow OR rain) colorado has:media" -s 2d```

When this set of requests finishes, the ```newest_id.txt``` file is written. The next time the script runs, perhaps by a crontab entry, the above response is automatically updated to:

```$ruby search.rb --poll --query "(snow OR rain) colorado has:media" --since-id 1230653928645124097```


### Polling with ```polling.rb```

The ```polling.rb``` was written to focus on polling, and operates in a completely different way. The ```polling.rb``` script internally runs an endless `while` loop and self-manages its polling timing based on the interval duration passed in by the user (and defaults to 5 minutes). To do this, the script times how long each set of requests makes, and adjustments accordingly to stay precisely on the interval. 

As an example, the following call sets up a polling session on a 30-second interval. This request starts off with a 72-hour  backfill, completes that backfill, then starts making a request every 30 seconds: 

```$ruby polling.rb --poll-interval 0.5 --query "(snow OR rain) colorado has:media" -s 72h```

The ```polling.rb``` script will continue to run until the script is stopped.


## Specifying search period start and end times <a id="specifying-times" class="tall"></a>

By default the Labs recent search endpoint will search from the previous 7 days. However, most search requests will have a more specific period of interest. With the Labs search endpont the start of the search period is specified with the ```start_time``` parameter, and the end with ```end_time``` request parameter. 

Both timestamps assume the UTC timezone. If you are making search requests based on a local timezone, you'll need to convert these timestamps to UTC. These search APIs require these timestamps to have the 'YYYY-MM-DDTHH:mm:ssZ' format (ISO 8601/RFC 3339). As that format suggests, search request periods can have a second granularity. 

This client uses the 'start' and 'end' aliases for ```start_time``` and ```end_time``` parameters, and supports additional timestamp formats.

Start ```-s``` and end ```-e``` parameters can be specified in a variety of ways:

+ A combination of an integer and a character indicating "days" (#d), "hours" (#h) or "minutes" (#m). Some examples:
	+ -s 5d --> Start five days ago.
	+ -s 6d -e 2d --> Start 6 days ago and end 2 days ago.
	+ -s 6h --> Start six hours ago (i.e. Tweets from the last six hours).

+ YYYYMMDDHHmm (UTC)
	+ -s 202005170700 
	+ -e 202005180700 

+ "YYYY-MM-DD HH:mm" (UTC, use double-quotes please).
	+ -s "2020-05-17 06:00" -e "2020-05-19 06:00" --> Tweets from between 2020-05-17 and 2020-05-19 MDT.

+ "YYYY-MM-DDTHH:MM:SS.000Z" (ISO 8061 timestamps as used by Twitter, in UTC).
	+ -s 2020-05-17T15:00:00.000Z --> Tweets posted since 2020-05-17 09:00:00 MDT .	
	
	
## Automating multiple queries <a id="queries" class="tall">&nbsp;</a>

The Search endpoint works with a single query at a time. This client supports making requests with multiple queries, managing the data retrieval for each individual rule. 

Multiple queries can be specified in JSON or YAML files.  Below is an example of each. 

**JSON query file:

```json
{
  "queries" :
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

**YAML query file:

```yaml
queries:
  - value  : "snow colorado"
    tag    : ski_biz
  - value  : "snow utah"
    tag    : ski_biz
  - value  : "rain washington"
    tag    : umbrellas
```

For example, you can pass in a JSON query file located at ./queries/my-snow-rules.json with the following argument:

```$ruby search.rb -r "./queries/my-snow-queries.json" -s 7d -m 100```  
