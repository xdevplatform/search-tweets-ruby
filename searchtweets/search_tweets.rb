#A singleton that knows how to make requests to the Twitter Developer Labs Recent search endpoint.
#
# Example usage:
#   require_relative "../searchtweets/tweets-search.rb"
#
#   oSearchClient = TweetsSearch.new()
#   tweet_array, newest_id = oSearchClient.get_data(query["value"])


class SearchTweets

  require 'json'
  require 'yaml' #Used for configuration files.
  require 'base64' #Needed if managing encrypted passwords.
  require 'fileutils'
  require 'time'

  #Common classes
  require_relative '../common/requester'
  require_relative '../common/queries'
  require_relative '../common/url_maker'
  require_relative '../common/utilities.rb' #Mixin code.

  MAX_RESULTS_LIMIT = 100 #Limit on the number of Tweet IDs per API request, can be overridden.

  attr_accessor :tweets, #An array of Tweet JSON objects.
                :includes, #A hash of 'includes' object arrays.

                :verbose, #This code is chatty when true, mute with false.

                :request_count, #Tracks how many requests have been made.
                :tweet_count, #Tracks how many Tweets have been returned (Labs only).
                :request_timestamp, #Used for self-throttling of request rates.
                :first_request, #Polling mode triggers some 'special' first-run logic.

                :start_time_study, #'Study' period. Future versions will likely support periods longer than 7 days.
                :end_time_study,
                :newest_id_study,
                :oldest_id_study,

                # Search request parameters
                :queries, #An array of queries.
                :start_time,
                :end_time,

                :since_id,
                :until_id,
                :max_results,

                :expansions,

                :fields,

                :auth, #Keys or Bearer-token from YAML file.

                #Helper objects.
                :requester, #Object that knows RESTful HTTP requests.
                :urlData, #Search uses two different end-points...
                :url_maker, #Object that builds request URLs.

                :exit_after, #Supports user option to quit after x requests.
                #:request_start_time, #May be breaking up 'study' period into separate smaller periods.
                #:request_end_time,

                #Query details. This client can load an array of queries from files (YAML or JSON)
                :query_file, #YAML (or JSON) file with queries.

                #This client can write to standard-out, files, and soon data stores...
                :write_rules,
                :write_mode, #files, standard out, hash
                :in_box,
                :out_box


  def initialize()

    #Override and/or add to defaults
    @tweet_fields = "id,created_at,author_id,text"  #Adding created_at and author_id to Labs v2 defaults.
    #Other objects need things added to Twitter defaults? Want to set a @expansions default?

    @tweets = []

    @includes = {}
    @includes['tweets'] = []
    @includes['users'] = []
    @includes['media'] = []
    @includes['places'] = []
    @includes['polls'] = []
    @includes['errors'] = []

    @fields = {}
    @fields['tweet'] = ''
    @fields['user'] = ''
    @fields['media'] = ''
    @fields['place'] = ''
    @fields['poll'] = ''

    @auth = {} #Hash for authentication keys, secrets, and tokens.

    #Defaults.
    @max_results = MAX_RESULTS_LIMIT
    @exit_after = nil #Can be set to 'nil' to not limit requests.
    @out_box = './outbox'
    @write_mode = 'standard_out' #Client defaults to writing output to standard out.

    #Helper objects, singletons.
    @requester = Requester.new #HTTP helper class.
    @url_maker = URLMaker.new #Abstracts away the URL details...
    @queries = Queries.new #Can load queries from configuration files.

    @request_count = 0
    @tweet_count = 0
    @request_timestamp = Time.now - 1 #Used to self-throttle requests. Running script generates at least one request.

    @verbose = false
  end

  #Load in the configuration file details, setting many object attributes.
  def get_system_config(config_file)

    config = YAML.load_file(config_file)

    #TODO: Update README to match these updates:

    #First, for authentication, look at ENV settings and see if these are set.
    bearer_token = ENV['TWITTER_BEARER_TOKEN']
    consumer_key = ENV['TWITTER_CONSUMER_KEY']
    consumer_secret = ENV['TWITTER_CONSUMER_SECRET']

    if bearer_token.nil?
      if not consumer_key.nil? and not consumer_secret.nil?
        @auth[:bearer_token] = @requester.get_bearer_token(consumer_key, consumer_secret)
      end
    else
      @auth[:bearer_token] = bearer_token
    end

    #If not Bearer Token, then config_file is last chance.
    if @auth[:bearer_token].nil? or @auth[:bearer_token] == ''
      #Look in confile_file
      bearer_token = config['auth']['bearer_token'] #Required.
      consumer_key = config['auth']['consumer_key']
      consumer_secret = config['auth']['consumer_secret']

      if bearer_token == nil or bearer_token == ''
        @auth[:bearer_token] = @requester.get_bearer_token( consumer_key, consumer_secret )
      else
        @auth[:bearer_token] = bearer_token
      end

    end

    if !config['headers'].nil?
      @headers = config['headers']
    end

    @max_results = config['options']['max_results']

    @expansions = config['options']['expansions']

    #Load in object fields.
    @fields['tweet'] = config['options']['tweet.fields']
    @fields['user'] = config['options']['user.fields']
    @fields['media'] = config['options']['media.fields']
    @fields['place'] = config['options']['place.fields']
    @fields['poll'] = config['options']['poll.fields']

    #Support shorthands for different formats.
    @write_mode = config['options']['write_mode']
    @write_mode = 'standard_out' if @write_mode == 'so'

    #Handle outbox options.
    begin
      @out_box = Utilities.checkDirectory(config['options']['out_box'])
    rescue
      @out_box = './outbox'
    end

  end

  def set_requester

    @requester.bearer_token = @auth[:bearer_token] #Set the info needed for authentication.
    @requester.headers = @headers

    @urlData = @url_maker.get_data_url()

    #Default to the "data" url.
    @requester.url = @urlData #Pass the URL to the HTTP object.
  end

  def get_search_rules
    if !@query_file.nil #TODO: Add JSON option.
      @queries.load_query_yaml(@query_file)
    end
  end

  def get_file_name(query, results)

    time_first = Time.parse(results.first['created_at'])
    time_last = Time.parse(results.first['created_at'])

    start_time = time_first.year.to_s + sprintf('%02i', time_first.month) + sprintf('%02i', time_first.day) + sprintf('%02i', time_first.hour) + sprintf('%02i', time_first.min) + sprintf('%02i', time_first.sec)
    end_time = time_last.year.to_s + sprintf('%02i', time_last.month) + sprintf('%02i', time_last.day) + sprintf('%02i', time_last.hour) + sprintf('%02i', time_last.min) + sprintf('%02i', time_last.sec)

    query_str = query.gsub(/[^[:alnum:]]/, "")[0..9]
    filename = "#{query_str}_#{start_time}_#{end_time}"

    return filename
  end

  def set_request_range(start_time = nil, end_time = nil, since_id = nil, until_id = nil)
    request = {}

    if !start_time.nil?
      request[:start_time] = start_time
    end

    if !end_time.nil?
      request[:end_time] = end_time
    end

    if not since_id.nil?
      request[:since_id] = since_id
    end

    if not until_id.nil?
      request[:until_id] = until_id
    end

    request
  end

  def build_data_request(query, start_time = nil, end_time = nil, since_id = nil, until_id = nil, max_results = nil, expansions = nil, fields = nil, next_token = nil)

    request = set_request_range(start_time, end_time, since_id, until_id)

    request[:query] = query

    request[:expansions] = expansions

    #Handle JSOPN fields.
    if fields.key?('tweet')
      request['tweet.fields'] = fields['tweet']
    end
    if fields.key?('user')
      request['user.fields'] = fields['user']
    end
    if fields.key?('media')
      request['media.fields'] = fields['media']
    end
    if fields.key?('place')
      request['place.fields'] = fields['place']
    end
    if fields.key?('poll')
      request['poll.fields'] = fields['poll']
    end

    if !max_results.nil?
      request[:max_results] = max_results
    else
      request[:max_results] = @max_results
    end

    if !next_token.nil?
      request[:next_token] = next_token
    end

    request
  end

  def write_standard_out(api_response)

    if api_response.key?('data')
      puts "Matching Tweets:"
      results = api_response['data']
      results.each do |tweet|
        puts tweet.to_json #Standard out...
      end
    end
    if api_response.key?('includes')
      results = api_response['includes']
      if results.key?('users')
        puts "Expanded user objects:"
        users = results['users']
        users.each do |user|
          puts user.to_json
        end
      end
      if results.key?('tweets')
        puts "Expanded Tweet objects for referenced Tweets:"
        tweets = results['tweets']
        tweets.each do |tweet|
          puts tweet.to_json
        end
      end
      if results.key?('media')
        puts "Expanded media objects:"
        media = results['media']
        media.each do |media|
          puts media.to_json
        end
      end
      if results.key?('places')
        puts "Expanded place objects:"
        places = results['places']
        places.each do |place|
          puts place.to_json
        end
      end
      if results.key?('polls')
        puts "Expanded poll objects:"
        polls = results['polls']
        polls.each do |poll|
          puts poll.to_json
        end
      end
    end
    if api_response.key?('errors')
      puts "Access errors:"
      errors = api_response['errors']
      errors.each do |error|
        puts error.to_json
      end
    end

  end

  def maintain_includes_arrays(api_response)

    puts "Loading 'includes' payload." if @verbose
    includes = api_response['includes']

    if not includes.nil?

      if includes.key?("users")
        puts "Adding user objects."
        users = includes['users']
        puts "Loading 'includes' users array.." if @verbose
        users.each do |user|
          @includes['users'] << user #Pushing into a non-indexed user array that can/will have duplicates.
        end
      end

      if includes.key?("tweets")
        puts "Adding referenced Tweet objects." if @verbose
        tweets = includes['tweets']
        tweets.each do |tweet|
          @includes['tweets'] << tweet
        end
      end

      if includes.key?("media")
        puts "Adding media objects." if @verbose
        media = includes['media']
        media.each do |media|
          @includes['media'] << media
        end
      end

      #TODO: implement adding to array.
      if includes.key?("places")
        puts "Adding place objects." if @verbose
      else
        puts "No place objects." if @verbose
      end

      #TODO: implement adding to array.
      if includes.key?("polls")
        puts "Adding poll objects." if @verbose
      else
        puts "No poll objects." if @verbose
      end
    end
  end

  def make_data_request(query, start_time, end_time, since_id, until_id, max_results, expansions, fields, next_token)

    result_count = nil #Only Labs returns this.

    @requester.url = @urlData

    request_data = build_data_request(query, start_time, end_time, since_id, until_id, max_results, expansions, fields, next_token)

    if (Time.now - @request_timestamp) < 1
      sleep 1
    end
    @request_timestamp = Time.now

    #puts data

    #Labs supports GET only, premium/enterprise support GET and POST (preferred).
    begin
      response = @requester.GET(request_data)

    rescue
      puts 'Error occurred with request, retrying... '
      sleep 5
      response = @requester.GET(request_data)
    end

    if response.code.to_i > 201
      puts "#{response.code} error. #{response.message}. #{response.body}"
      error_json = JSON.parse(response.body)

      if response.code.to_i == 503

        puts "Server-side error, sleeping for 30 seconds before retrying."
        sleep 30

      elsif response.code.to_i == 429
        puts "Hit request rate limit, sleeping for 1 minute before retrying."
        sleep 60
      else
        #TODO: If we are asking about an ID too old, it would be nice to grab the suggested timestamp and Tweet ID to correct request.

        if error_json['errors'][0]['message'].include?('tweet id created after') and error_json['errors'][0]['message'].include?("'since_id' that is larger than")
          #'since_id' must be a tweet id created after [TIMESTAMP]. Please use a 'since_id' that is larger than "ID"
          created_after = ''
          id_after = 0
        end

        puts "Quitting"
        exit
      end
    end

    #Prepare to convert Search API JSON to hash.
    #api_response = []
    api_response = JSON.parse(response.body)

    if @write_mode == 'files' #write the file.

      #Each 'page' has a start and end time, go get those for generating filename.

      filename = ""
      #TODO: just pass in first timestamp: results.first['created_at']
      filename = get_file_name(query, api_response['data'])

      puts "Storing Search API data in file: #{filename}"
      File.open("#{@out_box}/#{filename}.json", "w") do |new_file|
          new_file.write(api_response.to_json)
      end

    elsif @write_mode == 'standard_out' #Standard out
      write_standard_out(api_response)

    else #if hash, load up array

      #Maintain array!
      tweets = api_response['data']
      puts 'Loading response into @tweets array..' if @verbose
      tweets.each do |tweet|
        @tweets << tweet
      end

      maintain_includes_arrays(api_response)

    end

    if !api_response['meta'].nil?

      if @verbose
        puts "\nResponse metadata:"
        puts api_response['meta']
        puts "\n"
      end
    end

    return api_response['meta']

  end

  #Make initial request, and look for 'next' token, and re-request until the 'next' token is no longer provided.
  def get_data(query, start_time, end_time, since_id, until_id)

    #Going to be making data requests, so load auth details.
    #bearer_token = ENV['TWITTER_BEARER_TOKEN']

    #next_token = nil
    @request_count = 0
    @tweet_count = 0
    response_metadata = {}

    # Handle output options. Either writing to output now, or adding to @tweets array.
    if @verbose
      case
        when @write_mode == 'files'
          puts 'Writing to files.'
        when @write_mode == 'standard_out'
          puts 'Writing to standard out.'
        when @write_mode == 'hash'
          puts 'Writing to array of Tweets.'
        when @write_mode == 'json'
          puts 'Writing to array of Tweets.'
        else
          puts "Unhandled output mode?"
      end
    end

    loop do
      @request_count += 1

      puts response_metadata['next_token'] if @verbose

      if response_metadata['next_token'] == nil
        #If first response, grab the meta.newest_id.
        first_request = true
      end

      response_metadata = make_data_request(query, start_time, end_time, since_id, until_id, @max_results, @expansions, @fields, response_metadata['next_token'])

      @tweet_count += response_metadata['result_count'] if not response_metadata['result_count'].nil?

      if first_request
        puts "Persisting newest ID from first request: #{response_metadata['newest_id']}" if @verbose

        if response_metadata.key?('newest_id')
          @newest_id_study = response_metadata['newest_id'].to_i
        else
          @newest_id_study = since_id
        end

        first_request = false #Do just once.
      end

      if not @exit_after == nil and @requester.request_count >= @exit_after
        puts "Hit request threshold of #{@exit_after} requests. Quitting at #{Time.now}."
      end

      #If we either reach the end of the token road or have made the maximum number of requests.
      break if response_metadata['next_token'].nil? or (not @exit_after == nil and @request_count >= @exit_after)

      puts "Response has 'meta.next_token', making another request... \n" if @verbose

    end

    #puts "Made #{@request_count} data requests." #if @verbose
    @request_count > 1 ? (puts "Made #{@request_count} data requests.") : (puts "Made #{@request_count} data request.") if @verbose
    @tweet_count == 1 ? (puts "Received #{@tweet_count} Tweet.") : (puts "Received #{@tweet_count} Tweets.") if @verbose
    puts "Next polling cycle: since_id = #{@newest_id_study}" if @verbose

    #These outputs are handled once at the end:

    #With standard out, we have completely our output work, and only need to return the newest ID.
    return nil, nil, @newest_id_study if @write_mode == 'standard_out'

    #With the 'hash' and 'json' options, we accumulated Tweet and 'includes' objects across multiple pagination requests.
    # So assemble the 'includes' structure
    return @tweets, @includes, @newest_id_study if @write_mode == 'hash'
    return @tweets.to_json, @includes.to_json, @newest_id_study if @write_mode == 'json'
  end #get_data

end #SearchTweets class.
