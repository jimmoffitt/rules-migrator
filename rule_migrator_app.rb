require 'optparse'

require_relative './common/app_logger'
require_relative './lib/rules_migrator'

if __FILE__ == $0 #This script code is executed when running this file.

   OptionParser.new do |o|

	  #Passing in a config file.... Or you can set a bunch of parameters.
	  o.on('-a ACCOUNT', '--account', 'Account configuration file (including path) that provides OAuth settings.') { |account| $account = account }
	  o.on('-c CONFIG', '--config', 'Settings configuration file (including path) that provides API settings.') { |config| $config = config }
	  o.on('-s SOURCE', '--source', '') { |source| $source = source }
	  o.on('-t TARGET', '--target', '') { |target| $target = target }
	  o.on('-v', '--verbose', 'When verbose, output all kinds of things, each request, most responses, etc.') { |verbose| $verbose = verbose }
	  o.on('-h', '--help', 'Display this screen.') do
		 puts o #Help screen.
		 exit
	  end
	  o.parse!
   end

   #If not passed in, use some defaults.
   $account = "./config/account.yaml" if $account.nil?
   $settings = './config/options.yaml' if ($settings.nil?) 

   AppLogger.set_logger($settings, $verbose)
   AppLogger.log_info("Starting process at #{Time.now}")
   Migrator = RulesMigrator.new($account, $settings, $verbose)

   #Set application attributes from command-line. These override values in the configuration file.

   #---------------------------------------------------------------------------------------------------------------------

   
   continue = Migrator.check_systems(Migrator.source,Migrator.target)
   
   Migrator.target[:rules] = Migrator.get_rules(Migrator.target)
   if Migrator.target[:rules].nil?
	  AppLogger.log_error 'Problem checking target rules.'
   else
	  Migrator.target[:num_rules_before] = Migrator.target[:rules].count
   end
      
   Migrator.source[:rules] = Migrator.get_rules(Migrator.source)
   if Migrator.source[:rules].nil?
	  AppLogger.log_error 'Problem checking source rules.'
   else
	  Migrator.source[:num_rules] = Migrator.source[:rules].count
	  continue = Migrator.post_rules(Migrator.source, Migrator.target)
   end
  
   if continue
	  Migrator.target[:rules] = Migrator.get_rules(Migrator.target)
	  if Migrator.target[:rules].nil?
		 AppLogger.log_error 'Problem re-checking target rules.'
		 continue = false
	  else
		 Migrator.target[:num_rules_after] = Migrator.target[:rules].count
	  end
	end

	if continue
	  Migrator.write_summary
   else
	  AppLogger.log_error 'Did not post rules to Target.'
   end

   #------------------------------------------------------------------
   AppLogger.log_info("Finished at #{Time.now}")

end
   