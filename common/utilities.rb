module Utilities

	#-----------------------------------------------------

	#Confirm a directory exists, creating it if necessary.
	def checkDirectory(directory)
		#Make sure directory exists, making it if needed.
		if not File.directory?(directory)
			FileUtils.mkpath(directory) #logging and user notification.
		end
		directory
	end

	def Utilities.get_date_string(time)
		return time.year.to_s + sprintf('%02i', time.month) + sprintf('%02i', time.day) + sprintf('%02i', time.hour) + sprintf('%02i', time.min)
	end

	def get_date_object(time_string)
		time = Time.new
		time = Time.parse(time_string)
		return time
	end

	def numeric?(object)
		true if Float(object) rescue false
	end

	#Takes a variety of string inputs and returns a standard PowerTrack YYYYMMDDHHMM timestamp string.
	def Utilities.set_date_string(input)

		now = Time.new
		date = Time.new

		#Handle minute notation.
		if input.downcase[-1] == "m"
			date = now - (60 * input[0..-2].to_f)
			return get_date_string(date)
		end

		#Handle hour notation.
		if input.downcase[-1] == "h"
			date = now - (60 * 60 * input[0..-2].to_f)
			return get_date_string(date)
		end

		#Handle day notation.
		if input.downcase[-1] == "d"
			date = now - (24 * 60 * 60 * input[0..-2].to_f)
			return get_date_string(date)
		end

		#Handle PowerTrack format, YYYYMMDDHHMM
		if input.length == 12 and numeric?(input)
			return input
		end

		#Handle "YYYY-MM-DD 00:00"
		if input.length == 16
			return input.gsub!(/\W+/, '')
		end

		#Handle ISO 8601 timestamps, as in Twitter payload "2013-11-15T17:16:42.000Z"
		if input.length > 16
			date = Time.parse(input)
			return get_date_string(date)
		end

		return 'Error, unrecognized timestamp.'

	end

	#-----------------------------------------------------

end
