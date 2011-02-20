require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development, :test)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'active_support/test_case'
require 'test/unit'
require 'shoulda'
Gem.activate 'activerecord', '~>2.3'
require 'active_record'
require 'sqlite3'

if RUBY_VERSION < '1.9'
  require 'memprof'
else
  class Memprof
    class << self
      def method_missing(*args)
        true
      end
    end
  end
end

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'select_and_update_all'

ActiveRecord::Base.logger = Logger.new File.new('test.log', 'w+'), Logger::INFO
ActiveRecord::Base.establish_connection YAML.load(File.open(File.join(File.dirname(__FILE__), 'database.yml')).read)[ENV['db'] || 'sqlite3']

ActiveRecord::Base.connection.create_table 'test_entries' do |t|
  t.string  :name
  t.integer :number
end
