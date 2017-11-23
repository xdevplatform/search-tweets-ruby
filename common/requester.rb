# Knows how to make HTTP requests. 
# A simple, common RESTful HTTP class put together for Twitter RESTful endpoints.
# Does authentication via header, so supports BASIC and BEARER TOKEN authentication.

# Written with Twitter both premium and enterprise search in mind:
# Premium Search Tweets: 30-Day
# Enterprise 30-Day Search API
# Enterprise Full-Archive Search API

# [] Following implementation may be useful as pseudo-code for other languages.

#=======================================================================================================================

class Requester
	require "net/https" # [] Replace with rest-client gem? https://github.com/rest-client/rest-client
	require "uri"

	attr_accessor :product,
	              :url,
	              :uri,
	              :data,
	              :headers, #i.e. Authentication specified here.
	              :app_token, #username or bearer token
	              :password #Needed for BASIC auth.


	def initialize(url=nil, app_token=nil, headers=nil, password=nil)

		if not url.nil?
			@url = url
		end

		if not headers.nil?
			@headers = headers
		end

		if not app_token.nil?
			@app_token = app_token
		end

		if not password.nil?
			@password = password
			#@password = Base64.decode64(@password_encoded)
		end
	end

	def url=(value)
		@url = value
		@uri = URI.parse(@url)
	end

	def password_encoded=(value)
		@password_encoded=value
		if not @password_encoded.nil? then
			@password = Base64.decode64(@password_encoded)
		end
	end


	#Fundamental REST API methods:
	def POST(data=nil, headers=nil)

		if not data.nil? #if request data passed in, use it.
			@data = data
		end

		uri = URI(@url)
		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true
		request = Net::HTTP::Post.new(uri.path)
		request.body = @data

		if @product == 'premium'
			request['Authorization'] = "Bearer #{@app_token}"
		else
			request.basic_auth(@app_token, @password)
		end

		begin
			response = http.request(request)
		rescue
			logger()
			sleep 5
			response = http.request(request) #try again
		end

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

		if @product == 'premium'
			request['Authorization'] = "Bearer #{@app_token}"
		else
			request.basic_auth(@app_token, @password)
		end

		begin
			response = http.request(request)
		rescue
			sleep 5
			response = http.request(request) #try again
		end

		return response
	end

	def GET(params=nil)
		uri = URI(@url)

		#params are passed in as a hash.
		#Example: params["max"] = 100, params["since_date"] = 20130321000000
		if not params.nil?
			uri.query = URI.encode_www_form(params)
		end

		http = Net::HTTP.new(uri.host, uri.port)
		http.use_ssl = true
		request = Net::HTTP::Get.new(uri.request_uri)

		if @product == 'premium'
			request['Authorization'] = "Bearer #{@app_token}"
		else
			request.basic_auth(@app_token, @password)
		end

		begin
			response = http.request(request)
		rescue
			sleep 5
			response = http.request(request) #try again
		end

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

		if @product == 'premium'
			request['Authorization'] = "Bearer #{@app_token}"
		else
			request.basic_auth(@app_token, @password)
		end

		begin
			response = http.request(request)
		rescue
			sleep 5
			response = http.request(request) #try again
		end

		return response
	end
end #Requester class.

