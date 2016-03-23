require_relative '../common/app/app_logger'
require_relative "../common/http/restful"

require 'json'
require 'yaml'

class RulesMigrator

   MAX_POST_DATA_SIZE_IN_MB_v1 = 1
   MAX_POST_DATA_SIZE_IN_MB_v2 = 5

   REQUEST_SLEEP_IN_SECONDS = 10 #Sleep this long with hitting request rate limit.

   attr_accessor :source,
				 :source_version,
				 :target,
				 :target_version,
				 :do_rule_translation,
				 :credentials,
				 :options,
				 :http

   #Gotta supply account and settings files.
   def initialize(accounts, settings, verbose = nil)
	  @source = {:url => '', :rules => [], :num_rules => 0, :name => 'Source'}
	  @target = {:url => '', :rules => [], :num_rules_before => 0, :num_rules_after => 0, :name => 'Target'}
	  @credentials = {:user_name => '', :password => ''}
	  @options = {:verbose => true, :write_rules_to => 'api', :inbox => './inbox'}

	  set_credentials(accounts)
	  set_options(settings)
	  set_http
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
		 @options[:inbox] = options['options']['inbox']
		 @options[:verbose] = options['options']['verbose']

	  rescue
		 AppLogger.log_error "Error loading settings from #{file}. Check settings."
		 return nil
	  end
   end


   #Self-discover what version/publisher of streams we are working with.
   #
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
		 continue = false
	  elsif @source_version == @target_version
		 @do_rule_translation = false

	  elsif @source_version < @target_version
		 @do_rule_translation = true
	  end

	  return continue

   end

   def rule_has_pattern? rule, pattern
	  match = pattern.match rule
	  true unless match.nil?
   end

   def collect_languages rule

	  substring = 'lang:'
	  indexes = rule.enum_for(:scan, substring).map { $~.offset(0)[0] }

	  codes = []

	  indexes.each do |index|
		 code = rule[(index + substring.length), 2]
		 codes << code
	  end

	  language_codes = []

	  codes.each do |code|
		 language_codes << code.downcase
	  end

	  language_codes

   end

   def get_language_codes_unique rule
	  language_codes = collect_languages rule
	  language_codes.uniq
   end

   def only_one_language? rule

	  codes = collect_languages rule

	  language_codes = []

	  codes.each do |code|
		 language_codes << code.downcase
	  end

	  puts "Rule #{rule} has #{language_codes.uniq.count} unique language codes: #{language_codes.uniq.to_s}"

	  if language_codes.uniq.count == 1
		 true
	  else
		 false
	  end

   end

   def duplicate_languages? rule

	  language_codes = collect_languages rule

	  if language_codes.count == language_codes.uniq.count
		 false
	  else
		 true
	  end

   end

   def handle_lang_pair rule, pattern

	  AppLogger.log_info "Rule (before): #{rule}"

	  if rule_has_pattern?(rule, pattern)
		 AppLogger.log_info "Has #{pattern}"

		 if only_one_language?(rule)
			code = get_language_codes_unique rule
			rule.gsub! pattern, "lang:#{code[0]}"
		 else
			rule.gsub! 'twitter_lang:', 'lang:'
		 end
	  end

	  AppLogger.log_info "Rule (after): #{rule}"
	  AppLogger.log_info '----------------------'

	  rule

   end

   def handle_common_lang_patterns rule

	  #lang:xx OR twitter_lang:xx
	  pattern = /lang:[a-zA-Z][a-zA-Z] OR twitter_lang:[a-zA-Z][a-zA-Z]/
	  rule = handle_lang_pair rule, pattern

	  #twitter_lang:xx OR lang:xx
	  pattern = /twitter_lang:[a-zA-Z][a-zA-Z] OR lang:[a-zA-Z][a-zA-Z]/
	  rule = handle_lang_pair rule, pattern

	  #lang:xx twitter_lang:xx
	  pattern = /lang:[a-zA-Z][a-zA-Z] twitter_lang:[a-zA-Z][a-zA-Z]/
	  rule = handle_lang_pair rule, pattern

	  #twitter_lang:xx lang:xx
	  pattern = /twitter_lang:[a-zA-Z][a-zA-Z] lang:[a-zA-Z][a-zA-Z]/
	  rule = handle_lang_pair rule, pattern

	  rule

   end

   def handle_has_lang(rule)
	  AppLogger.log_warn "Rule (#{rule}) has 'has:geo', replacing with 'lang:und' and negating usage."

	  rule.gsub!('-has:lang', 'lang:und')

	  rule.gsub!('has:lang', '-lang:und')

	  rule
   end

   def handle_lang_operators(rule)

	  #Any twitter_lang Operators?	  
	  twitter_lang_clauses = rule.scan('twitter_lang:').count

	  #Any Gnip lang: Operators?
	  gnip_lang_clauses = (rule.scan(/[ ()]lang:/).count)
	  gnip_lang_clauses += 1 if rule.start_with?('lang:')

	  #No language clauses, sweet.
	  if twitter_lang_clauses == 0 and gnip_lang_clauses == 0
		 return rule
	  end

	  #twitter_lang only?
	  if twitter_lang_clauses > 0 and gnip_lang_clauses == 0
		 return rule.gsub!('twitter_lang:', 'lang:')
	  end

	  #lang: only? Do nothing.
	  if twitter_lang_clauses == 0 and gnip_lang_clauses > 0
		 return rule
	  end

	  #OK, we have a mix of lang Operators
	  #Shortcut is to replace the twitter_lang: clauses with lang:.
	  #The longer answer is to eliminate twitter_langs in ORs and ANDs and clean up.
	  AppLogger.log_debug "Have mix of lang and twitter_lang Operators..."
	  AppLogger.log_debug "Language rule (before): #{rule}"

	  rule = handle_common_lang_patterns rule

	  #First, snap to lang:.
	  rule.gsub!('twitter_lang:', 'lang:')

	  #if duplicate_languages?(rule)
	  #		 rule = eliminate_duplicate_ORed_languages rule
	  #end

	  AppLogger.log_debug "Language rule (after): #{rule}"

	  rule

   end

   #Drops the '_contains' from these Operators: 
   # 'place_contains:', 'bio_location_contains', 'bio_contains', 'bio_name_contains', 'profile_region_contains', 
   # 'profile_locality_contains', 'profile_subregion_contains'
   def handle_contains_operators(rule)

	  rule.gsub!('place_contains:', 'place:')
	  rule.gsub!('bio_location_contains:', 'bio_location:')
	  rule.gsub!('bio_contains:', 'bio:')
	  rule.gsub!('bio_name_contains:', 'bio_name:')
	  rule.gsub!('profile_region_contains:', 'profile_region:')
	  rule.gsub!('profile_locality_contains:', 'profile_locality:')
	  rule.gsub!('profile_subregion_contains:', 'profile_subregion:')

	  rule

   end

   #Order here matters: check profile_country_code first, then check country_code.
   def handle_country_code_operators(rule)

	  if rule_has_pattern? rule, /profile_country_code:/
		 rule.gsub!('profile_country_code:', 'profile_country_code:')
		 #rule.gsub!('profile_country_code:','profile_country:') #TODO: Synch with PT 2.0 deploys.
	  end

	  if rule_has_pattern? rule, /[ ,()]country_code/
		 rule.gsub!('country_code:', 'place_country_code:')
		 #rule.gsub!('country_country_code:','place_country:') #TODO: Synch with PT 2.0 deploys.
	  end

	  rule

   end

   #Handle any rule translations.
   #Explicitly not handling Klout, bio_lang, and has:profile* Operators. These will be passed through and 
   #handled by the Rules API (and in the case of 2.0, identified as a rule NOT added).
   def check_rule(rule)


	  if rule.include? 'twitter_lang'
		 rule = handle_lang_operators rule
	  end

	  if rule.include? 'has:lang'
		 rule = handle_has_lang rule
	  end

	  if rule.include? '_contains:'
		 rule = handle_contains_operators rule
	  end

	  #TODO: Keep in synch with PT 2.0 deploys (2016-03-18).
	  if rule.include? 'country_code:'
		 rule = handle_country_code_operators rule
	  end

	  rule

   end

   def create_post_requests(rules)

	  requests = []

	  request_data = {}
	  request_data['rules'] = []

	  if @target_version == 1
		 max_payload_size_in_mb = MAX_POST_DATA_SIZE_IN_MB_v1
	  else
		 max_payload_size_in_mb = MAX_POST_DATA_SIZE_IN_MB_v2
	  end

	  rules.each do |rule|

		 request_data['rules'] << rule

		 request = request_data.to_json

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

		 rule_translated['value'] = check_rule(rule['value'])

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
		 if not File.file?("#{@inbox}/#{filename}.json")
			File.open("#{@inbox}/#{filename}.json", 'w') { |file| file.write(request) }
			rules_written = true
		 else
			num += 1
			filename = filename_base + "_" + num.to_s
		 end
	  end
   end


   def post_rules(target)

	  return false if target[:name].downcase == 'source'

	  AppLogger.log_info "Posting rules to #{target[:name]} system."

	  #return nil if url includes? source
	  requests = create_post_requests(target[:rules])

	  requests.each do |request|

		 if @options[:write_rules_to] == 'files'
			
			make_rules_file request

		 else # writing to 'api', so POST the requests.


			begin
			   response = @http.POST(target[:url], request)

			   AppLogger.log_debug "response code: #{response.code} | message: #{response.message} "

			   if response.code == 200
				  AppLogger.log_info "Successful rule post to target system."


				  #"{"summary":{"created":8,"not_created":5},"detail":[{"rule":{"value":"(lang:en OR lang:en OR lang:und) Gnip","tag":null,"id":710911249710653441},"created":true},{"rule":{"value":"(place:minneapolis OR bio:minnesota) (snow OR rain)","tag":null,"id":710911249735811073},"created":true},{"rule":{"value":"-lang:und (snow OR rain)","tag":null,"id":710911249735753728},"created":true},{"rule":{"value":"(lang:en) place_country_code:us bio:Twitter","tag":null,"id":710911249706409985},"created":true},{"rule":{"value":"(lang:en OR lang:und OR lang:en) Gnip","tag":null,"id":710911249735749632},"created":true},{"rule":{"value":"(lang:en) Gnip","tag":null,"id":710911249702191104},"created":true},{"rule":{"value":"lang:en Gnip","tag":null,"id":710911249735757825},"created":true},{"rule":{"value":"(lang:es OR lang:en) Gnip","tag":null,"id":710911249706422273},"created":true},{"rule":{"value":"(lang:en) Gnip","tag":null},"created":false,"message":"A rule with this value already exists"},{"rule":{"value":"(lang:en) Gnip","tag":null},"created":false,"message":"A rule with this value already exists"},{"rule":{"value":"lang:en Gnip","tag":null},"created":false,"message":"A rule with this value already exists"},{"rule":{"value":"(lang:es OR lang:en) Gnip","tag":null},"created":false,"message":"A rule with this value already exists"},{"rule":{"value":"(lang:en) Gnip","tag":null},"created":false,"message":"A rule with this value already exists"}]}"

			   else #TODO: handle errors. 

				  response_json = response.body.to_json

				  puts response_json

				  #"{"error":{"detail":[{"rule":{"value":"has:lang (snow OR rain)"},
				  #      "message":"The has:lang operator is not supported. Use lang:und to identify Tweets where a language classification was not assigned. (at position 1)\n"},
				  #
				  # {"rule":{"value":"(lang:en) place_country:us bio:Twitter"},
				  # "message":"Reference to invalid field 'place_country' (at position 11)\nReference to invalid field 'place_country',
				  # 		must be from the list: [] (at position 11)\n"},
				  #
				  # {"rule":{"value":"(place_country:us profile_country:us) (rain OR snow)"},
				  # "message":"Reference to invalid field 'profile_country' (at position 19)\nReference to invalid field 'place_country' (at position 2)\n
				  #       Reference to invalid field 'profile_country', must be from the list: [from, to, source, retweets_of, place, url_contains, klout_score, contains, lang, bounding_box, point_radius, user_profile_location, sample, place_contains, bio_location_contains, time_zone, followers_count, bio_location, friends_count, statuses_count, listed_count, profile_point_radius, profile_bounding_box, profile_country_code, profile_region, profile_locality, klout_topic, klout_topic_id, klout_topic_contains, twitter_lang, retweets_of_status_id, in_reply_to_status_id, profile_subregion, user_place_id, url, url_title, url_description, place_country_code, bio, bio_name, has:mentions, has:hashtags, has:geo, has:links, has:media, has:profile_geo, has:lang, has:symbols, has:images, has:videos, is:retweet, is:verified, is:quote] (at position 19)\nReference to invalid field 'place_country', must be from the list: [from, to, source, retweets_of, place, url_contains, klout_score, contains, lang, bounding_box, point_radius, user_profile_location, sample, place_contains, bio_location_contains, time_zone, followers_count, bio_location, friends_count, statuses_count, listed_count, profile_point_radius, profile_bounding_box, profile_country_code, profile_region, profile_locality, klout_topic, klout_topic_id, klout_topic_contains, twitter_lang, retweets_of_status_id, in_reply_to_status_id, profile_subregion, user_place_id, url, url_title, url_description, place_country_code, bio, bio_name, has:mentions, has:hashtags, has:geo, has:links, has:media, has:profile_geo, has:lang, has:symbols, has:images, has:videos, is:retweet, is:verified, is:quote] (at position 2)\n"}],
				  # "message":"The has:lang operator is not supported. Use lang:und to identify Tweets where a language classification was not assigned. (at position 1)\n",
				  # "sent":"2016-03-18T17:36:22.750Z"}}"
			   end


			rescue
			   sleep 5
			   response = @http.POST(target[:url], request) #try again
			end
		 end
	  end

	  true
   end


   def load_rules system

	  system[:rules] = get_rules(system)

	  if system[:rules].nil?
		 AppLogger.log_error "Problem checking #{system[:name]} rules."
	  else
		 system[:num_rules_before] = system[:rules].count
	  end

	  system[:rules]

   end


   def write_summary
	  #Number of rules for source and target (before and after).
	  puts "Rule Migrator summary"
	  puts "     Source[:url] = #{@source[:url]}"
	  puts "     Target[:url] = #{@target[:url]}"

	  puts '---------------------'

	  #Note any rules that needed to be 'translated'.

   end

end