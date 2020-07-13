# A general object that knows how to make HTTP requests.
# A simple, common RESTful HTTP class put together for Twitter RESTful endpoints.
# Does authentication via header, so supports BEARER TOKEN authentication.

#=======================================================================================================================

class Requester
	require "net/https" 
	require "uri"

	attr_accessor :url,
								:uri,
								:data,
								:headers, #i.e. Authentication specified here.
								:bearer_token,
								:request_count,
								:request_limit

	def initialize(url=nil, bearer_token=nil, headers=nil)

		if not url.nil?
			@url = url
		end

		if not headers.nil?
			@headers = headers
		end

		if not bearer_token.nil?
			@bearer_token = bearer_token
		end

		@request_count = 0
		@request_limit = nil #Not set by default. Parent object should make an informed decision.

	end

	def url=(value)
		@url = value
		@uri = URI.parse(@url)
	end

	#Fundamental REST API methods:
	def POST(data=nil)

		if not data.nil? #if request data passed in, use it.
			@data = data
		end

		uri = URI(@url)
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true
		request = Net::HTTP::Post.new(uri.path)
		request.body = @data

		request['Authorization'] = "Bearer #{@bearer_token}"

		if not @headers.nil?
			@headers.each do | key, value|
				request[key] = value
			end
		end

		begin
			response = http.request(request)
		rescue
			logger()
			sleep 5
			response = http.request(request) #try again
		end

		@request_count =+ 1

		return response
	end

	def PUT(data=nil)

		if not data.nil? #if request data passed in, use it.
			@data = data
		end

		uri = URI(@url)
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true
		request = Net::HTTP::Put.new(uri.path)
		request.body = @data

		request['Authorization'] = "Bearer #{@bearer_token}"

		begin
			response = http.request(request)
		rescue
			sleep 5
			response = http.request(request) #try again
		end

		@request_count =+ 1

		return response
	end

	def GET(params=nil)
		uri = URI(@url)

		#params are passed in as a hash.
		#Example: params["max"] = 100, params["since_date"] = 202005010000
		if not params.nil?
			uri.query = URI.encode_www_form(params)
		end

		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true
		request = Net::HTTP::Get.new(uri.request_uri)
		request['Authorization'] = "Bearer #{@bearer_token}"

		if not @headers.nil?
			@headers.each do | key, value|
				request[key] = value
			end
		end

		begin
			response = http.request(request)
		rescue
			sleep 5
			response = http.request(request) #try again
		end

		@request_count =+ 1

		return response
	end

	def DELETE(data=nil)
		if not data.nil?
			@data = data
		end

		uri = URI(@url)
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true
		request = Net::HTTP::Delete.new(uri.path)
		request.body = @data

		request['Authorization'] = "Bearer #{@bearer_token}"

		begin
			response = http.request(request)
		rescue
			sleep 5
			response = http.request(request) #try again
		end

		@request_count =+ 1

		return response
	end

	#This method knows how to take app keys and generate a Bearer token.
	def get_bearer_token(consumer_key, consumer_secret)
# Generates a Bearer Token using your Twitter App's consumer key and secret.
# Calls the Twitter URL below and returns the Bearer Token.
		bearer_token_url = "https://api.twitter.com/oauth2/token"

		credentials = Base64.encode64("#{consumer_key}:#{consumer_secret}").gsub("\n", "")

		uri = URI(bearer_token_url)
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true
		request = Net::HTTP::Post.new(uri.path)
		request.body =  "grant_type=client_credentials"
		request['Authorization'] = "Basic #{credentials}"
		request['User-Agent'] = "LabsRecentSearchQuickStartRuby"

		response = http.request(request)

		body = JSON.parse(response.body)

		body['access_token']
	end
end #Requester class.

