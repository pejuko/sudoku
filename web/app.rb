# This file contains your application, it requires dependencies and necessary
# parts of the application.
#
# It will be required from either `config.ru` or `start.rb`

require 'rubygems'
require "bundler/setup"
require 'ramaze'

#Ramaze::Cache.options.session = Ramaze::Cache::MemCache.using(
#    :compression => true,
#    :servers => ['127.0.0.1:11211']#, 'localhost:11211', '::1:11211']
#)

# Make sure that Ramaze knows where you are
Ramaze.options.roots = [__DIR__]

Ramaze.setup_dependencies

# Initialize controllers and models
require __DIR__('model/init')
require __DIR__('controller/init')
