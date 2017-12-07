#A command-line wrapper to the fa_search class.
#Uses the 'optparse' gem for parsing command-line options.  For better or worse...
#The code here focuses on parsing command-line options, config files, then calling get_data or get_counts methods.

#Loads up rules, and loops through them.
#Writes to standard-out, files or to a database.

#Example usage: see README.md

require_relative "./lib/search-tweets.rb"
require_relative "./common/utilities.rb"

#=======================================================================================================================
if __FILE__ == $0  #This script code is executed when running this file.

    require 'optparse'
    require 'base64'
    


    #-------------------------------------------------------------------------------------------------------------------
    #Example command-lines

    #Options:
    #       Pass in configuration and rules files.
    #       Pass in everything on command-line.
    #       Pass in configuration file and all search parameters.
    #       Pass in configuration parameters and rules file.

    #Pass in two files, the Gnip Search API config file and a Rules file.
    # $ruby ./search-api.rb -c "./SearchConfig.yaml" -r "./rules/mySearchRules.yaml"
    # $ruby ./search-api.rb -c "./SearchConfig.yaml" -r "./rules/mySearchRules.json"

    #Typical command-line usage.
    # Passing in single filter/rule and ISO formatted dates. Otherwise running with defaults.
    # $ruby ./search-api.rb -r "rain OR weather (profile_region:colorado)" -s "2013-10-18 06:00" -e "2013-10-20 06:00"

    #Get minute counts.  Returns JSON time-series of minute, hour, or day counts.
    # $ruby ./search_api.rb -l -d "minutes" -r "rain OR weather (profile_region:colorado)" -s "2013-10-18 06:00" -e "2013-10-20 06:00"

    #-------------------------------------------------------------------------------------------------------------------

    OptionParser.new do |o|

        #We need either a config file AND a rule parameter (which can be a single rule passed in, or a rules file)
        # OR
        #100% parameters, with no config file:
        # Mandatory: username, password, address/account, rule
        # Options: start(defaults to Now - 30 days), end (defaults to Now), tag,
        # look, duration (defaults to minute), maxResults (defaults to 100)

        #Passing in a config file.... Or you can set a bunch of parameters.
        o.on('-c CONFIG', '--config', 'Configuration file (including path) that provides account and option selections.
                                       Config file specifies which search api, includes credentials, and sets app options.') { |config| $config = config}
        
        #Search rule.  This can be a single rule ""this exact phrase\" OR keyword"
        o.on('-r RULE', '--rule', 'Rule details (maps to API "query" parameter).  Either a single rule passed in, or a file containing either a
                                   YAML or JSON array of rules.') {|rule| $rule = rule}
        #Tag, optional.  Not in payload, but triggers a "matching_rules" section with rule/tag values.
        o.on('-t TAG', '--tag', 'Optional. Gets included in the  payload if included. Alternatively, rules files can contain tags.') {|tag| $tag = tag}

        #Period of search.  Defaults to end = Now(), start = Now() - 30.days.
        o.on('-s START', '--start_date', 'UTC timestamp for beginning of Search period (maps to "fromDate").
                                         Specified as YYYYMMDDHHMM, \"YYYY-MM-DD HH:MM\", YYYY-MM-DDTHH:MM:SS.000Z or use ##d, ##h or ##m.') { |start_date| $start_date = start_date}
        o.on('-e END', '--end_date', 'UTC timestamp for ending of Search period (maps to "toDate").
                                      Specified as YYYYMMDDHHMM, \"YYYY-MM-DD HH:MM\", YYYY-MM-DDTHH:MM:SS.000Z or use ##d, ##h or ##m.') { |end_date| $end_date = end_date}
        o.on('-m MAXRESULTS', '--max', 'Specify the maximum amount of data results (maps to "maxResults").  10 to 500, defaults to 100.') {|max_results| $max_results = max_results}  #... as in look before you leap.

        #These trigger the estimation process, based on "duration" bucket size.
        o.on('-l', '--look', '"Look before you leap..."  Triggers the return of counts only via the "/counts.json" endpoint.') {|look| $look = look}  #... as in look before you leap.
        o.on('-d DURATION', '--duration', 'The "bucket size" for counts, minute, hour (default), or day. (maps to "bucket")' ) {|duration| $duration = duration}  

        o.on('-x EXIT', '--exit', 'Specify the maximum amount of requests to make. "Exit app after this many requests."') {|exit_after| $exit_after = exit_after}

        o.on('-w WRITE', '--write',"'files', 'standard-out' (or 'so' or 'standard'), 'store' (database)") {|write| $write = write}
        o.on('-o OUTBOX', '--outbox', 'Optional. Triggers the generation of files and where to write them.') {|outbox| $outbox = outbox}
        o.on('-z', '--zip', 'Optional. If writing files, compress the files with gzip.') {|zip| $zip = zip}

        #Help screen.
        o.on( '-h', '--help', 'Display this screen.' ) do
            puts o
            exit
        end

        o.parse!
    end

    #Create a Tweet Search object.
    oSearch = TweetSearch.new()
    oSearch.rules.rules = Array.new

    #Provided config file, which can provide auth, URL metadata, and app options.
    if !$config.nil?
        oSearch.get_system_config($config)
    end

    #So, we got what we got from the config file, so process what was passed in.
    #Initial "gate-keeping" on what we have been provided.  Enough information to proceed?
    #Anything on command-line overrides configuration setting...

    error_msgs = Array.new

    oSearch.set_requester

    #We need to have at least one rule.
    if !$rule.nil?
        #Rules file provided?
        extension = $rule.split(".")[-1]
        if extension == "yaml" or extension == "json"
            oSearch.rules_file = $rule
            if extension == "yaml" then
                oSearch.rules.loadRulesYAML(oSearch.rules_file)
            end
            if extension == "json"
                oSearch.rules.loadRulesYAML(oSearch.rules_file)
            end


        else
            rule = {}
            rule["value"] = $rule
            oSearch.rules.rules << rule
        end
    else
        error_msgs << "Either a single rule or a rules files is required. "
    end

    #Everything else is option or can be driven by defaults.

    #Tag is completely optional.
    if !$tag.nil?
        rule = {}
        rule = oSearch.rules.rules
        rule[0]["tag"] = $tag
    end

    #Look is optional.
    #Duration is optional, defaults to "hour" which is handled by Search API.
    #Can only be "minute", "hour" or "day".
    if !$duration.nil?
        if !['minute','hour','day'].include?($duration)
            p "Warning: unrecognized duration setting, defaulting to 'minute'."
            $duration = 'minute'
        end
    end

    #start_date, defaults to NOW - 30.days by Search API.
    #end_date, defaults to NOW by Search API.
    # OK, accepted parameters gets a bit fancy here.
    #    These can be specified on command-line in several formats:
    #           YYYYMMDDHHmm or ISO YYYY-MM-DD HH:MM.
    #           14d = 14 days, 48h = 48 hours, 360m = 6 hours
    #    Or they can be in the rules file (but overridden on the command-line).
    #    start_date < end_date, and end_date <= NOW.

    #We need to end up with PowerTrack timestamps in YYYYMMDDHHmm format.
    #If numeric and length = 12 then we are all set.
    #If ISO format and length 16 then apply o.gsub!(/\W+/, '')
    #If ends in m, h, or d, then do some time.add math

    #Handle start date.
    #First see if it was passed in
    if !$start_date.nil?
        oSearch.from_date = Utilities.set_date_string($start_date)
    end

    #Handle end date.
    #First see if it was passed in
    if !$end_date.nil?
        oSearch.to_date = oSearch.set_date_string($end_date)
    end

    #Max results is optional, defaults to 100 by Search API.
    if !$max_results.nil?
        oSearch.max_results = $max_results
    end

    #Max results is optional, defaults to 100 by Search API.
    if !$exit_after.nil?
	    oSearch.exit_after = $exit_after.to_i
    end
    
    #Handle 'write' option
    if !$write.nil?
			oSearch.write_mode = $write
			
			if oSearch.write_mode == "so" or oSearch.write_mode == "standard"
				oSearch.write_mode = "standard-out"
			end
			
    end

    #Writing data to files.
    if !$outbox.nil?
        oSearch.out_box = $outbox
        oSearch.write_mode = "files"

        if !$zip.nil?
            oSearch.compress_files = true
        end
    end

    #Check for configuration errors.
    if error_msgs.length > 0
        puts "Errors in configuration: "
        error_msgs.each { |e|
          puts e
        }

        puts ""
        puts "Please check configuration and try again... Exiting."

        exit
    end
    
    #Wow, we made it all the way through that!  Documentation must be awesome...

    if $look == true #Handle count requests.
        oSearch.rules.rules.each do |rule|
            puts "Getting counts for rule: #{rule["value"]}"
            results = oSearch.get_counts(rule["value"], oSearch.from_date, oSearch.to_date, $duration)
        end
    else #Asking for data!
        oSearch.rules.rules.each do |rule|
            puts "Getting activities for rule: #{rule["value"]}"
            oSearch.get_data(rule["value"], oSearch.from_date, oSearch.to_date)
        end
    end
    
    puts "Exiting"
end
