require_relative './common/app_logger'
require_relative './common/restful'
require_relative './rules/rule_translator'

require 'json'
require 'yaml'
require 'objspace'

class RulesMigrator


   MAX_POST_DATA_SIZE_IN_MB_v1 = 1
   MAX_POST_DATA_SIZE_IN_MB_v2 = 5

   REQUEST_SLEEP_IN_SECONDS = 10 #Sleep this long with hitting request rate limit.

   attr_accessor :source,
				 :source_version,
				 :target,
				 :target_version,
				 :do_rule_translation,
				 :rules_translated,
				 :rules_already_existing,
				 :rules_invalid,           #Valid 1.0 rules not passing new 2.0 syntax validators.
				 :credentials,
				 :options,
				 :rules_translator,
				 :http

   #Gotta supply account and settings files.
   def initialize(accounts, settings, verbose = nil)
	  @source = {:url => '', :rules => [], :num_rules => 0, :name => 'Source'}
	  @target = {:url => '', :rules => [], :num_rules_before => 0, :num_rules_after => 0, :name => 'Target'}
	  @credentials = {:user_name => '', :password => ''}
	  @options = {:verbose => true, :write_rules_to => 'api', :rules_folder => './rules', :load_files => false}
	  @rules_translated = []
	  @rules_invalid = []
	  @rules_already_existing = []

	  set_credentials(accounts)
	  set_options(settings)
	  set_http
	  
	  @rules_translator = RuleTranslator.new
   end

   def set_http
	  @http = GnipRESTful.new
	  @http.user_name = @credentials[:user_name] #Set the info needed for authentication.
	  @http.password = @credentials[:password]
   end

   def set_credentials(file)
	  begin
		 credentials = YAML::load_file(file)
		 @credentials = credentials['account'].each_with_object({}) { |(k, v), memo| memo[k.to_sym] = v }
	  rescue
		 AppLogger.log_error "Error trying to load account settings. Could not parse account YAML file. Quitting."
		 @credentials = nil
	  end
   end

   def set_options(file)
	  begin
		 options = YAML::load_file(file)
	  rescue
		 AppLogger.log_error "Error loading/parsing  #{file}. Expecting YAML. Check file details."
		 return nil
	  end

	  begin #Now parse contents and load separate attributes.
		 @source[:url] = options['source']['url'] #Load Source details.
		 @target[:url] = options['target']['url'] #Load Target details

		 @options[:write_rules_to] = options['options']['write_rules_to']
		 @options[:rules_folder] = options['options']['rules_folder']
		 @options[:load_files] = options['options']['load_files']
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

   #Self-discover what version/publisher of streams we are working with.
   def check_systems(source_url, target_url)

	  continue = true

	  if source_url.include? 'api.gnip.com'
		 @source_version = 1
	  else
		 @source_version = 2
	  end

	  if target_url.include? 'twitter.com'
		 @target_version = 2
	  else
		 @target_version = 1
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

   #Rules were loaded either from a single Rules API GET request, or loaded from a file.
   #The number of rules may be quite high (up to 250K), and the payload size big (150 MB and higher?).
   def create_post_requests(rules)

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
	  
	  #Check size
	  if request.bytesize < (max_payload_size_in_mb * 1000000)
		 requests << request
		 AppLogger.log_debug "Request has size: #{request.bytesize/1000} KB"
	  else
		 requests = split_request(request)
	  end
	  
	  requests
	 
=begin
		 
		 
	 request_data['rules'] << rule


		#request = request_data.to_json
	 
	    #puts "Size of 'request': #{request.bytesize}"
	    puts "Size of 'request_data': #{ObjectSpace.memsize_of(request_data['rules'])}"
	 
		if request.bytesize > (max_payload_size_in_mb * 1000000)

			#Save request, start over
			requests << request
			AppLogger.log_debug "Request has size: #{request.bytesize/1000} KB"
			request_data['rules'] = [] #Initialize and re-add current rule.
			request_data['rules'] << rule
		end
		 
		 
	  end

	  if request_data['rules'].count > 0

		 #TODO: handle JSON files for manual loading.
		 request = request_data.to_json

		 AppLogger.log_debug "Request has size: #{request.bytesize/1000} KB"
		 requests << request
	  end



	  requests
