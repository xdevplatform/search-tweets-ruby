=begin
Helper function for building URLs.

Premium Search example:
	labels = {}
	labels['label'] = 'dev'
	search-app.countURL = URLMaker.getSearchCountURL('premium', labels)

Enterprise Search example:
	labels = {}
	labels['account_name'] = 'thinksnow'
	labels['label'] = 'dev'
	search-app.countURL = URLMaker.getSearchCountURL('enterprise', labels)
=end

class URLMaker

	
	#CONSTANTS
	#root uris
	PREMIUM_ROOT = "https://api.twitter.com/1.1/tweets/search/"
	ENTERPRISE_ROOT = "https://gnip-api.twitter.com/search/"
		
	attr_accessor :product, #'premium' or 'enterprise'.
	              :archive, #'30day' or 'fullarchive'.
	              :account_name, #Enterprise only.
	              :environment, #'dev', 'prod', and 'sandbox' are common examples.
	              :url

	def initialize
		@search_type = 'premium'
		@archive = '30day'
		@account_name = nil   #Being explicit about this. If not set, we have 'premium'.
		@environment = 'dev'  #Best practice is to have a 'dev' environment. So a decent default.
	end

	def getDataURL(product, archive, labels)
		if product == 'premium'
			#https://api.twitter.com/1.1/tweets/search/{archive}/{environment}.json
			@url = "#{PREMIUM_ROOT}#{archive}/#{labels[:environment]}.json"
		end

		if product == 'enterprise'
			#https://gnip-api.twitter.com/search/{archive}/accounts/{account_name}/{environment}.json
			@url = "#{ENTERPRISE_ROOT}#{archive}/accounts/#{labels[:account_name]}/#{labels[:environment]}.json"
		end
		
		@url
	end
	
	def getCountURL(product, archive, labels)

		if product == 'premium'
			#https://api.twitter.com/1.1/tweets/search/{archive}/{environment}/counts.json
			@url = "#{PREMIUM_ROOT}#{archive}/#{labels[:environment]}/counts.json"
		end

		if product == 'enterprise'
			#https://gnip-api.twitter.com/search/{archive}/accounts/{account_name}/{environment}/counts.json
			@url = "#{ENTERPRISE_ROOT}#{archive}/accounts/#{labels[:account_name]}/#{labels[:environment]}/counts.json"
		end
		
		@url
		
	end

end