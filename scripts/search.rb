'''

Provides a command-line driven wrapper around the Labs Recent search endpoint.

Originally built for premium and enterprise tiers of search, now updated to the Labs Recent search endpoint.

-------------------------------------------------------------------------------------------------------------------
This script/app is a command-line wrapper to search-tweets.rb, the SearchTweets class. The code here focuses on parsing
command-line options, loading configuration details, and then calling get_data or get_counts methods.

* Uses the optparse gem for parsing command-line options.
* Currently loads all configuration details from a .config.yaml file
* A next step could be to load in authentication keys via local environment vars.

This app currently has no logging, and instead just "puts" statements to system out. The SearchTweets class includes a
@verbose attribute that control the level of chatter.

One query can be passed in via the command-line (most common method), or a file path can be provided which contains a
query array in JSON or yaml.
Loads up queries, and loops through them. At least one query is required.
Writes to standard-out or files. 

-------------------------------------------------------------------------------------------------------------------
Example command-lines

    #Pass in two files, the SearchTweets app config file and a Rules file.
    # $ruby ./search.rb -c "./config/.config.yaml" -q "./queries/myQueries.yaml"
    # $ruby ./search.rb -c "./config/.config.yaml" -q "./queries/myQueries.json"

    #Typical command-line usage.
    # Passing in single query and ISO formatted dates. Otherwise running with defaults.
    # $ruby ./search.rb -q "(snow OR weather) (colorado OR #COWX)" -s "2020-01-06T17:00:00Z" -e "2020-01-10T17:00:00Z"
-------------------------------------------------------------------------------------------------------------------
'''

require_relative "../searchtweets/search_tweets.rb"
require_relative "../common/utilities.rb"

def check_query_and_set_defaults(oSearchTweets, query, start_time, end_time, since_id, until_id, max_results)

    #Provides initial "gate-keeping" on what we have been provided. Enough information to proceed?

    #We need to have at least one query.
    if !query.nil?
        #Queries file provided?
        extension = query.split(".")[-1]
        if extension == "yaml" or extension == "json"
            oSearchTweets.query_file = query
            if extension == "yaml" then
                oSearchTweets.queries.load_query_yaml(oSearchTweets.query_file)
            end
            if extension == "json"
                oSearchTweets.queries.load_query_json(oSearchTweets.query_file)
            end
        else
            query_hash = {}
            query_hash["value"] = query
            oSearchTweets.queries.queries << query_hash
        end
    else
       puts "Either a single query or a queries files is required. "
       puts "No query, quitting..."
       exit
    end

    #Everything else is option or can be driven by defaults.

    #start_date, defaults to NOW - 7 days by Recent search endpoint.
    #end_date, defaults to NOW (actually, third seconds before time of request).
    # OK, accepted parameters gets a bit fancy here.
    #    These can be specified on command-line in several formats:
    #           YYYYMMDDHHmm or ISO YYYY-MM-DD HH:MM.
    #           14d = 14 days, 48h = 48 hours, 360m = 6 hours
    #    Or they can be in the queries file (but overridden on the command-line).
    #    start_date < end_date, and end_date <= NOW.

    #Handle start date.
    #First see if it was passed in
    if !start_time.nil?
        oSearchTweets.start_time_study = Utilities.set_date_string(start_time)
    end

    #Handle end date.
    #First see if it was passed in
    if !end_time.nil?
        oSearchTweets.end_time_study = Utilities.set_date_string(end_time)
    end

    #Any defaults for these?
    if !since_id.nil?
        oSearchTweets.since_id = since_id
    end

    #Any defaults for these?
    if !until_id.nil?
        oSearchTweets.until_id = until_id
    end

    #Max results is optional, defaults to 10 by Labs Recent search.
    if !max_results.nil?
        oSearchTweets.max_results = max_results
    end

end

def set_app_configuration(oSearchTweets, exit_after, write, outbox, tag, verbose)

    #Tag is completely optional.
    if !tag.nil?
        query = {}
        query = oSearchTweets.queries.queries
        query[0]["tag"] = tag
    end

    #Tag is completely optional.
    if !verbose.nil?
        oSearchTweets.verbose = true
    end

    #Supports ability to set a maximum number of (pagination) requests.
    if !exit_after.nil?
        oSearchTweets.exit_after = exit_after.to_i
    end

    #Handle 'write' option
    if !write.nil?
        oSearchTweets.write_mode = write

        if oSearchTweets.write_mode == "standard_out" or oSearchTweets.write_mode == "standard" or oSearchTweets.write_mode == "so"
            oSearchTweets.write_mode = "standard_out"
        end
    end

    #Writing data to files.
    if !outbox.nil?
        oSearchTweets.out_box = outbox
        oSearchTweets.write_mode = "files"  #Setting an outbox overrides the write_mode....
    end

end

def request_summary(query, start_time, end_time, since_id, until_id)

    puts "Searching with query: #{query}"

    if start_time.nil? and end_time.nil? and (!since_id.nil? or !until_id.nil?)
        puts "Retrieving data since Tweet ID #{since_id}..." unless since_id.nil?
        puts "Retrieving data up until Tweet ID #{until_id}..." unless until_id.nil?
    else
        time_span = "#{start_time} to #{end_time}.  "
        if start_time.nil? and end_time.nil?
            time_span = "last 7 days."
        elsif start_time.nil?
            time_span = "7 days ago to #{end_time}. "
        elsif end_time.nil?
            time_span = "#{start_time} to now.  "
        end

        puts "Retrieving data from #{time_span}..."

    end
end

