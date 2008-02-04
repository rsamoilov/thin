require File.dirname(__FILE__) + '/spec_helper'

describe Runner do
  it "should parse options" do
    runner = Runner.new(%w(start --pid test.pid --port 5000))
    
    runner.options[:pid].should == 'test.pid'
    runner.options[:port].should == 5000
  end
  
  it "should parse specified command" do
    Runner.new(%w(start)).command.should == 'start'
    Runner.new(%w(stop)).command.should == 'stop'
    Runner.new(%w(restart)).command.should == 'restart'
  end

  it "should abort on unknow command" do
    runner = Runner.new(%w(poop))
    
    runner.should_receive(:abort)
    runner.run!
  end
  
  it "should exit on empty command" do
    runner = Runner.new([])
    
    runner.should_receive(:exit).with(1)
    
    silence_stream(STDOUT) do
      runner.run!
    end
  end
  
  it "should use Controller when controlling a single server" do
    runner = Runner.new(%w(start))
    
    controller = mock('controller')
    controller.should_receive(:start)
    Controller.should_receive(:new).and_return(controller)
    
    runner.run!
  end

  it "should use Cluster controller when controlling multiple servers" do
    runner = Runner.new(%w(start --servers 3))
    
    controller = mock('cluster')
    controller.should_receive(:start)
    Cluster.should_receive(:new).and_return(controller)
    
    runner.run!
  end
  
  it "should default to single server controller" do
    Runner.new(%w(start)).should_not be_a_cluster
  end
  
  it "should consider as a cluster with :servers option" do
    Runner.new(%w(start --servers 3)).should be_a_cluster
  end
  
  it "should consider as a cluster with :only option" do
    Runner.new(%w(start --only 3000)).should be_a_cluster
  end  
end

describe Runner, 'with config file' do
  before do
    @runner = Runner.new(%w(start --config spec/configs/cluster.yml))
  end
  
  it "should load options from file with :config option" do
    @runner.send :load_options_from_config_file!
    
    @runner.options[:environment].should == 'production'
    @runner.options[:chdir].should == 'spec/rails_app'
    @runner.options[:port].should == 5000
    @runner.options[:servers].should == 3
  end
  
  it "should change directory after loading config" do
    @orig_dir = Dir.pwd
    
    controller = mock('controller')
    controller.should_receive(:respond_to?).with('start').and_return(true)
    controller.should_receive(:start)
    Cluster.should_receive(:new).and_return(controller)
    expected_dir = File.expand_path('spec/rails_app')
    
    begin
      silence_stream(STDERR) do
        @runner.run!
      end
  
      Dir.pwd.should == expected_dir
    
    ensure
      # any other spec using relative paths should work as expected
      Dir.chdir(@orig_dir)
    end
  end
end

describe Runner, "service" do
  before do
    Thin.stub!(:linux?).and_return(true)
    
    @controller = mock('service')
    Service.stub!(:new).and_return(@controller)
  end
  
  it "should use Service controller when controlling all servers" do
    runner = Runner.new(%w(start --all))
    
    @controller.should_receive(:start)
    
    runner.run!
  end
  
  it "should call install with arguments" do
    runner = Runner.new(%w(install /etc/cool))
    
    @controller.should_receive(:install).with('/etc/cool')
    
    runner.run!
  end

  it "should call install without arguments" do
    runner = Runner.new(%w(install))
    
    @controller.should_receive(:install).with()
    
    runner.run!
  end  
end