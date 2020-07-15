'''

Manages Twitter search requests in a "polling" mode. In this mode, "any new Tweets since I last asked?" requests
are made repeatedly on a polling frequency. As the polling interval decreases, the more this request pattern mimics
real-time feeds. The default interval is 5 minutes.

-------------------------------------------------------------------------------------------------------------------
Example command-lines

Poll every 5 minutes for original Tweets with mentions of keywords with media "attached."
   $ruby ./polling-api.rb -c "./SearchConfig.yaml" -p 5 -r "(snow OR hail OR rain) -is:retweet has:media"

-------------------------------------------------------------------------------------------------------------------
'''

require_relative "../searchtweets/search_tweets.rb"
require_relative "../common/utilities.rb"

def check_query_and_set_defaults(oSearchTweets, query, start_time, since_id, max_results)

    #Provides initial "gate-keeping" on what we have been provided. Enough information to proceed?

    #We need to have at least one query.
    if !query.nil?
        #Rules file provided?
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

    #start_date, defaults to NOW - 7 days by the Labs Recent search endpoint.
    #end_date, defaults to NOW (actually, third seconds before time of request).
    #
    # These time commandline arguments can be formated in several ways:
    #    These can be specified on command-line in several formats:
    #           YYYYMMDDHHmm or ISO YYYY-MM-DD HH:MM.
    #           14d = 14 days, 48h = 48 hours, 360m = 6 hours
    #    Or they can be in the queries file (and overridden on the command-line).

    #Handle start date.
    #First see if it was passed in
    if !start_time.nil?
        oSearchTweets.start_time_study = Utilities.set_date_string(start_time)
    end

     #Any defaults for these?
    if !since_id.nil?
        oSearchTweets.since_id = since_id
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

def request_summary(query, start_time, since_id)

    puts "Searching with query: #{query}"

    if !start_time.nil?
        puts "Backfilling Tweets since #{start_time}..."
    elsif !since_id.nil?
        puts "Retrieving Tweets since ID #{since_id}..." unless since_id.nil?
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
        
        #Search query.  This can be a single query ""this exact phrase\" OR keyword"
        o.on('-q QUERY', '--query', 'Maps to API "query" parameter.  Either a single query passed in, or a file containing either a
                                   YAML or JSON array of queries/rules.') {|query| $query = query}


        #Period of search.  Defaults to end = Now(), start = Now() - 30.days.
        o.on('-s START', '--start-time', 'UTC timestamp for beginning of Search period (maps to "fromDate").
                                         Specified as YYYYMMDDHHMM, \"YYYY-MM-DD HH:MM\", YYYY-MM-DDTHH:MM:SS.000Z or use ##d, ##h or ##m.') { |start_time| $start_time = start_time}
        o.on('-i SINCEID', '--since_id', 'All matching Tweets since this Tweet ID was created (exclusive).') {|since_id| $since_id = since_id}

        o.on('-p POLLINTERVAL', '--poll-interval', 'Polling interval in minutes. Default is 5 minutes.') {|interval| $interval = interval}

        o.on('-m MAXRESULTS', '--max', 'Specify the maximum amount of Tweets results per response (maps to "max_results"). 10 to 100, defaults to 10.') {|max_results| $max_results = max_results}  #... as in look before you leap.

        o.on('-x EXIT', '--exit', 'Specify the maximum amount of requests to make. "Exit app after this many requests."') {|exit_after| $exit_after = exit_after}

        o.on('-w WRITE', '--write',"'files', 'standard-out' (or 'so' or 'standard').") {|write| $write = write}
        o.on('-o OUTBOX', '--outbox', 'Optional. Triggers the generation of files and where to write them.') {|outbox| $outbox = outbox}

        #Tag:  Not in payload, but triggers a "matching_rules" section with query tag values.
        o.on('-t TAG', '--tag', 'Optional. Gets included in the  payload if included. Alternatively, rules files can contain tags.') {|tag| $tag = tag}

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

    if $interval.nil?
        $interval = 5
    end

    oSearchTweets.get_system_config($config) #Anything on command-line overrides configuration setting...
    oSearchTweets.set_requester #With config details, set the HTTP stage for making requests.

    #Validate request and commands. #So, we got what we got from the config file, so process what was passed in.
    check_query_and_set_defaults(oSearchTweets, $query, $start_time, $since_id, $max_results)
    set_app_configuration(oSearchTweets, $exit_after, $write, $outbox, $tag, $verbose)

    #Wow, we made it all the way through that!  Documentation must be awesome...
    request_summary($query, $start_time, $since_id)

    polling_interval = $interval.to_f * 60
    newest_id = 0

    #Start making requests and keep doing that until this script is stopped...
    while true

        start_request = Time.now

        #Start requesting data...
        tweet_array = []
        oSearchTweets.queries.queries.each do |query|
            puts "Getting activities for query: #{query["value"]}" if oSearchTweets.verbose
            tweet_array, newest_id = oSearchTweets.get_data(query["value"], oSearchTweets.start_time_study, oSearchTweets.end_time_study, oSearchTweets.since_id, oSearchTweets.until_id)
        end

        #Finished making requests for this polling interval.
        oSearchTweets.since_id = newest_id
        oSearchTweets.start_time_study = nil

        #returning dictionary or JSON string.
        if oSearchTweets.write_mode == 'hash' or oSearchTweets.write_mode == 'json'
            puts tweet_array.to_json if oSearchTweets.verbose
            puts "Received #{tweet_array.length} Tweets..." if oSearchTweets.verbose
            puts "Building a polling client that works with 'hash' or 'JSON' output? This is where you process that data..." if oSearchTweets.verbose
        end

        request_duration = Time.now - start_request
        puts "Polling again in #{'%.1f' %[polling_interval - request_duration,1].max} seconds..."
        sleep (polling_interval - request_duration)
    end
end
