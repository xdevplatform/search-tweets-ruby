require "json"
require "yaml"

#=======================================================================================================================
class Queries
    attr_accessor :queries

    def initialize
        @queries = Array.new
    end

    #Methods for maintaining the rules array
    def add_query(value, tag=nil)
        #Gotta have a rule value, but tag is optional.
        query = Hash.new
        query[:value] = value
        if not tag.nil? then
            query[:tag] = tag
        end
        #Add rule to rules array.
        @queries << query
    end

    def delete_query(value)   #No tag passed in, we remove with 'value' match.
                            #Regardless of tag, tour rules Array and remove.
        @queries.each do |r|
            if r[:value] == value then
                @queries.delete(r)
            end
        end
    end

    #Methods for getting the rules in the structure you want ===========================================================
    def get_JSON
        queryPayload = Hash.new
        queryPayload[:queries] = @queries
        queryPayload.to_json
    end

    #Methods for reading queries from files ==============================================================================

    def load_query_yaml(file)
        #Open file and parse, looking for rule/tag pairs
        queryset = YAML.load_file(file)
        queries = queryset["queries"]
        queries.each do |query|
            #puts query
            @queries << query
        end
    end

    def load_query_json(file)
        #Open file and parse
        contents = File.read(file)
        queryset = JSON.parse(contents)
        queries = queryset["queries"]
        queries.each do |query|
            @queries << query
        end
    end
end
