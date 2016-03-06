$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

Bundler.require(:default, :development)

require './configuration'
require './test_database'

require 'percona_migrator'
require 'lhm'

db_config = Configuration.new

fd = ENV['VERBOSE'] ? STDOUT : '/dev/null'
ActiveRecord::Base.logger = Logger.new(fd)

ActiveRecord::Base.establish_connection(
  adapter: 'percona',
  host: 'localhost',
  username: db_config['username'],
  password: db_config['password'],
  database: 'percona_migrator_test'
)

MIGRATION_FIXTURES = File.expand_path('../fixtures/migrate/', __FILE__)

test_database = TestDatabase.new(db_config)

RSpec.configure do |config|
  config.order = 'random'

  config.before(:all) do
    test_database.create_schema_migrations_table

    @initial_migration_paths = ActiveRecord::Migrator.migrations_paths
    ActiveRecord::Migrator.migrations_paths = [MIGRATION_FIXTURES]
  end

  config.after(:all) do
    ActiveRecord::Migrator.migrations_paths = @initial_migration_paths
  end

  # Cleans up the database after each example ala Database Cleaner
  config.around(:each) do |example|
    if example.metadata[:integration]
      test_database.create_schema_migrations_table
      example.run
      test_database.create_schema_migrations_table
    elsif example.metadata[:index]
      test_database.create_test_database
      test_database.create_schema_migrations_table
      example.run
      test_database.create_test_database
    else
      example.run
    end
  end

  config.order = :random

  Kernel.srand config.seed
end
