require 'optparse'

require_relative './lib/common/app_logger'
require_relative './lib/rules_migrator'

def parseOptions(o)

   cmd_line_params = {}

   #Passing in a config file.... Or you can set a bunch of parameters.
   cmd_line_params['account'] = nil
   o.on('-a ACCOUNT', '--account', 'Account configuration file (including path) that provides OAuth settings.') { |account| cmd_line_params['account']= account }
   cmd_line_params['options'] = nil
   o.on('-c CONFIG', '--config', 'Settings configuration file (including path) that provides API settings.') { |config| cmd_line_params['options'] = config }

   cmd_line_params['source'] = nil
   o.on('-s SOURCE', '--source', "Rules API URL for GETting 'Source' rules.") { |source| cmd_line_params['source'] = source }
   cmd_line_params['target'] = nil
   o.on('-t TARGET', '--target', "Rules API URL for POSTing rules to 'Target' system.") { |target| cmd_line_params['target'] = target }

   cmd_line_params['report'] = nil
   o.on('-r', '--report', "Just generate rule migration report, do not make any updates.'") { |report| cmd_line_params['report'] = report }
   cmd_line_params['directory'] = nil
   o.on('-d DIRECTORY', '--directory', "Specify directory/folder for storing rule set JSON files. Default is './rules'.") { |directory| cmd_line_params['directory'] = directory }

   cmd_line_params['write_mode'] = nil
   o.on('-w WRITE', '--write', "Write rules to either JSON file or POST to Target Rules API. Choices: \"file\" or \"api\".") { |write| cmd_line_params['write_mode'] = write }

   cmd_line_params['file'] = nil
   o.on('-f FILE', '--file', "Specify a file to load into 'Target' system.") { |file| cmd_line_params['file'] = file }

   cmd_line_params['verbose'] = nil
   o.on('-v', '--verbose', 'When verbose, output all kinds of things, each request, most responses, etc.') { |verbose| $verbose = verbose }
   o.on('-h', '--help', 'Display this screen.') do
	  puts o #Help screen.
	  exit
   end
   o.parse!

   cmd_line_params

end

def set_defaults cmd_line_params
   #No defaults for Source, Target, File.

   #If not passed in, use some defaults.
   cmd_line_params['account'] = './config/account.yaml' if cmd_line_params['account'].nil?
   cmd_line_params['options'] = './config/options.yaml' if cmd_line_params['options'].nil?
   cmd_line_params['verbose'] = true if cmd_line_params['verbose'].nil?
   cmd_line_params['write_mode'] = 'file' if cmd_line_params['write_mode'].nil?
   cmd_line_params['directory'] = "./rules" if cmd_line_params['directory'].nil?

   cmd_line_params
end