#=======================================================================================================================
if __FILE__ == $0  #This script code is executed when running this file.

    require 'optparse'
    require 'base64'

    #Defines the UI for the user. Albeit a simple command-line interface.
    OptionParser.new do |o|

        #Passing in a config file.... Or you can set a bunch of parameters.
        o.on('-c CONFIG', '--config', 'Configuration file (including path) that provides account and option selections.
                                       Config file specifies which search endpoint, includes credentials, and sets app options.') { |config| $config = config}
        
        o.on('-q QUERY', '--query', 'Maps to API "query" parameter.  Either a single query passed in, or a file containing either a
                                   YAML or JSON array of queries.') {|query| $query = query}


        #Period of search.  Defaults to end = Now(), start = Now() - 30.days.
        o.on('-s START', '--start-time', 'UTC timestamp for beginning of Search period (maps to "fromDate").
                                         Specified as YYYYMMDDHHMM, \"YYYY-MM-DD HH:MM\", YYYY-MM-DDTHH:MM:SS.000Z or use ##d, ##h or ##m.') { |start_time| $start_time = start_time}
        o.on('-e END', '--end-time', 'UTC timestamp for ending of Search period (maps to "toDate").
                                      Specified as YYYYMMDDHHMM, \"YYYY-MM-DD HH:MM\", YYYY-MM-DDTHH:MM:SS.000Z or use ##d, ##h or ##m.') { |end_time| $end_time = end_time}

        o.on('-p', '--poll', 'Sets "polling" mode.') {|poll| $poll = poll}

        o.on('-i SINCEID', '--since-id', 'All matching Tweets since this Tweet ID was created (exclusive).') {|since_id| $since_id = since_id}
        o.on('-u UNTILID', '--until-id', 'All matching Tweets up until this ID was created (exclusive).') {|until_id| $until_id = until_id}

        o.on('-m MAXRESULTS', '--max', 'Specify the maximum amount of Tweets results per response (maps to "max_results"). 10 to 100, defaults to 10.') {|max_results| $max_results = max_results}  #... as in look before you leap.

        o.on('-x EXIT', '--exit', 'Specify the maximum amount of requests to make. "Exit app after this many requests."') {|exit_after| $exit_after = exit_after}

        o.on('-w WRITE', '--write',"'files', 'hash', standard-out' (or 'so' or 'standard').") {|write| $write = write}
        o.on('-o OUTBOX', '--outbox', 'Optional. Triggers the generation of files and where to write them.') {|outbox| $outbox = outbox}

        #Tag:  Not in payload, but triggers a "matching_query" section with query tag values.
        o.on('-t TAG', '--tag', 'Optional. Gets included in the Tweet payload if included. Also, queries files can contain tags.') {|tag| $tag = tag}

        o.on('-v', '--verbose', 'Optional. Turns verbose messaging on.') {|verbose| $verbose = verbose}

        #Help screen.
        o.on( '-h', '--help', 'Display this screen.' ) do
            puts o
            exit
        end

        o.parse!
    end

    #Create a Tweet Search object.
    oSearchTweets = SearchTweets.new()

    oSearchTweets.queries.queries = Array.new # Ability to handle arrays of queries is baked in at a low level ;)

    #Provided config file, which can provide auth, URL metadata, and app options.
    if $config.nil?
			$config = "../config/.config.yaml" #Set default.
    end
    
    if !File.exists?($config) 
			puts "Can not find configuration file. Quitting."
			exit
    end

    oSearchTweets.get_system_config($config) #Anything on command-line overrides configuration setting...

    #Adding polling details...
    newest_id = '0'

    newest_id_file = './newest_id.txt'  #'./config/polling.txt'

    oSearchTweets.set_requester #With config details, set the HTTP stage for making requests.
    if $poll
        puts "Polling request"

        if File.exists?(newest_id_file)
          newest_id = Utilities.read_id(newest_id_file).to_s
        end
    end

    if !$since_id.nil?
      puts "Polling request with since_id"
    end

    if newest_id != '' and newest_id != '0'
      $since_id = newest_id
      $start_time = nil
      $end_time = nil
    end

    #Validate request and commands. #So, we got what we got from the config file, so process what was passed in.
    check_query_and_set_defaults(oSearchTweets, $query, $start_time, $end_time, $since_id, $until_id, $max_results) #TODO: add polling?
    set_app_configuration(oSearchTweets, $exit_after, $write, $outbox, $tag, $verbose)

    #Wow, we made it all the way through that!  Documentation must be awesome...
    request_summary($query, $start_time, $end_time, $since_id, $until_id)

    #Start requesting data...
    tweet_array = []
    includes_array = []
    oSearchTweets.queries.queries.each do |query|
       puts "Getting activities for query: #{query["value"]}" if oSearchTweets.verbose
       tweet_array, includes_array, newest_id = oSearchTweets.get_data(query["value"], oSearchTweets.start_time_study, oSearchTweets.end_time_study, oSearchTweets.since_id, oSearchTweets.until_id)
    end

    #Finished making requests...
    Utilities.write_file(newest_id_file, newest_id) if newest_id.to_i > 0 if $poll

    #returning hash or JSON string.
    if oSearchTweets.write_mode == 'hash' or oSearchTweets.write_mode == 'json'
        puts tweet_array.to_json if oSearchTweets.verbose
        puts "Received #{tweet_array.length} Tweets..." if oSearchTweets.verbose
        puts "Building a polling client that works with 'hash' or 'JSON' output? This is where you process that data..." if oSearchTweets.verbose
    end
     
    puts "Exiting..."
end
