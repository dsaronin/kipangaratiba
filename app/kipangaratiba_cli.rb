# Kipangaratiba: A Remote Elder Monitoring Hub
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#
# class KipangaratibaCLI -- 'controller' for CLI
#

  require_relative 'kipangaratiba_work'

# +++++++++++++++++++++++++++++++++++++++++++++++++
module Kipangaratiba # Define the top-level module
# +++++++++++++++++++++++++++++++++++++++++++++++++

class KipangaratibaCLI

    KIPANGARATIBA = KipangaratibaWork.new 

  #  ------------------------------------------------------------
  #  cli  -- #  CLI entry point  <==== kicks off command loop
  #  ------------------------------------------------------------
  def cli()
    KIPANGARATIBA.setup_work()    # initialization of everything
    Environ.put_message "\n\t#{ Environ.app_name }: Remote Elder Monitoring Hub.\n"

    do_work()      # do the work of kipangaratiba

    KIPANGARATIBA.shutdown_work()

    return 1
  end

  #  ------------------------------------------------------------
  #  do_work  -- handles primary kipangaratiba stuff
  #  CLI usage only
  #  ------------------------------------------------------------
  def do_work()
      # loop for command prompt & user input
    begin
      Environ.put_prompt("\n#{ Environ.app_name } > ")  
    end  while  parse_commands( Environ.get_input_list )
  end

  #  ------------------------------------------------------------
  #  parse_commands  -- command interface
  #  ------------------------------------------------------------
  def parse_commands( cmdlist )        
    loop = true                 # user input loop while true

        # parse command
    case ( cmdlist.first || ""  ).chomp

      when  "f", "flags"     then  KIPANGARATIBA.do_flags( cmdlist )     # print flags
      when  "h", "help"      then  KIPANGARATIBA.do_help      # print help
      when  "v", "version"   then  KIPANGARATIBA.do_version   # print version
      when  "o", "options"   then  KIPANGARATIBA.do_options   # print options

      when  "x", "exit"      then  loop = false  # exit program
      when  "q", "quit"      then  loop = false  # exit program

      when  ""               then  loop = true   # empty line; NOP

      else     
        Environ.log_warn( "unknown command" ) 

    end  # case

    return loop
    end

  #  ------------------------------------------------------------
  #  ------------------------------------------------------------
end  # class

end  # module Kipangaratiba
