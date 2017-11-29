require "json"
require "yaml"

#=======================================================================================================================
class PtRules
    attr_accessor :rules

    def initialize
        @rules = Array.new
    end

    #Methods for maintaining the rules array
    def addRule(value, tag=nil)
        #Gotta have a rule value, but tag is optional.
        rule = Hash.new
        rule[:value] = value
        if not tag.nil? then
            rule[:tag] = tag
        end
        #Add rule to rules array.
        @rules << rule
    end

    def deleteRule(value)   #No tag passed in, we remove with 'value' match.
                            #Regardless of tag, tour rules Array and remove.
        @rules.each do |r|
            if r[:value] == value then
                @rules.delete(r)
            end
        end
    end

    #Methods for getting the rules in the structure you want ===========================================================
    def getJSON
        rulesPayload = Hash.new
        rulesPayload[:rules] = @rules
        rulesPayload.to_json
    end

    #Methods for reading rules from files ==============================================================================

    def loadRulesYAML(file)
        #Open file and parse, looking for rule/tag pairs
        ruleset = YAML.load_file(file)
        rules = ruleset["rules"]
        rules.each do |rule|
            #p rule
            @rules << rule
        end
    end

    def loadRulesJSON(file)
        #Open file and parse
        contents = File.read(file)
        ruleset = JSON.parse(contents)
        rules = ruleset["rules"]
        rules.each do |rule|
            @rules << rule
        end
    end

    #Methods for writing rules to files ================================================================================
    def writeRulesYAML(rules)
        puts 'Not implemented.'
    end

    def writeRulesJSON(rules)
        puts 'Not implemented.'
    end

end

