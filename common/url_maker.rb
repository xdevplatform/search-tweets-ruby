=begin
Helper function for building URLs. Developed for Labs usage.
=end

class URLMaker

		attr_accessor :url, :search_tier, :search_period

	def initialize
		@data_url = "https://api.twitter.com/labs/2/tweets/search" #Versioning.
		@search_tier = 'labs'
		@search_period = 'recent'
	end

	def get_data_url()
		@data_url
	end
	
	def get_count_url()

		return "Counts endpoint not supported in Labs."
		
	end

end
