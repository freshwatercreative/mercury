require 'rails/generators/active_record'
module Mercury
  module Generators
    module Install
      class AssetsGenerator < Rails::Generators::Base
        include Rails::Generators::Migration
        source_root File.expand_path("../templates", __FILE__)

        desc "Installs assets processing migrations and model."

        class_option :orm, :default => 'active_record', :banner => 'mongoid',
                     :desc => 'ORM for required models -- active_record, or mongoid'

        def copy_models
          if options[:orm] == 'mongoid'
            copy_file 'mongoid_paperclip_asset.rb', 'app/models/mercury/asset.rb'
          else
            copy_file 'ar_paperclip_asset.rb', 'app/models/mercury/asset.rb'
            migration_template 'ar_paperclip_asset_migration.rb', 'db/migrate/create_mercury_assets.rb'
          end
        end

        def copy_controller
          copy_file 'assets_controller.rb', 'app/controllers/mercury/assets_controller.rb'
        end

        def add_routes
          route %Q{  namespace :mercury do
      resources :assets
    end}
        end

        def add_gemfile_dependencies
          append_to_file "Gemfile", %Q{gem 'paperclip'}
          if options[:orm] == 'mongoid'
            append_to_file "Gemfile", %Q{gem 'mongoid-paperclip', :require => 'mongoid_paperclip'}
          end
        end

        # Implement the required interface for Rails::Generators::Migration.
        def self.next_migration_number(dirname) #:nodoc:
          ActiveRecord::Generators::Base.next_migration_number(dirname)
        end
      end
    end
  end
end