if __FILE__ == $0 #This script code is executed when running this file.

   cmd_line_params = {}

   OptionParser.new do |o|
	  cmd_line_params = parseOptions o
   end

   cmd_line_params = set_defaults cmd_line_params

   #Let's do some bootstrapping and get a Logger set-up.
   AppLogger.set_logger(cmd_line_params['config'], cmd_line_params['verbose'])
   AppLogger.log_info("Starting process at #{Time.now}")

   #Create a singleton instance of the RuleMigrator class. 
   Migrator = RulesMigrator.new cmd_line_params['account'], cmd_line_params['options']
      
   #Override with any command-line parameters.
   Migrator.source[:url] = cmd_line_params['source'] if !cmd_line_params['source'].nil?
   Migrator.target[:url] = cmd_line_params['target'] if !cmd_line_params['target'].nil?
   Migrator.report_only = cmd_line_params['report'] if !cmd_line_params['report'].nil?
   Migrator.options[:write_mode] = cmd_line_params['write_mode'] if !cmd_line_params['write_mode'].nil?
   Migrator.options[:rules_folder] = cmd_line_params['directory'] if !cmd_line_params['directory'].nil?
   Migrator.options[:rules_json_to_post] = cmd_line_params['file'] if !cmd_line_params['file'].nil?
   Migrator.options[:verbose] = cmd_line_params['verbose'] if !cmd_line_params['verbose'].nil?
   
   #If both :rules_json_to_post and :write_mode == file are specified, default to writing JSON.
   if not (Migrator.options[:rules_json_to_post].to_s == '') and Migrator.options[:write_mode] == 'file'
	  Migrator.options[:rules_json_to_post] == nil
	  AppLogger.log_info "Config says to both POST file to Rules API and write Source rules to file. Only writing JSON file."
	  AppLogger.log_info "Unset 'write_mode' (-w command-line option) if you want to POST file to Rules API."
   end

   #Affect the Logger w.r.t. user options. 
   AppLogger.verbose = Migrator.options[:verbose]
   AppLogger.info_chatter = true #Even if verbose is false, let's treat info log messages in a verbose way...

   #---------------------------------------------------------------------------------------------------------------------

   #Only fail here is downgrading (target_version >= source_target). Migrating 2.0 rules to 1.0 is not supported. 
   continue = Migrator.check_systems(Migrator.source[:url], Migrator.target[:url])

   if not continue
	  AppLogger.log_error "Can not migrate PowerTrack 2.0 rules to PowerTrack 1.0 stream."
	  abort
   end

   #*******************
   #Load Source rules...  Always, either a URL or inbox file(s).
   if cmd_line_params['file'].nil? #Retrieving rules from Source Rules API.
	  Migrator.source[:rules_json] = Migrator.GET_rules(Migrator.source) if continue
   else #Loading from file.
	  Migrator.source[:rules_json] = Migrator.load_rules_from_file(cmd_line_params['file']) if continue
   end

   Migrator.source[:num_rules] = Migrator.source[:rules_json].count

   continue = false if Migrator.source[:rules_json].nil?

   if not continue
	  AppLogger.log_error "Could not load SOURCE rules. Quitting."
	  abort
   end

   #*******************
   #Try and get Target rules, for stats and configuration confirmation.
   if not Migrator.report_only
	  #Load Target rules.
	  Migrator.target[:rules_json] = Migrator.GET_rules(Migrator.target, true)
	  Migrator.target[:num_rules_after] = Migrator.target[:rules_json].count
	  continue = false if Migrator.target[:rules_json].nil?

	  if not continue
		 AppLogger.log_error "Error accessing TARGET Rules API. Quitting."
		 abort
	  end
   end

   #*******************
   #Do translation if going 'up-version' (PT 1.0 --> 2.0).
   if Migrator.do_rule_translation
	  Migrator.target[:rules_json] = Migrator.translate_rules(Migrator.source[:rules_json])
   else
	  Migrator.target[:rules_json] = Migrator.source[:rules_json]
	  #TODO: mark all as OK? Seems it should be handled by summary writer.
   end

   continue = false if Migrator.target[:rules_json].nil?

   if not continue
	  AppLogger.log_error "No rules for TARGET system. Quitting. "
	  abort
   end

   #*******************
   
   if not Migrator.report_only #translated rules ready to post

   	  continue = Migrator.post_rules(Migrator.target)
   
	  if continue #If migration successful, recheck Target rules. 	 
		 Migrator.target[:rules_json] = Migrator.GET_rules(Migrator.target, false)
		 AppLogger.log_error "ERROR re-checking target rules." if Migrator.target[:rules_json].nil?
		 Migrator.target[:num_rules_after] = Migrator.target[:rules_json].count
	  else
		 AppLogger.log_error "POSTing rules to TARGET system. Quitting"
		 abort
	  end
   else
	  continue = Migrator.post_rules_to_validator(Migrator.target)
   end

   Migrator.write_summary

   #------------------------------------------------------------------
   AppLogger.log_info("Finished at #{Time.now}")

end
   