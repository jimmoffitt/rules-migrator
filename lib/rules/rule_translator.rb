# Developed for translating PowerTrack 1.0 rules to version 2.0.

class RuleTranslator
   
	OPERATORS_DEPRECATED = ['klout_topics:', 'klout_topic_contains:', 'bio_lang:', 'has:profile_geo_region', 'has:profile_geo_subregion', 'has:profile_geo_locality']

   def rule_has_deprecated_operator? rule
	  deprecated_operators = ['klout_topics:', 
							  'klout_topic_contains:', 
							  'bio_lang:', 
							  'has:profile_geo_region', 
							  'has:profile_geo_subregion', 
							  'has:profile_geo_locality']
	  
	  if deprecated_operators.any? { |operator| rule['value'].include?(operator) }
		 return true
	  end

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
		 if code == "un"
			code = "und"
		 end
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

	  AppLogger.log_debug "Rule #{rule} has #{language_codes.uniq.count} unique language codes: #{language_codes.uniq.to_s}"

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

	  #AppLogger.log_info "Rule (before): #{rule}"

	  if rule_has_pattern?(rule, pattern)
		 AppLogger.log_debug "Has #{pattern}"

		 if only_one_language?(rule)
			code = get_language_codes_unique rule
			rule.gsub! pattern, "lang:#{code[0]}"
		 else
			rule.gsub! 'twitter_lang:', 'lang:'
		 end
	  end

	  #AppLogger.log_info "Rule (after): #{rule}"
	  #AppLogger.log_info '----------------------'

	  rule

   end

   def handle_common_duplicate_patterns rule, language

	  #lang:xx OR lang:und OR lang:xx
	  rule.gsub! "lang:#{language} OR lang:und OR lang:#{language}", "lang:#{language} OR lang:und"

	  rule.gsub! "lang:#{language} OR lang:#{language}", "lang:#{language}"

	  rule.gsub! "lang:#{language} lang:#{language}", "lang:#{language}"

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

   def eliminate_duplicate_languages rule

	  languages = collect_languages rule

	  languages.each do |language|

		 if rule.scan("lang:#{language}").count > 1

			AppLogger.log_debug "Have double #{language}"

			rule = handle_common_duplicate_patterns rule, language
		 end
	  end

	  rule
   end

   def handle_has_lang(rule)
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

	  #No language clauses?
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
	  #AppLogger.log_debug "Language rule (before): #{rule}"

	  rule = handle_common_lang_patterns rule

	  #First, snap to lang:.
	  rule.gsub!('twitter_lang:', 'lang:')

	  if duplicate_languages?(rule)
		 rule = eliminate_duplicate_languages rule
	  end

	  #AppLogger.log_debug "Language rule (after): #{rule}"

	  rule

   end
  
   def handle_contains_operators(rule)
	  #Drops the '_contains' from these Operators:
	  # 'place_contains:', 'bio_location_contains', 'bio_contains', 'bio_name_contains', 'profile_region_contains',
	  # 'profile_locality_contains', 'profile_subregion_contains'

	  rule.gsub!('place_contains:', 'place:')
	  rule.gsub!('bio_location_contains:', 'bio_location:')
	  rule.gsub!('bio_contains:', 'bio:')
	  rule.gsub!('bio_name_contains:', 'bio_name:')
	  rule.gsub!('profile_region_contains:', 'profile_region:')
	  rule.gsub!('profile_locality_contains:', 'profile_locality:')
	  rule.gsub!('profile_subregion_contains:', 'profile_subregion:')

	  rule
   end

   def handle_country_code_operators(rule)
	  #Order here matters: check profile_country_code first, then check country_code.
	  rule.gsub!('profile_country_code:', 'profile_country:')

	  rule.gsub!('country_code:', 'place_country:')

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


	  if rule.include? 'country_code:'
		 rule = handle_country_code_operators rule
	  end

	  rule

   end
	  
end
   
