require_relative './common/app_logger'
require_relative './common/restful'
require_relative './rules/rule_translator'

require 'json'
require 'yaml'
require 'objspace'

class RulesMigrator


   MAX_POST_DATA_SIZE_IN_MB_v1 = 1
   MAX_POST_DATA_SIZE_IN_MB_v2 = 5
   RULES_PER_REQUEST = 3000 			#Tune this if request payloads are too big.

   REQUEST_SLEEP_IN_SECONDS = 10 #Sleep this long after hitting request rate limit.

   attr_accessor :source,
				 :source_version,
				 :target,
				 :target_version,
				 :credentials,
				 :options, #hash of options such as :write_mode, :rules_folder
				 :do_rule_translation,
				 :report_only, #boolean

				 :rules_ok, #Rules that did not require any translation.
				 :rules_translated, #Rules that were translated.
				 :rules_invalid, #Valid 1.0 rules not passing new 2.0 syntax validators.
				 :rules_invalid_all,
				 :rules_deprecated, #1.0 Rules with deprecated Operators.
				 :rules_already_exist,
				 :rules_valid_but_blocked, #Any remaining 2.0 validation questions?

				 :rules_translator, #singleton instance of RuleTranslator class. 
				 :http #singleton instance of HTTP class.

   #Gotta supply account and settings files.
   def initialize(account_file, config_file)
	  @source = {:url => '', :rules_json => [], :num_rules => 0, :name => 'Source'}
	  @target = {:url => '', :rules_json => [], :num_rules_before => 0, :num_rules_after => 0, :name => 'Target'}
	  @credentials = {:user_name => '', :password => ''}
	  @options = {:verbose => true,
				  :write_mode => 'file',
				  :rules_folder => './rules',
				  :rules_json_to_post => nil,
				  :report_only => true
	  }

	  #Report metrics.
	  @rules_ok = [] #For same-version migrations, all should be OK.
	  @rules_translated = []
	  @rules_invalid = []
	  @rules_invalid_all = []
	  @rules_deprecated = []
	  @rules_already_exist = []
	  @rules_valid_but_blocked = []

	  set_credentials(account_file)
	  set_options(config_file)
	  set_http

	  @rules_translator = RuleTranslator.new
   end

   def set_http
	  @http = GnipRESTful.new
	  @http.user_name = @credentials[:user_name] #Set the info needed for authentication.
	  @http.password = @credentials[:password]
   end

   def set_credentials(account_file)
	  begin
		 credentials = YAML::load_file(account_file)
		 @credentials = credentials['account'].each_with_object({}) { |(k, v), memo| memo[k.to_sym] = v }
	  rescue
		 AppLogger.log_error "Error trying to load account settings. Could not parse account YAML file. Quitting."
		 @credentials = nil
	  end
   end

   def set_options(config_file)
	  begin
		 options = YAML::load_file(config_file)
	  rescue
		 AppLogger.log_error "Error loading/parsing  #{config_file['options']}. Expecting YAML. Check file details."
		 return nil
	  end

	  begin #Now parse contents and load separate attributes.

		 begin
			@source[:url] = options['source']['url'] #Load Source details.
		 rescue
			@source[:url] = nil
		 end
		 begin
			@target[:url] = options['target']['url']
		 rescue
			@target[:url] = nil
		 end
		 #Load Target details
		 @options[:write_mode] = options['options']['write_mode']
		 @options[:rules_folder] = options['options']['rules_folder']
		 @options[:rules_json_to_post] = options['options']['rules_json_to_post']
		 @options[:verbose] = options['options']['verbose']

		 #Create folder if they do not exist.
		 if (!File.exist?(@options[:rules_folder]))
			Dir.mkdir(@options[:rules_folder])
		 end

	  rescue
		 AppLogger.log_error "Error loading settings from #{file}. Check settings."
		 return nil
	  end
   end

   def check_systems(source_url, target_url)
	  #Self-discover what version/publisher of streams we are working with.

	  continue = true

	  if !source_url.nil?
		 if source_url.include? 'api.gnip.com'
			@source_version = 1
		 else
			@source_version = 2
		 end
	  else
		 @source_version = 1 #Note: if no source specified, we are assuming this is a '1.0 readiness report'.
	  end

	  if !target_url.nil?
		 if target_url.include? 'twitter.com'
			@target_version = 2
		 else
			@target_version = 1
		 end
	  else
		 @target_version = 2 #Note: if no target specified, we are assuming this is a '2.0 readiness report'.
	  end

	  if @source_version > @target_version
		 continue = false #No support for down versioning...
	  elsif @source_version == @target_version
		 @do_rule_translation = false

	  elsif @source_version < @target_version
		 @do_rule_translation = true
	  end

	  return continue

   end

   def split_request all_rules_request, size_limit

	  request_hash = JSON.parse(all_rules_request)

	  rules = request_hash['rules']

	  slice = RULES_PER_REQUEST
	  puts "Uploading #{slice} rules per request."

	  rule_request_sets = rules.each_slice(slice).to_a
	  
	  puts "Making #{ rule_request_sets.count} requests."

	  requests = []

	  rule_request_sets.each do |set|
		 #Make request
		 request = {}
		 request['rules'] = set
		 #AppLogger.log_debug "Request has size: #{'%.2f' % (request.to_json.bytesize.to_f/1048576.0)} MB"
		 requests << request.to_json
	  end

	  requests

   end

   def create_post_requests(rules)
	  #Rules were loaded either from a single Rules API GET request, or loaded from a file.
	  #The number of rules may be quite high (up to 250K), and the payload size big (150 MB and higher?).

	  if @target_version == 1
		 max_payload_size_in_mb = MAX_POST_DATA_SIZE_IN_MB_v1
	  else #version 2.0
		 max_payload_size_in_mb = MAX_POST_DATA_SIZE_IN_MB_v2
	  end

	  requests = [] #Make take an array of requests to add rules to Target system. 

	  request_data = {} #Start building hash for Rules API POST requests.
	  request_data['rules'] = []

	  rules.each do |rule|
		 request_data['rules'] << rule
	  end

	  #Create JSON for request.
	  request = request_data.to_json
	  AppLogger.log_debug "Request has size: #{'%.3f' % (request.bytesize/1048576)} MB"
	
	  #Check size
	  if request.bytesize < (max_payload_size_in_mb * 1048576)
		 requests << request
	  else
		 requests = split_request(request, max_payload_size_in_mb)
	  end

	  requests

   end

   def get_rules_from_api(system)

	  AppLogger.log_info "Getting rules from #{system[:name]} system. Making Request to Rules API..."
	  response = @http.GET(system[:url])
	  
	  if response.code != '200'
	  
		 if response.code == '401'
			AppLogger.log_error "Can not authenticate, please confirm your credential configuration in the 'account.yaml' file."
			puts 'Quitting.'
			abort
		 end

		 if response.code == '404'
			AppLogger.log_error "Source Rules URL not found. Please confirm your Source Rules API configuration."
			puts 'Quitting.'
			abort
		 end



		 AppLogger.log_error "An #{response.code} error occurred with message #{response.message}."
		 puts "Retrying after waiting #{REQUEST_SLEEP_IN_SECONDS} seconds. "
		 sleep REQUEST_SLEEP_IN_SECONDS
		 get_rules_from_api system

	  end

	  rules_payload = JSON.parse(response.body)
	  rules = rules_payload['rules']

	  AppLogger.log_info "    ... got #{rules.count} rules from #{system[:name]} system."
	  AppLogger.log_debug "\n ******************"

	  rules

   end

   def translate_rules(rules)
	  #All things PowerTrack 1.0 --> 2.0 Operators.

	  AppLogger.log_info "Checking #{rules.count} rules for translation..."

	  processed_rules = []

	  rules.each do |rule|

		 #Remove any rules with deprecated Operator.
		 if @rules_translator.rule_has_deprecated_operator? rule
			@rules_deprecated << rule
			#puts "Skipping deprecated rule"
			next
		 end

		 rule_translated = {}
		 rule_translated['tag'] = rule['tag']

		 rule_before = Marshal.load(Marshal.dump(rule))

		 rule_translated['value'] = @rules_translator.check_rule(rule['value'])

		 #puts rule_before['value'] + " ---->  " +  rule_translated['value']

		 if rule_before['value'] != rule_translated['value']
			@rules_translated << "'#{rule_before['value']}' ----> '#{rule_translated['value']}'"
		 else
			@rules_ok << "'#{rule_before['value']}'"
		 end

		 processed_rules << rule_translated
	  end

	  AppLogger.log_info "Translated #{@rules_translated.count} rules..."
	  AppLogger.log_info "#{@rules_deprecated.count} rules contain deprecated Operators..."

	  processed_rules
   end

   def make_rules_file(request)
	  #puts request

	  begin
		 num = 0

		 rules_written = false

		 filename_base = "#{@source[:name]}_rules"
		 filename = filename_base

		 until rules_written
			if not File.file?("#{@options[:rules_folder]}/#{filename}.json")
			   File.open("#{@options[:rules_folder]}/#{filename}.json", 'w') { |file| file.write(request) }
			   AppLogger.log_info "Created #{@options[:rules_folder]}/#{filename}.json file..."
			   rules_written = true
			else
			   num += 1
			   filename = filename_base + "_" + num.to_s
			end
		 end

	  rescue => error
		 puts
	  end

   end

   def make_rules_files(target)

	  return false if target[:name].downcase == 'source'

	  AppLogger.log_info "Writing rules to a JSON file."

	  #return nil if url includes? source
	  requests = create_post_requests(target[:rules_json])

	  requests.each do |request|
		 make_rules_file request
	  end

	  true
   end

   def drop_bad_rules_from_request(request, rules_invalid)

	  AppLogger.log_info "Dropping rules with syntax not supported in version 2.0."

	  rules_before = 0
	  rules_after = 0
	  
	  request_hash = JSON.parse(request)
	  rules = request_hash['rules']
	  rules_before = rules.count

	  rules.each do |rule|
		 if rules_invalid.include?(rule['value'])

			puts rule['value']

			rules.delete(rule)

		 end
	  end

	  rules_after = rules.count

	  #Double-check, did we drop all rules we wanted to?
	  #If not, input = input.gsub(/[^0-9A-Za-z]/, '')
	  #.gsub(/[^[:print:]]/,'.')

	  if rules_after + rules_invalid.count > rules_before

		 rules.each do |rule|
			
			rules_invalid.each do |rule_invalid|
			   
			   puts rule_invalid.gsub(/[^0-9A-Za-z]/, '')

			   if rule['value'].gsub(/[^0-9A-Za-z]/, '') == rule_invalid.gsub(/[^0-9A-Za-z]/, '')
				  rules.delete(rule)
			   end
			end
		 end

		 rules_invalid.each do |rule_invalid|

			rules.each do |rule|

			   if rule['value'].gsub(/[^0-9A-Za-z]/, '') == rule_invalid.gsub(/[^0-9A-Za-z]/, '')
				  rules.delete(rule)
			   end
			end
		 end

	  end

	  #Reassemble request
	  request = {}
	  request['rules'] = rules
	  request.to_json
   end

   def make_request url, request

	  begin
		 response = @http.POST(url, request, {"content-type" => "application/json", "accept" => "application/json"})
		 
		 #puts "Response: #{response.code} | #{response.message}"

		 if response.code[0] == '4' and response.code != "422"
			AppLogger.log_error "Error occurred: code: #{response.code} | message: #{response.message}"
		 end

	  rescue => error
		 puts "Error with POST request: #{error.message}"
	  end

	  return response #object

   end

   def manage_validation_request url, request

	  response = make_request url, request
	  response_hash = JSON.parse(response.body) unless response.body == ''

	  if (response.code == '200' or response.code == '201') or (response.code == '400' and response.message == 'OK') #Then all rules are syntactically OK, although maybe not all were created (already exists?).
		 AppLogger.log_info "Successful request of validation endpoint."

		 if response_hash['summary']['not_valid'] > 0 #Validation endpoint metadata.
			AppLogger.log_debug "#{response_hash['summary']['not_valid']} rules were NOT valid."

			response_hash['detail'].each do |detail|
			   if detail['valid'] == false
				  AppLogger.log_debug "Rule '#{detail['rule']['value']}' is not valid because: #{detail['message']}"
				  @rules_invalid << detail['rule']['value']
			   end
			end
		 end
		 return 'ok'
	  end
   end

   def validate_rules target
   #This method manages calls to the the Rules API validation endpoint...

	  #return nil if url includes? source
	  requests = create_post_requests(target[:rules_json])

	  requests.each do |request|
     	 result = manage_validation_request target[:url], request
 	  end

	  true

   end

   def manage_initial_request url, request


	  @rules_invalid = []
	  
	  response = make_request url, request
	  response_hash = JSON.parse(response.body) unless response.body == ''
	  
	  if @target_version == 1 and response.message == 'Created'
		 return 'ok'
	  end
	  

	  if  @target_version == 2 and ((response.code == '200' or response.code == '201') or (response.code == '401' and response.message == 'Created')) #Then all rules are syntactically OK, although maybe not all were created (already exists?).
		 AppLogger.log_info "Successful rule post to target system."

		 #Although we have a 201, it is possible some were not created since they already exist.
		 AppLogger.log_info "#{response_hash['summary']['created']} rules were created."

		 if response_hash['summary']['not_created'] > 0
			AppLogger.log_debug "#{response_hash['summary']['not_created']} rules were NOT created."

			response_hash['detail'].each do |detail|
			   if detail['created'] == false
				  AppLogger.log_debug "Rule '#{detail['rule']['value']}' was not created because: #{detail['message']}"

				  if detail['message'].include?("rule with this value already exists")
					 @rules_already_exist << detail['rule']['value']
				  else
					 puts "Did not understand reason rule was not created: #{detail['message']} "
				  end
			   end
			end
		 end


		 return 'ok'

	  elsif (response.code == '422' or response.code == '401') and not response_hash['summary'].nil? #Rules API rejected at least one rule, do drop rules.

		 AppLogger.log_info "No rules were created. Here are the offending rules:"

		 response_hash['detail'].each do |detail|

			if detail['created'] == false and not detail['message'].nil?
			   AppLogger.log_info "Rule '#{detail['rule']['value']}' was not created because: #{detail['message']}"
			   @rules_invalid << detail['rule']['value']
			   @rules_invalid_all << detail['rule']['value']
			end
		 end

		 return 'cleanup'

	  elsif response.code[0] == '5' #retry on server-side 5## error code.
		 AppLogger.log_error "Error occurred: code: #{response.code} | message: #{response.message}"
		 sleep REQUEST_SLEEP_IN_SECONDS
		 return 'retry'

	  else #Let's quit for other errors... Authentication errors and the like.
		 return 'quit'
	  end


   end

   def manage_cleanup_request url, request
   #After dropping bad rules, we retry once.
	  
	  if @rules_invalid.count > 0
		 request = drop_bad_rules_from_request(request, @rules_invalid)
		 AppLogger.log_info "Retrying after removing #{@rules_invalid.count} bad 2.0 s@rules_invalidyntax rules...."
		 response = @http.POST(url, request)
		 if response.code == '200' or response.code == '201'
			AppLogger.log_info "Retry with dropped rules succeeded."
			response_hash = JSON.parse(response.body)

			if response_hash['summary']['not_created'] > 0
			   AppLogger.log_debug "#{response_hash['summary']['not_created']} rules were NOT created."

			   response_hash['detail'].each do |detail|
				  if detail['created'] == false
					 AppLogger.log_debug "Rule '#{detail['rule']['value']}' was not created because: #{detail['message']}"

					 if detail['message'].include?("rule with this value already exists")
						@rules_already_exist << detail['rule']['value']
					 end
				  end
			   end

			   return 'ok'
			end
		 else
			AppLogger.log_error "Retry with dropped rules failed. "
			return 'quit'
		 end
	  end
   end

   def migrate_rules target
   #This method manages the Rules API requests...
	  
	  #return nil if url includes? source
	  requests = create_post_requests(target[:rules_json])

	  requests.each do |request|

		 result = manage_initial_request target[:url], request

		 if result == 'cleanup'
			result = manage_cleanup_request target[:url], request
		 end

		 if result == 'quit'
			return false
		 end
	  end

	  true

   end

   def GET_rules system, before = true

	  system[:rules_json] = get_rules_from_api(system)

	  if system[:rules_json].nil?
		 AppLogger.log_error "Problem checking #{system[:name]} rules."
	  else
		 if before
			system[:num_rules_before] = system[:rules_json].count
		 else
			system[:num_rules_after] = system[:rules_json].count
		 end
	  end

	  system[:rules_json]

   end

   def load_rules_from_file rules_file #By definition, this loading is only for a Source system.

	  rules = File.read("#{@options[:rules_folder]}/#{rules_file}")
	  rules_hash = JSON.parse(rules)
	  rules = rules_hash['rules']

	  if rules.nil?
		 AppLogger.log_error "Problem loading Source rules from file #{@options[:rules_folder]}/#{rules_file}."
	  else
		 @source[:num_rules_before] = rules.count
	  end

	  rules
   end

   def write_summary
	  #Number of rules for source and target (before and after).

	  if @report_only
		 puts ''
		 puts "Running in 'report' mode, no changes will be made."
		 puts ''
	  end

	  puts '---------------------'
	  puts "Rule Migrator summary"

	  puts ''
	  puts '---------------------'
	  puts 'Source system:'
	  puts "	Source[:url] = #{@source[:url]}"
	  puts "	Source system has #{@source[:num_rules_before]} rules."
	  puts "	Source system has #{@rules_ok.count - @rules_invalid_all.count} rules ready for version 2."
	  puts "	Source system has #{@rules_translated.count} rules that were translated to version 2."
	  puts "	Source system has #{@rules_deprecated.count} rules that contain deprecated Operators with no equivalent in version 2.0."
	  puts "    Source system has #{@rules_invalid_all.count} rules with version 1.0 syntax not supported in version 2.0."

	  puts "    Target system already has #{@rules_already_exist.count} rules from Source system." unless @report_only

	  puts ''

	  if not @report_only and @options[:write_mode] != 'file'
		 puts 'Target system:'
		 puts "   	Target[:url] = #{@target[:url]}"
		 puts "   	Target system had #{@target[:num_rules_before]} rules before, and #{@target[:num_rules_after]} rules after."
		 puts "    Number of rules translated: #{@rules_translated.count}"
	  end
	  puts ''
	  #Note any rules that needed to be 'translated'.
	  if @rules_translated.count > 0
		 puts '---------------------'
		 puts "#{@rules_translated.count} Source rules were translated:"
		 @rules_translated.each do |rule|
			puts "   #{rule}"
		 end
	  end

	  puts ''
	  #Rules that could not be added to version 2.0

	  if @rules_invalid_all.count > 0
		 puts '---------------------'
		 puts "#{@rules_invalid_all.count} Source rules that have version 1.0 syntax not supported in version 2.0:"
		 @rules_invalid_all.each do |rule|
			puts "   #{rule}"
		 end
	  end
	  puts ''

	  puts ''
	  #Rules that already existed.
	  puts '---------------------'
	  if @rules_deprecated.count > 0

		 puts "#{@rules_deprecated.count} Source rules contain deprecated Operators with no equivalent in version 2.0:."
		 @rules_deprecated.each do |rule|
			puts "   #{rule['value']}"
		 end
	  end
	  puts ''

	  puts ''
	  #Rules that already existed.

	  if not @report_only and @rules_already_exist.count > 0
		 puts '---------------------'
		 puts "#{@rules_already_exist.count} Source rules already exist in Target system:"
		 @rules_already_exist.each do |rule|
			puts "   #{rule}"
		 end
	  end
	  puts ''
   end

end