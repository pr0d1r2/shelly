require "yaml"
require "shelly/user"
require "shelly/cloudfile"

module Shelly
  module CLI
    class User < Thor
      namespace :user
      include Helpers

      desc "list", "List users who have access to clouds defined in Cloudfile"
      def list
        say_error "Must be run inside your project git repository" unless App.inside_git_repository?
        say_error "No Cloudfile found" unless Cloudfile.present?
        @cloudfile = check_clouds.first
        @cloudfile.fetch_users.each do |cloud, users|
          say "Cloud #{cloud}:"
          users.each { |user| say "  #{user}" }
        end
      rescue Client::APIError => e
        if e.unauthorized?
          e.errors.each { |error| say_error error, :with_exit => false}
          exit 1
        else
          say_error e.message
        end
      end

      desc "add [EMAIL]", "Add new developer to clouds defined in Cloudfile"
      def add(email = nil)
        say_error "Must be run inside your project git repository" unless App.inside_git_repository?
        say_error "No Cloudfile found" unless Cloudfile.present?
        @cloudfile, @user = check_clouds
        user_email = email || ask_for_email({:guess_email => false})
        @cloudfile.clouds.each do |cloud|
          @user.send_invitation(cloud, user_email)
          say "Sending invitation to #{user_email} to work on #{cloud}", :green
        end
      rescue Client::APIError => e
        if e.validation?
          e.each_error { |error| say_error error =~ /already in the project/ ? error.gsub("Email", "User") : error, :with_exit => false }
          exit 1
        elsif e.unauthorized?
          e.errors.each { |error| say_error error, :with_exit => false}
          exit 1
        end
      end

      no_tasks do
        def check_clouds
          @cloudfile = Shelly::Cloudfile.new
          @user = Shelly::User.new
          user_apps = @user.apps.map { |cloud| cloud['code_name'] }
          unless @cloudfile.clouds.all? { |cloud| user_apps.include?(cloud) }
            errors = (@cloudfile.clouds - user_apps).map { |cloud| "You have no access to '#{cloud}' cloud defined in Cloudfile" }
            raise Shelly::Client::APIError.new({:message => "Unauthorized",
              :errors => errors}.to_json)
          end
          [@cloudfile, @user]
        end

      end
    end
  end
end