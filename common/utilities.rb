#Collection of general helper methods.
#
# So far, things like
# + date object helpers.
# + Support for a variety of timestamp formats.
# + A few file-handling helpers:
# 	+ Writing/reading 'state' file.
#   + Checking for folder and creating it if it does not exist.

module Utilities

	def Utilities.checkDirectory(directory) #Confirm a directory exists, creating it if necessary.
		#Make sure directory exists, making it if needed.
		if not File.directory?(directory)
			FileUtils.mkpath(directory) #logging and user notification.
		end
		directory
  end

  def Utilities.numeric?(object)
    true if Float(object) rescue false
	end

	# def Utilities.file_exists?(file_path)
	# 	return File.exist?(file_path)
	# end

	def Utilities.write_file(file_path, data)

		begin
			f = File.new(file_path, 'w')
			f.write(data)
			f.close
		rescue
			puts 'Error writing file...'
			return false
		end

		return true
	end

	def Utilities.read_id(file_path)

		file = File.open(file_path)

		data = file.read

		return data


	end


	#Date helpers.

	def Utilities.get_date_string(time)
		return time.year.to_s + sprintf('%02i', time.month) + sprintf('%02i', time.day) + sprintf('%02i', time.hour) + sprintf('%02i', time.min)
	end

	def Utilities.get_date_ISO_string(time)
		return "#{time.year.to_s}-#{sprintf('%02i', time.month)}-#{sprintf('%02i', time.day)}T#{sprintf('%02i', time.hour)}:#{sprintf('%02i', time.min)}:00Z"
	end

	def Utilities.get_date_object(time_string)
		time = Time.new
		time = Time.parse(time_string)
		return time
	end

	#Takes a variety of string inputs and returns a standard Twitter Labs timestamp string.
	def Utilities.set_date_string(input)

		now = Time.new
		date = Time.new

		#Handle minute notation.
		if input.downcase[-1] == "m"
			date = now.utc - (60 * input[0..-2].to_f)
		  return get_date_ISO_string(date)
		end

		#Handle hour notation.
		if input.downcase[-1] == "h"
			date = now.utc - (60 * 60 * input[0..-2].to_f)
      return get_date_ISO_string(date)
		end

		#Handle day notation.
		if input.downcase[-1] == "d"
			date = now.utc - (24 * 60 * 60 * input[0..-2].to_f)
			#Double check if 7 days were passed in, and if so, add 60 seconds
			if input[0..-2] == '7'
				date = date + 60
			end
			return get_date_ISO_string(date)
		end

		#Handle premium/enterprise format, YYYYMMDDHHMM
		if input.length == 12 and numeric?(input)
			date = Time.new(input[0..3],input[4..5],input[6..7],input[8..9],input[10..11])
			return get_date_ISO_string(date)
		end

		#Handle "YYYY-MM-DD 00:00"
		if input.length == 16
			date = Time.new(input[0..3],input[5..6],input[8..9],input[11..12],input[14..15])
      return get_date_ISO_string(date)
		end

		#Handle ISO 8601 timestamps, as in Twitter payload "2013-11-15T17:16:42.000Z"
		if input.length > 16
			date = Time.parse(input)
			return get_date_ISO_string(date)
		end

		return 'Error, unrecognized timestamp.'
	end
end
