#!/usr/bin/env ruby
#
# Kipangaratiba: A Remote Elder Monitoring Hub
# Copyright (c) 2025 David S Anderson, All Rights Reserved
#
# main.rb -- starting point for linux CLI implementation
#
# make sure to run $ bundle install  the first time
# To Run:
# make this file executable: chmod +x main.rb
# $ ~/main.rb
#

  require_relative 'kipangaratiba_cli'

  exit Kipangaratiba::KipangaratibaCLI.new.cli   # <-- cli() is the entry point

