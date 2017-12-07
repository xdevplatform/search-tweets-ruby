class TweetSearch

	require 'json'
	require 'yaml' #Used for configuration files.
	require 'base64'
	require 'fileutils'
	require 'zlib'
	require 'time'

	#Common classes
	require_relative '../common/requester'
	require_relative '../common/rules'
	require_relative '../common/url_maker'
	require_relative '../common/utilities.rb' #Mixin code.
	#require_relative '../common/datastores/datastore'
	
	API_ACTIVITY_LIMIT = 500 #Limit on the number of activity IDs per Rehydration API request, can be overridden.

	attr_accessor :search_type,
	              :archive,
	              :requester, #Knows RESTful HTTP requests.
	              :urlData, #Search uses two different end-points...
	              :urlCount,
	              :url_maker, #Builds request URLs.

	              # Search request parameters	
	              :from_date, :to_date, #'Study' period.
	              :request_from_date, :request_to_date, #May be breaking up 'study' period into separate smaller periods.
	              :interval,
	              :max_results,
	              :count_page_total, #total of individual bucket counts per page/response.
	              :count_total,

	              :auth,
	              :labels,

	              #Filters/Rules details. This client can load an array of filters from files (YAML or JSON) 
	              :rules, #rules object.
	              :rules_file, #YAML (or JSON) file with rules.
	              :write_rules, #[] TODO: ---> Append rule syntax to collected Tweet JSON. Written for AS, works with native?

	              #This client can write to standard-out, files, and soon data stores... 
	              :write_mode, #files, standard out, data store
	              :in_box,
	              :out_box,
	              :compress_files,
	              :datastore, #Knows how to store Tweets.
	              
	              :exit_after,
	              :request_count,
	              :request_timestamp #Used for self-throttling of request rates. 

	def initialize()

		#Defaults.
		@search_type = 'premium'
		@archive = '30day'
		@labels = {}
		@auth = {}
		
		@interval = 'day'
		@max_results = API_ACTIVITY_LIMIT
		@out_box = './outbox'
		@write_mode = 'files'
		@counts_to_standard_out = false

		#Helper objects, singletons.
		@requester = Requester.new #HTTP helper class.
		@url_maker = URLMaker.new #Abstracts away the URL details... 
		@rules = PtRules.new #Can load rules from configuration files.
		#@datastore = Datastore.new

		@exit_after = nil
		@request_count = 0
		@request_timestamp = Time.now - 1 #Used to self-throttle requests.

	end


	#Load in the configuration file details, setting many object attributes.
	def get_system_config(config_file)

		config = YAML.load_file(config_file)

		#Figuring out the app token and label details...
		
		@search_type = config['options']['search_type']
		@archive = config['options']['archive']

		#'Label' details needed for establishing endpoint URI.
		@labels[:environment] = config['labels']['environment'] #Required.
		if !config['labels']['account_name'].nil? #Only for enterprise..
			@labels[:account_name] = config['labels']['account_name']
		end

		#Authentication details.  
		@auth[:app_token] = config['auth']['app_token'] #Required.
		if !config['auth']['password'].nil? #Only for enterprise BASIC auth. 
			@auth[:password] = config['auth']['password']
		end
		if !config['auth']['headers'].nil?
			@auth[:headers] = config['auth']['headers']
		end

=begin
			if !config["account"]["password"].nil? or !config["account"]["password_encoded"].nil?
				@password_encoded = config["account"]["password_encoded"]

				if @password_encoded.nil? #User is passing in plain-text password...
					@password = config["account"]["password"]
					@password_encoded = Base64.encode64(@password)
				end
			end
