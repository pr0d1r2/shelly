require "spec_helper"
require "shelly/app"

describe Shelly::App do
  before do
    @app = Shelly::App.new
    @app.purpose = "staging"
    @app.code_name = "foooo-staging"
  end

  describe ".guess_code_name" do
    before do
      FileUtils.mkdir_p("/projects/foo")
    end

    it "should return name of current working directory" do
      Dir.chdir("/projects/foo")
      Shelly::App.guess_code_name.should == "foo"
    end
  end

  describe "#add_git_remote" do
    it "should add git remote with proper name and git repository" do
      @app.should_receive(:system).with("git remote add staging git@git.shellycloud.com:foooo-staging.git")
      @app.add_git_remote
    end
  end


  describe "#generate_cloudfile" do
    it "should return generated cloudfile" do
      FakeFS.deactivate!
      @app.databases = %w(postgresql mongodb)
      puts @app.generate_cloudfile
    end
  end
end
