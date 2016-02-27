require 'json'
require 'yaml'

require_relative '../common/app_logger'
require_relative "../common/restful"

class RulesMigrator

   MAX_POST_DATA_SIZE_IN_MB = 1

   REQUEST_SLEEP_IN_SECONDS = 10 #Sleep this long with hitting request rate limit.

   attr_accessor :source,
				 :target,
				 :credentials,
				 :options,
				 :http

   #Gotta supply account and settings files.
   def initialize(accounts, settings, verbose = nil)
	  @source = {:url => '', :rules => [], :num_rules => 0}
	  @target = {:url => '', :rules => [], :num_rules_before => 0, :num_rules_after => 0}
	  @credentials = {:user_name => '', :password => ''}
	  @options = {:verbose => true}

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
		 @options[:verbose] = options['options']['verbose']
	  rescue
		 AppLogger.log_error "Error loading settings from #{file}. Check settings."
		 return nil
	  end
   end
   
   def check_systems(source, target)
	  continue = true
   end

   def create_post_requests(rules)

	  requests = []

	  request_data = {}
	  request_data['rules'] = []

	  rules.each do |rule|
		 request_data['rules'] << rule

		 request = request_data.to_json
		 
		 if request.bytesize > (MAX_POST_DATA_SIZE_IN_MB * 1000000)

			#Save request, start over
			requests << request
			AppLogger.log_debug "Request has size: #{request.bytesize/1000} KB"
			request_data['rules'] = []
			request_data['rules'] << rule
		 end
	  end

	  if request_data['rules'].count > 0
	  	request = request_data.to_json
		AppLogger.log_debug "Request has size: #{request.bytesize/1000} KB"
	  	requests << request
	  end
		
	  requests

   end

   def get_rules(system)
	  response = @http.GET(system[:url])

	  #TODO: handle response codes

	  rules = JSON.parse(response.body)
	  rules['rules']
   end

   def post_rules(source, target)

	  #return nil if url includes? source
	  requests = create_post_requests(source[:rules])
	  requests.each do |request|

		 begin
			response = @http.POST(target[:url], request)
		 rescue
			sleep 5
			response = @http.POST(target[:url], request) #try again
		 end
	  end

	  true
   end

   def write_summary
	  #Number of rules for source and target (before and after).
	  
	  #Note any rules that needed to be 'translated'.

   end

end