=end

		@write_mode = config['options']['write_mode']
		@counts_to_standard_out = config['options']['counts_to_standard_out']

		begin
			@out_box =  Utilities.checkDirectory(config['options']['out_box'])
		rescue
			@out_box = './outbox'
		end

		begin
			@compress_files = config['options']['compress_files']
		rescue
			@compress_files = false
		end


		if @write_mode == 'database' #Get database connection details.
			db_host = config['database']['host']
			db_port = config['database']['port']
			db_schema = config['database']['schema']
			db_user_name = config['database']['user_name']
			db_password = config['database']['password']

			#@datastore = Database.new(db_host, db_port, db_schema, db_user_name, db_password)
			#@datastore.connect
		end
	end

	def set_requester

		@requester.search_type = @search_type
		@requester.app_token = @auth[:app_token] #Set the info needed for authentication.
		@requester.password = @auth[:password] #HTTP class can decrypt password.
		@requester.headers = @auth[:headers]

		#@urlData = @requester.getFaSearchURL(@account_name, @environment)
		@urlData = @url_maker.getDataURL(@search_type, @archive, @labels)

		#@urlCount = @requester.getFaSearchCountURL(@account_name, @environment)
		@urlCount = @url_maker.getCountURL(@search_type, @archive, @labels)

		#Default to the "data" url.
		@requester.url = @urlData #Pass the URL to the HTTP object.
	end

	def get_search_rules
		if !@rules_file.nil #TODO: Add JSON option.
			@rules.loadRulesYAML(@rules_file)
		end
	end

	# [] TODO: needs to check for existing file name, and serialize if needed.
	# Payloads are descending chronological, first timestamp is end_time, last is start_time.  Got it?
	def get_file_name(rule, results)

		#Format specific parsing.
		time_stamp = ""
		if results.first.has_key?("postedTime")
			format = 'as'
		else
			format = 'native'
		end


		#[] TODO: Drop AS format?
		if format == 'as'
			time_first = Time.parse(results.first['postedTime'])
			time_last = Time.parse(results.last['postedTime'])
		elsif format == 'native'
			time_first = Time.parse(results.first['created_at'])
			time_last = Time.parse(results.first['created_at'])
		end

		start_time = time_first.year.to_s + sprintf('%02i', time_first.month) + sprintf('%02i', time_first.day) + sprintf('%02i', time_first.hour) + sprintf('%02i', time_first.min) + sprintf('%02i', time_first.sec)
		end_time = time_last.year.to_s + sprintf('%02i', time_last.month) + sprintf('%02i', time_last.day) + sprintf('%02i', time_last.hour) + sprintf('%02i', time_last.min) + sprintf('%02i', time_last.sec)

		rule_str = rule.gsub(/[^[:alnum:]]/, "")[0..9]
		filename = "#{rule_str}_#{start_time}_#{end_time}"
		return filename
	end

	# TODO: needs to check for existing file name, and serialize if needed.
	# Payloads are descending chronological, first timestamp is end_time, last is start_time.  Got it?
	def get_counts_file_name(rule, results)

		#Get start_time of this response payload.
		time = Time.parse(results.first['timePeriod'])
		end_time = time.year.to_s + sprintf('%02i', time.month) + sprintf('%02i', time.day) + sprintf('%02i', time.hour) + sprintf('%02i', time.min) + sprintf('%02i', time.sec)

		#Get end_time of this response payload.
		time = Time.parse(results.last['timePeriod'])
		start_time = time.year.to_s + sprintf('%02i', time.month) + sprintf('%02i', time.day) + sprintf('%02i', time.hour) + sprintf('%02i', time.min) + sprintf('%02i', time.sec)

		rule_str = rule.gsub(/[^[:alnum:]]/, "")[0..9]
		filename = "#{rule_str}_#{start_time}_#{end_time}"

		filename
	end

	#Builds a hash and generates a JSON string.
	#Defaults:
	#@interval = "hour"   #Set in constructor.
	#@max_results = API_ACTIVITY_LIMIT   #Set in constructor.

	def build_request(rule, from_date=nil, to_date=nil)
		request = {}

		request[:query] = rule

		if !from_date.nil?
			request[:fromDate] = from_date
		end

		if !to_date.nil?
			request[:toDate] = to_date
		end

		request
	end

	def build_counts_request(rule, from_date=nil, to_date=nil, interval=nil, next_token=nil)

		request = build_request(rule, from_date, to_date)

		if !interval.nil?
			request[:bucket] = interval
		else
			request[:bucket] = @interval
		end

		if !next_token.nil?
			request[:next] = next_token
		end

		JSON.generate(request)
	end

	def build_data_request(rule, from_date=nil, to_date=nil, max_results=nil, next_token=nil)

		request = build_request(rule, from_date, to_date)

		request[:tag] = rule['tag'] if not rule['tag'].nil?

		if !max_results.nil?
			request[:maxResults] = max_results
		else
			request[:maxResults] = @max_results #This client
		end

		if !next_token.nil?
			request[:next] = next_token
		end

		JSON.generate(request)
	end

	def get_count_total(count_response)

		count_total = 0

		#puts count_response

		contents = JSON.parse(count_response)
		results = contents["results"]
		results.each do |result|
			count_total = count_total + result["count"]
		end

		@count_page_total = count_total
	end

	def make_counts_request(rule, start_time, end_time, interval, next_token)

		@requester.url = @urlCount

		results = {}
		@count_page_total = 0

		data = build_counts_request(rule, start_time, end_time, interval, next_token)

		if (Time.now - @request_timestamp) < 1
			sleep 1
		end
		@request_timestamp = Time.now

		begin
			response = @requester.POST(data)
		rescue
			sleep 5
			response = @requester.POST(data) #try again
		end

		if response.code == "200"
			#Parse response.body and build ordered array.
			temp = JSON.parse(response.body)

			next_token = temp['next']
			@count_page_total = temp['totalCount']
			@count_total = @count_total + @count_page_total

			results['total'] = @count_page_total

			results['results'] = temp['results']

		else

			puts "ERROR occurred: #{response.code}  #{response.message} --> #{response.body}"
		end

		if @write_mode == "files" #write the file.

			#Each 'page' has a start and end time, go get those for generating filename.

			filename = get_counts_file_name(rule, temp['results'])
			filename_root = filename

			if @compress_files

				num = 0
				until not File.exists?("#{@out_box}/#{filename}.json")
					num += 1
					filename = "#{filename_root}_#{num}"
				end

				puts "Storing Search API data in GZIPPED file: #{filename}"
				File.open("#{@out_box}/#{filename}.json.gz", 'w') do |f|
					gz = Zlib::GzipWriter.new(f, level=nil, strategy=nil)
					gz.write api_response.to_json
					gz.close
				end
			else
				num = 0
				until not File.exists?("#{@out_box}/#{filename}.json")
					num += 1
					filename = "#{filename_root}_#{num}"
				end


				puts "Storing Search API data in file: #{filename}"
				File.open("#{@out_box}/#{filename}.json", "w") do |new_file|
					new_file.write(temp.to_json)
				end
			end
		else
			puts results
		end

		next_token

	end

	def make_data_request(rule, start_time, end_time, max_results, next_token)

		@requester.url = @urlData
		data = build_data_request(rule, start_time, end_time, max_results, next_token)

		if (Time.now - @request_timestamp) < 1
			sleep 1
		end
		@request_timestamp = Time.now

		#puts data

		begin
			response = @requester.POST(data)
		rescue
			sleep 5
			response = @requester.POST(data) #try again
		end

		#Prepare to convert Search API JSON to hash.
		api_response = []
		api_response = JSON.parse(response.body)

		if !(api_response["error"] == nil)
			puts "Error: #{api_response["error"]["message"]}"
		end

		if (api_response['results'].length == 0)
			puts "No results returned."
			return api_response['next']
		end

		if @write_mode == "files" #write the file.

			#Each 'page' has a start and end time, go get those for generating filename.

			filename = ""
			filename = get_file_name(rule, api_response['results'])

			puts "Storing Search API data in file: #{filename}"

			if @compress_files
				File.open("#{@out_box}/#{filename}.json.gz", 'w') do |f|
					gz = Zlib::GzipWriter.new(f, level=nil, strategy=nil)
					gz.write api_response.to_json
					gz.close
				end
			else
				File.open("#{@out_box}/#{filename}.json", "w") do |new_file|
					new_file.write(api_response.to_json)
				end
			end
		elsif @write_mode == "datastore" #store in database.
			puts "Storing Tweet data in data store..."

			results = []
			results = api_response['results']

			results.each do |tweet|

				#p activity
				@datastore.storeTweet(tweet.to_json)
			end
		else #Standard out
			results = []
			results = api_response['results']
			results.each do |activity|
				puts activity.to_json #Standard out...
			end
		end

		#Return next_token, or 'nil' if there is not one provided.
		api_response['next']
	end

	def get_counts(rule, start_time, end_time, interval)

		@write_mode = 'standard-out' if  @counts_to_standard_out
		next_token = 'first request'
		@count_total = 0

		time_span = "#{start_time} to #{end_time}.  "
		if start_time.nil? and end_time.nil?
			time_span = "last 30 days."
		elsif start_time.nil?
			time_span = "30 days ago to #{end_time}. "
		elsif end_time.nil?
			time_span = "#{start_time} to now.  "
		end

		#TODO: puts "Retrieving counts for rule: #{rule}"
		#TODO: puts "For time period: #{time_span}..."

		while !next_token.nil? do

			@request_count += 1
			
			if next_token == 'first request'
				next_token = nil
			end
			next_token = make_counts_request(rule, start_time, end_time, interval, next_token)

			if !@exit_after.nil?
				if @request_count >= @exit_after
					puts "Hit request threshold of #{@exit_after} requests. Quitting."
					exit
				end
			end
		end

		#TODO: puts "Total counts: #{@count_total}"
		puts "#{@count_total}"

		#puts "#{time_span} #{@count_total}"
		#puts "#{time_span[4..5]}/#{time_span[0..3]} #{@count_total}" #useful for creating monthly plots

	end

	#Make initial request, and look for 'next' token, and re-request until the 'next' token is no longer provided.
	def get_data(rule, start_time, end_time)

		next_token = 'first request'

		time_span = "#{start_time} to #{end_time}.  "
		if start_time.nil? and end_time.nil?
			time_span = "last 30 days."
		elsif start_time.nil?
			time_span = "30 days ago to #{end_time}. "
		elsif end_time.nil?
			time_span = "#{start_time} to now.  "
		end

		puts "Retrieving data from #{time_span}..."

		while !next_token.nil? do
			
			@request_count += 1
						
			if next_token == 'first request'
				next_token = nil
			end
			#puts "Next token: #{next_token}"
			next_token = make_data_request(rule, start_time, end_time, max_results, next_token)
			
			if !@exit_after.nil?
				if @request_count >= @exit_after 
					puts "Hit request threshold of #{@exit_after} requests. Quitting."
					exit
				end
			end
		end

	end #process_data

end #TweetSearch class.