=end

   end

   def get_rules(system)

	  AppLogger.log_info "Getting rules from #{system[:name]} system..."
	  response = @http.GET(system[:url])

	  #TODO: handle response codes

	  rules = JSON.parse(response.body)

	  AppLogger.log_info "    ... got #{rules['rules'].count} rules from #{system[:name]} system."
	  AppLogger.log_debug "\n ******************"

	  rules['rules']
   end

   #All things PowerTrack 1.0 --> 2.0 Operators. 
   def translate_rules(rules)

	  AppLogger.log_info "Translating #{rules.count} rules..."

	  translated_rules = []

	  rules.each do |rule|

		 rule_translated = {}
		 rule_translated['tag'] = rule['tag']
		 
		 rule_before = Marshal.load(Marshal.dump(rule))

		 #rule_translated['value'] = RuleTranslator.check_rule(rule['value'])
         rule_translated['value'] = @rules_translator.check_rule(rule['value'])

		 
		 if rule_before['value'] != rule_translated['value']
			@rules_translated << "'#{rule_before['value']}' ----> '#{rule_translated['value']}'"
		 end

		 translated_rules << rule_translated
	  end

	  translated_rules
   end

   def make_rules_file(request)
	  puts request

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


   end
   
   
   def drop_bad_rules_from_request(request, rules_invalid)
	  
	  request_hash = JSON.parse(request)
	  rules = request_hash['rules']
	  
	  rules.each do |rule|
		 if rules_invalid.include?(rule['value'])
			rules.delete(rule)
		 end
	  end

	  #Reassemble request
	  request = {} 
	  request['rules'] = rules
	  request.to_json
   end

   def post_rules(target)

	  return false if target[:name].downcase == 'source'

	  AppLogger.log_info "Posting rules to #{target[:name]} system."

	  #return nil if url includes? source
	  requests = create_post_requests(target[:rules])

	  requests.each do |request|

		 if @options[:write_rules_to] == 'files' and not @options['write_to_file'].nil?

			make_rules_file request

		 else # writing to 'api', so POST the requests.

			begin
			   response = @http.POST(target[:url], request)
			   #response_json = response.body.to_json
			   response_hash = JSON.parse(response.body)

			   AppLogger.log_debug "response code: #{response.code} | message: #{response.message} "

			   if response.code == '200' or response.code == '201'
				  AppLogger.log_info "Successful rule post to target system."

				  #Although we have a 201, it is possible some were not created since they already exist.
				  AppLogger.log_info "#{response_hash['summary']['created']} rules were created."

				  if response_hash['summary']['not_created'] > 0
					 AppLogger.log_info "#{response_hash['summary']['not_created']} rules were NOT created."

					 response_hash['detail'].each do |detail|
						if detail['created'] == false
						   AppLogger.log_debug "Rule '#{detail['rule']['value']}' was not created because: #{detail['message']}"
						end
					 end
				  end

				  #"{"summary":{"created":8,"not_created":5},"detail":[{"rule":{"value":"(lang:en OR lang:en OR lang:und) Gnip","tag":null,"id":710911249710653441},"created":true},{"rule":{"value":"(place:minneapolis OR bio:minnesota) (snow OR rain)","tag":null,"id":710911249735811073},"created":true},{"rule":{"value":"-lang:und (snow OR rain)","tag":null,"id":710911249735753728},"created":true},{"rule":{"value":"(lang:en) place_country_code:us bio:Twitter","tag":null,"id":710911249706409985},"created":true},{"rule":{"value":"(lang:en OR lang:und OR lang:en) Gnip","tag":null,"id":710911249735749632},"created":true},{"rule":{"value":"(lang:en) Gnip","tag":null,"id":710911249702191104},"created":true},{"rule":{"value":"lang:en Gnip","tag":null,"id":710911249735757825},"created":true},{"rule":{"value":"(lang:es OR lang:en) Gnip","tag":null,"id":710911249706422273},"created":true},{"rule":{"value":"(lang:en) Gnip","tag":null},"created":false,"message":"A rule with this value already exists"},{"rule":{"value":"(lang:en) Gnip","tag":null},"created":false,"message":"A rule with this value already exists"},{"rule":{"value":"lang:en Gnip","tag":null},"created":false,"message":"A rule with this value already exists"},{"rule":{"value":"(lang:es OR lang:en) Gnip","tag":null},"created":false,"message":"A rule with this value already exists"},{"rule":{"value":"(lang:en) Gnip","tag":null},"created":false,"message":"A rule with this value already exists"}]}"

			   else #TODO: handle errors. 
				  
				  if response_hash['summary'].nil? #This is something the non-Rules API/syntax error. 
					 AppLogger.log_error "Error occurred: code: #{response.code} | message: #{response.message}"
				  else #Request was processed, but probably at least one rule was invalid w.r.t. to PT 2.0.
					 
					 #Idea here is to drop the bad rules, and retry, logging the bad rules....
					 
					 AppLogger.log_info "No rules were created. Here are the offending rules:"
					 
					 response_hash['detail'].each do |detail|
						if detail['created'] == false and not detail['message'].nil?
						   AppLogger.log_info "Rule '#{detail['rule']['value']}' was not created because: #{detail['message']}"
						   
						   #if detail['message'] about new 2.0 syntax validator.
						   invalid_msg = "#{detail['rule']['value']} | #{detail['message']}"
						   @rules_invalid << detail['rule']['value']
						   
						elsif detail['created'] == false and detail['message'].nil?
						   AppLogger.log_debug "Rule '#{detail['rule']['value']}' was not created because it already exists."

						   @rules_already_existing << detail['rule']['value']

						end
					 end

					 if @rules_invalid.count > 0
						request = drop_bad_rules_from_request(request, @rules_invalid)

						response = @http.POST(target[:url], request)
						if response.code == '200' or response.code == '201'
						   AppLogger.log_info "Retry after removing bad 2.0 syntax rules succeeded."
						else
						   AppLogger.log_error "Retry failed... "
						end
					 end
				  end
			   end
			rescue
			   sleep 5
			   response = @http.POST(target[:url], request) #try again
			end
		 end
	  end

	  true
   end


   def load_rules system, before = true

	  system[:rules] = get_rules(system)

	  if system[:rules].nil?
		 AppLogger.log_error "Problem checking #{system[:name]} rules."
	  else
		 if before
			system[:num_rules_before] = system[:rules].count
		 else
			system[:num_rules_after] = system[:rules].count
		 end
	  end

	  system[:rules]

   end

   def load_rules_from_file rules_file #By definition, this loading is only for a Source system.
	  rules = File.read(rules_file)
	  rules_hash = JSON.parse(rules)
	  rules = rules_hash['rules']

	  if rules.nil?
		 AppLogger.log_error "Problem loading Source rules from file."
	  else
		@source[:num_rules_before] = rules.count
	  end

	  rules
   end
   

   def write_summary
	  #Number of rules for source and target (before and after).
	  puts '---------------------'
	  puts "Rule Migrator summary"
	  
	  
	  puts ''
	  puts '---------------------'
	  puts 'Source system:'
	  puts "	Source[:url] = #{@source[:url]}"
	  puts "	Source system has #{@source[:num_rules_before]} rules."
	  puts "    Number of rules with version 1.0 syntax not supported in version 2.0: #{@rules_invalid.count}"
	  puts ''
	  puts 'Target system:'
	  puts "   	Target[:url] = #{@target[:url]}"
	  puts "   	Target system had #{@target[:num_rules_before]} rules before, and #{@target[:num_rules_after]} rules after."
	  puts "    Number of rules translated: #{@rules_translated.count}"
	  
	  puts ''
	  #Note any rules that needed to be 'translated'.
	  puts '---------------------'
	  if @rules_translated.count > 0
		 
		 puts "#{rules_translated.count} Source rules were translated:"
		 @rules_translated.each do |rule|
			puts "   #{rule}"
		 end
	  end
	  
	  puts ''
	  #Rules that could not be added to version 2.0
	  puts '---------------------'
	  if @rules_invalid.count > 0

		 puts "#{rules_invalid.count} Source rules that have version 1.0 syntax not supported in version 2.0:"
		 @rules_invalid.each do |rule|
			puts "   #{rule}"
		 end
	  end
	  puts ''

	  puts ''
	  #Rules that already existed.
	  puts '---------------------'
	  if @rules_already_existing.count > 0

		 puts "#{@rules_already_existing.count} Source rules already exist in Target system."
		 @rules_already_existing.each do |rule|
			puts "   #{rule}"
		 end
	  end
	  puts ''
	  
	  
   end

end