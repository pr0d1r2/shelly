require 'erb'
require 'launchy'
require 'shelly/backup'

module Shelly
  class App < Model
    DATABASE_KINDS = %w(postgresql mongodb redis)
    DATABASE_CHOICES = DATABASE_KINDS + %w(none)
    SERVER_SIZES = %w(small large)

    attr_accessor :code_name, :databases, :ruby_version, :environment,
      :git_url, :domains, :web_server_ip, :mail_server_ip, :size, :thin

    def initialize(code_name = nil)
      self.code_name = code_name
    end

    def databases=(dbs)
      @databases = dbs - ['none']
    end

    def add_git_remote
      system("git remote rm #{code_name} > /dev/null 2>&1")
      system("git remote add #{code_name} #{git_url}")
    end

    def git_remote_exist?
      IO.popen("git remote").read.include?(code_name)
    end

    def git_fetch_remote
      system("git fetch #{code_name} > /dev/null 2>&1")
    end

    def git_add_tracking_branch
      system("git checkout -b #{code_name} --track #{code_name}/master > /dev/null 2>&1")
    end

    def remove_git_remote
      system("git remote rm #{code_name} > /dev/null 2>&1")
    end

    def create
      attributes = {:code_name => code_name}
      response = shelly.create_app(attributes)
      self.git_url = response["git_url"]
      self.domains = response["domains"]
      self.ruby_version = response["ruby_version"]
      self.environment = response["environment"]
    end

    def create_cloudfile
      cloudfile = Cloudfile.new
      cloudfile.code_name = code_name
      cloudfile.ruby_version = ruby_version
      cloudfile.environment = environment
      cloudfile.domains = domains
      cloudfile.size = size
      cloudfile.databases = databases
      cloudfile.create
    end

    def delete
      shelly.delete_app(code_name)
    end

    def deploy_logs
      shelly.deploy_logs(code_name)
    end

    def deploy_log(log)
      shelly.deploy_log(code_name, log)
    end

    def application_logs(options = {})
      shelly.application_logs(code_name, options)
    end

    def database_backups
      shelly.database_backups(code_name).map do |attributes|
        Shelly::Backup.new(attributes.merge("code_name" => code_name))
      end
    end

    def database_backup(handler)
      attributes = shelly.database_backup(code_name, handler)
      Shelly::Backup.new(attributes.merge("code_name" => code_name))
    end

    def restore_backup(filename)
      shelly.restore_backup(code_name, filename)
    end

    def request_backup(kind)
      shelly.request_backup(code_name, kind)
    end

    def logs
      shelly.cloud_logs(code_name)
    end

    def start
      shelly.start_cloud(code_name)
    end

    def stop
      shelly.stop_cloud(code_name)
    end

    def redeploy
      shelly.redeploy(code_name)
    end

    def self.guess_code_name
      guessed = nil
      cloudfile = Cloudfile.new
      if cloudfile.present?
        clouds = cloudfile.clouds
        if clouds.grep(/staging/).present?
          guessed = "production"
          production_clouds = clouds.grep(/production/)
          production_clouds.sort.each do  |cloud|
            cloud =~ /production(\d*)/
            guessed = "production#{$1.to_i+1}"
          end
        end
      end
      "#{File.basename(Dir.pwd)}-#{guessed || 'staging'}".downcase.tr('_','-')
    end

    def collaborations
      @collaborations ||= Array(shelly.collaborations(code_name)).
        sort_by { |c| c["email"] }
    end

    def active_collaborations
      collaborations.select { |c| c["active"] }
    end

    def inactive_collaborations
      collaborations.select { |c| !c["active"] }
    end

    def configs
      @configs ||= shelly.app_configs(code_name)
    end

    def user_configs
      configs.find_all { |config| config["created_by_user"] }
    end

    def shelly_generated_configs
      configs.find_all { |config| config["created_by_user"] == false }
    end

    def config(path)
      shelly.app_config(code_name, path)
    end

    def create_config(path, content)
      shelly.app_create_config(code_name, path, content)
    end

    def update_config(path, content)
      shelly.app_update_config(code_name, path, content)
    end

    def delete_config(path)
      shelly.app_delete_config(code_name, path)
    end

    def rake(task)
      ssh_command("rake_runner \"#{task}\"")
    end

    def attributes
      @attributes ||= shelly.app(code_name)
    end

    def statistics
      @stats ||= shelly.statistics(code_name)
    end

    def web_server_ip
      attributes["web_server_ip"]
    end

    def mail_server_ip
      attributes["mail_server_ip"]
    end

    def git_info
      attributes["git_info"]
    end

    def state
      attributes["state"]
    end

    def self.inside_git_repository?
      system("git status > /dev/null 2>&1")
    end

    def to_s
      code_name
    end

    def edit_billing_url
      "#{shelly.shellyapp_url}/apps/#{code_name}/billing/edit"
    end

    def open
      Launchy.open("http://#{attributes["domain"]}")
    end

    def console
      ssh_command
    end

    def upload(source)
      rsync(source, "#{ssh['node_ip']}:/srv/glusterfs/disk")
    end

    def download(relative_source, destination)
      source = File.join("#{ssh['node_ip']}:/srv/glusterfs/disk", relative_source)
      rsync(source, destination)
    end

    private

    def ssh
      @ssh ||= shelly.node_and_port(code_name)
    end

    def ssh_command(command = "")
      exec "ssh #{ssh_options} #{ssh['node_ip']} #{command}"
    end

    def ssh_options
      "-o StrictHostKeyChecking=no -p #{ssh['port']} -l #{ssh['user']}"
    end

    def rsync(source, destination)
      exec "rsync -avz -e 'ssh #{ssh_options}' --progress #{source} #{destination}"
    end
  end
end
