require 'optparse'

require_relative './common/app_logger'
require_relative './lib/rules_migrator'

def parseOptions(o)

   settings = {}

   settings['account'] = nil
   settings['config'] = nil
   settings['target'] = nil
   settings['source'] = nil
   settings['verbose'] = nil
   settings['write_rules_to'] = nil
   settings['load_files'] = nil

   #Passing in a config file.... Or you can set a bunch of parameters.
   o.on('-a ACCOUNT', '--account', 'Account configuration file (including path) that provides OAuth settings.') { |account| settings['account']= account }
   o.on('-c CONFIG', '--config', 'Settings configuration file (including path) that provides API settings.') { |config| settings['config'] = config }
   o.on('-s SOURCE', '--source', "Rules API URL for GETting 'Source' rules.") { |source| settings['source'] = source }
   o.on('-t TARGET', '--target', "Rules API URL for POSTing rules to 'Target' system.") { |target| settings['target'] = target }
   o.on('-w WRITE', '--write', "Write rules to either 'files' or Target Rules 'api'") { |write| settings['write_rules_to'] = write }
   o.on('-l', '--load', "If inbox has files, load them into 'Target' system") { |load| settings['load_files'] = load }

   o.on('-v', '--verbose', 'When verbose, output all kinds of things, each request, most responses, etc.') { |verbose| $verbose = verbose }
   o.on('-h', '--help', 'Display this screen.') do
	  puts o #Help screen.
	  exit
   end
   o.parse!

   settings

end

def set_defaults settings

   #If not passed in, use some defaults.
   settings['account'] = '../config/account.yaml' if settings['account'].nil?
   settings['config'] = '../config/options.yaml' if settings['config'].nil?
   settings['verbose'] = true if settings['verbose'].nil?
   settings['write_rules_to'] = 'files' if settings['write_rules_to'].nil?

   settings
end


if __FILE__ == $0 #This script code is executed when running this file.

   settings = {}

   OptionParser.new do |o|
	  settings = parseOptions o
   end

   settings = set_defaults settings

   AppLogger.set_logger(settings['config'], settings['verbose'])
   AppLogger.log_info("Starting process at #{Time.now}")
   Migrator = RulesMigrator.new(settings['account'], settings['config'], settings['verbose'])
   AppLogger.verbose = Migrator.options[:verbose]
   AppLogger.info_chatter = true #Even if verbose is false, let's treat info log messages in a verbose way...

   #Set application attributes from command-line. These override values in the configuration file.

   #---------------------------------------------------------------------------------------------------------------------

   #Only fail here is down grading (target_version >= source_target). 
   continue = Migrator.check_systems(Migrator.source[:url], Migrator.target[:url]) 

   if continue 

	  #Load Target rules.
	 Migrator.target[:rules] = Migrator.load_rules(Migrator.target)
	 continue = false if Migrator.target[:rules].nil?
	 
	 #Load Source rules.
	 Migrator.source[:rules] = Migrator.load_rules(Migrator.source) if continue
	 continue = false if Migrator.source[:rules].nil?
	 Migrator.source[:num_rules] = Migrator.source[:rules].count #TODO: Why set here?

     #Do translation if going 'up-version' (PT 1.0 --> 2.0).
	 if Migrator.do_rule_translation
	    Migrator.target[:rules] = Migrator.translate_rules(Migrator.source[:rules])
	 else
		Migrator.target[:rules] = Migrator.source[:rules]
	 end

     continue = false if Migrator.target[:rules].nil?
	 
	 #Migrate (Source) rules to Target system.
	 continue = Migrator.post_rules(Migrator.target)

     #If migration success, recheck Target rules. 	 
	  if continue
		 Migrator.target[:rules] = Migrator.load_rules(Migrator.target, false)
		 AppLogger.log_error "ERROR re-checking target rules." if Migrator.target[:rules].nil?
         Migrator.target[:num_rules_after] = Migrator.target[:rules].count
	  end

	  if continue
		 Migrator.write_summary 
	  else
		 AppLogger.log_error 'Did not post rules to Target.'
	  end
   else
	  AppLogger.log_error "Can not migrate PowerTrack 2.0 rules to PowerTrack 1.0 stream."
   end

   #------------------------------------------------------------------
   AppLogger.log_info("Finished at #{Time.now}")

end
   