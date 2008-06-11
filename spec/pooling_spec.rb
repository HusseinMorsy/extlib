require File.expand_path(File.join(File.dirname(__FILE__), 'spec_helper'))
require 'timeout'

describe "Extlib::Pooling" do
  before(:all) do
    
    module Extlib::Pooling
      def self.scavenger_interval
        0.1
      end
    end
    
    class Person
      include Extlib::Pooling
      
      attr_accessor :name
      
      def initialize(name)
        @name = name
      end
      
      def dispose
        @name = nil
      end
      
      def self.scavenge_interval
        0.2
      end
    end
    
    class Overwriter      
      
      def self.new(*args)
        instance = allocate
        instance.send(:initialize, *args)
        instance.overwritten = true
        instance
      end
      
      include Extlib::Pooling
      
      attr_accessor :name
      
      def initialize(name)
        @name = name
        @overwritten = false
      end
      
      def overwritten?
        @overwritten
      end
      
      def overwritten=(value)
        @overwritten = value
      end
      
    end
  end
  
  it "should track the initialized pools" do
    bob = Person.new('Bob') # Ensure the pool is "primed"
    bob.instance_variable_get(:@__pool).should_not be_nil
    Person.__pools.size.should == 1
    bob.release
    Person.__pools.size.should == 1
    
    Extlib::Pooling::pools.should_not be_empty
    sleep(1)
    Extlib::Pooling::pools.should be_empty
  end
  
  it "should maintain a size of 1" do
    bob = Person.new('Bob')
    fred = Person.new('Fred')
    ted = Person.new('Ted')
    
    Person.__pools.each do |args, pool|
      pool.size.should == 1
    end
    
    bob.release
    fred.release
    ted.release
    
    Person.__pools.each do |args, pool|
      pool.size.should == 1
    end
  end
  
  it "should allow you to overwrite Class#new" do
    Overwriter.new('Bob').should be_overwritten
  end
  
  it "should raise a ThreadStopError when the pool is exhausted in a single thread" do
    lambda do
      begin
        bob = Person.new('Bob')
        Person.new('Bob')      
      ensure
        bob.release
      end      
    end.should raise_error(Extlib::Pooling::ThreadStopError)
  end
  
  it "should allow multiple threads to access the pool" do
    t1 = Thread.new do
      bob = Person.new('Bob')
      sleep(0.1)
      bob.release
    end
    
    lambda do
      bob = Person.new('Bob')
      t1.join
      bob.release
    end.should_not raise_error(Extlib::Pooling::ThreadStopError)
  end
end

# describe Extlib::Pooling::ResourcePool do
#   before :each do
#     @pool = Extlib::Pooling::ResourcePool.new(7, DisposableResource, :expiration_period => 50)
#   end
# 
#   it "responds to flush!" do
#     @pool.should respond_to(:flush!)
#   end
# 
#   it "responds to aquire" do
#     @pool.should respond_to(:aquire)
#   end
# 
#   it "responds to release" do
#     @pool.should respond_to(:release)
#   end
# 
#   it "responds to :available?" do
#     @pool.should respond_to(:available?)
#   end
# 
#   it "has a size limit" do
#     @pool.size_limit.should == 7
#   end
# 
#   it "has initial size of zero" do
#     @pool.size.should == 0
#   end
# 
#   it "has a set of reserved resources" do
#     @pool.instance_variable_get("@reserved").should be_empty
#   end
# 
#   it "has a set of available resources" do
#     @pool.instance_variable_get("@available").should be_empty
#   end
# 
#   it "knows class of resources (objects) it works with" do
#     @pool.class_of_resources.should == DisposableResource
#   end
# 
#   it "raises exception when given anything but class for resources class" do
#     lambda {
#       @pool = Extlib::Pooling::ResourcePool.new(7, "Hooray!", {})
#     }.should raise_error(ArgumentError, /class/)
#   end
# 
#   it "requires class of resources (objects) it works with to have a dispose instance method" do
#     lambda {
#       @pool = Extlib::Pooling::ResourcePool.new(3, UndisposableResource, {})
#     }.should raise_error(ArgumentError, /dispose/)
#   end
# 
#   it "may take initialization arguments" do
#     @pool = Extlib::Pooling::ResourcePool.new(7, DisposableResource, { :initialization_args => ["paper"] })
#     @pool.instance_variable_get("@initialization_args").should == ["paper"]
#   end
# 
#   it "may take expiration period option" do
#     @pool = Extlib::Pooling::ResourcePool.new(7, DisposableResource, { :expiration_period => 100 })
#     @pool.expiration_period.should == 100
#   end
# 
#   it "has default expiration period of one minute" do
#     @pool = Extlib::Pooling::ResourcePool.new(7, DisposableResource, {})
#     @pool.expiration_period.should == 60
#   end
# 
#   it "spawns a thread to dispose objects haven't been used for a while" do
#     @pool = Extlib::Pooling::ResourcePool.new(7, DisposableResource, {})
#     @pool.instance_variable_get("@pool_expiration_thread").should be_an_instance_of(Thread)
#   end
# end
# 
# 
# 
# describe "Aquire from contant size pool" do
#   before :each do
#     DisposableResource.initialize_pool(2)
#   end
# 
#   after :each do
#     DisposableResource.instance_variable_set("@__pool", nil)
#   end
# 
#   it "increased size of the pool" do
#     @time = DisposableResource.pool.aquire
#     DisposableResource.pool.size.should == 1
#   end
# 
#   it "places initialized instance in the reserved set" do
#     @time = DisposableResource.pool.aquire
#     DisposableResource.pool.instance_variable_get("@reserved").size.should == 1
#   end
# 
#   it "raises an exception when pool size limit is hit" do
#     @t1 = DisposableResource.pool.aquire
#     @t2 = DisposableResource.pool.aquire
# 
#     lambda { DisposableResource.pool.aquire }.should raise_error(RuntimeError)
#   end
# 
#   it "returns last released resource" do
#     @t1 = DisposableResource.pool.aquire
#     @t2 = DisposableResource.pool.aquire
#     DisposableResource.pool.release(@t1)
# 
#     DisposableResource.pool.aquire.should == @t1
#   end
# 
#   it "really truly returns last released resource" do
#     @t1 = DisposableResource.pool.aquire
#     DisposableResource.pool.release(@t1)
# 
#     @t2 = DisposableResource.pool.aquire
#     DisposableResource.pool.release(@t2)
# 
#     @t3 = DisposableResource.pool.aquire
#     DisposableResource.pool.release(@t3)
# 
#     DisposableResource.pool.aquire.should == @t1
#     @t1.should == @t3
#   end
# 
#   it "sets allocation timestamp on resource instance" do
#     @t1 = DisposableResource.new
#     @t1.instance_variable_get("@__pool_aquire_timestamp").should be_close(Time.now, 2)
#   end
# end
# 
# 
# 
# describe "Releasing from contant size pool" do
#   before :each do
#     DisposableResource.initialize_pool(2)
#   end
# 
#   after :each do
#     DisposableResource.instance_variable_set("@__pool", nil)
#   end
# 
#   it "decreases size of the pool" do
#     @t1 = DisposableResource.pool.aquire
#     @t2 = DisposableResource.pool.aquire
#     DisposableResource.pool.release(@t1)
# 
#     DisposableResource.pool.size.should == 1
#   end
# 
#   it "raises an exception on attempt to releases object not in pool" do
#     @t1 = DisposableResource.new
#     @t2 = Set.new
# 
#     DisposableResource.pool.release(@t1)
#     lambda { DisposableResource.pool.release(@t2) }.should raise_error(RuntimeError)
#   end
# 
#   it "removes released object from reserved set" do
#     @t1 = DisposableResource.pool.aquire
# 
#     lambda {
#       DisposableResource.pool.release(@t1)
#     }.should change(DisposableResource.pool.instance_variable_get("@reserved"), :size).by(-1)
#   end
# 
#   it "returns released object back to available set" do
#     @t1 = DisposableResource.pool.aquire
# 
#     lambda {
#       DisposableResource.pool.release(@t1)
#     }.should change(DisposableResource.pool.instance_variable_get("@available"), :size).by(1)
#   end
# 
#   it "updates aquire timestamp on already allocated resource instance" do
#     # aquire it once
#     @t1 = DisposableResource.new
#     # wait a bit
#     sleep 3
# 
#     # check old timestamp
#     @t1.instance_variable_get("@__pool_aquire_timestamp").should be_close(Time.now, 4)
# 
#     # re-aquire
#     DisposableResource.pool.release(@t1)
#     @t1 = DisposableResource.new
#     # see timestamp is updated
#     @t1.instance_variable_get("@__pool_aquire_timestamp").should be_close(Time.now, 2)
#   end
# end
# 
# 
# 
# describe Extlib::Pooling::ResourcePool, "#available?" do
#   before :each do
#     DisposableResource.initialize_pool(2)
#     DisposableResource.new
#   end
# 
#   after :each do
#     DisposableResource.instance_variable_set("@__pool", nil)
#   end
# 
#   it "returns true when pool has available instances" do
#     DisposableResource.pool.should be_available
#   end
# 
#   it "returns false when pool is exhausted" do
#     # aquires the last available resource
#     DisposableResource.new
#     DisposableResource.pool.should_not be_available
#   end
# end
# 
# 
# 
# describe "Flushing of contant size pool" do
#   before :each do
#     DisposableResource.initialize_pool(2)
# 
#     @t1 = DisposableResource.new
#     @t2 = DisposableResource.new
# 
#     # sanity check
#     DisposableResource.pool.instance_variable_get("@reserved").should_not be_empty
#   end
# 
#   after :each do
#     DisposableResource.instance_variable_set("@__pool", nil)
#   end
# 
#   it "disposes all pooled objects" do
#     [@t1, @t2].each { |instance| instance.should_receive(:dispose) }
# 
#     DisposableResource.pool.flush!
#   end
# 
#   it "empties reserved set" do
#     DisposableResource.pool.flush!
# 
#     DisposableResource.pool.instance_variable_get("@reserved").should be_empty
#   end
# 
#   it "returns all instances to available set" do
#     DisposableResource.pool.flush!
# 
#     DisposableResource.pool.instance_variable_get("@available").size.should == 2
#   end
# end
# 
# 
# 
# describe "Poolable resource class" do
#   before :each do
#     DisposableResource.initialize_pool(3, :initialization_args => ["paper"])
#   end
# 
#   after :each do
#     DisposableResource.instance_variable_set("@__pool", nil)
#   end
# 
#   it "aquires new instances from pool" do
#     @instance_one = DisposableResource.new
# 
#     DisposableResource.pool.aquired?(@instance_one).should be(true)
#   end
# 
#   it "flushed existing pool on re-initialization" do
#     DisposableResource.pool.should_receive(:flush!)
#     DisposableResource.initialize_pool(5)
#   end
# 
#   it "replaces pool on re-initialization" do
#     DisposableResource.initialize_pool(5)
#     DisposableResource.pool.size_limit.should == 5
#   end
# 
#   it "passes initialization parameters to newly created resource instances" do
#     DisposableResource.new.name.should == "paper"
#   end
# end
# 
# 
# 
# describe "Pooled object", "on initialization" do
#   after :each do
#     DisposableResource.instance_variable_set("@__pool", nil)
#   end
# 
#   it "does not flush pool" do
#     # using pool here initializes the pool first
#     # so we use instance variable directly
#     DisposableResource.instance_variable_get("@__pool").should_not_receive(:flush!)
#     DisposableResource.initialize_pool(23)
#   end
# 
#   it "flushes pool first when re-initialized" do
#     DisposableResource.initialize_pool(5)
#     DisposableResource.pool.should_receive(:flush!)
#     DisposableResource.initialize_pool(23)
#   end
# end
# 
# 
# 
# describe Extlib::Pooling::ResourcePool, "#time_to_dispose?" do
#   before :each do
#     DisposableResource.initialize_pool(7, :expiration_period => 2)
#   end
# 
#   after :each do
#     DisposableResource.instance_variable_set("@__pool", nil)
#   end
# 
#   it "returns true when object's last aquisition time is greater than limit" do
#     @t1 = DisposableResource.new
#     DisposableResource.pool.time_to_release?(@t1).should be(false)
# 
#     sleep 3
#     DisposableResource.pool.time_to_release?(@t1).should be(true)
#   end
# end
# 
# 
# 
# describe Extlib::Pooling::ResourcePool, "#dispose_outdated" do
#   before :each do
#     DisposableResource.initialize_pool(7, :expiration_period => 2)
#   end
# 
#   after :each do
#     DisposableResource.instance_variable_set("@__pool", nil)
#   end
# 
#   it "releases and thus disposes outdated instances" do
#     @t1 = DisposableResource.new
#     DisposableResource.pool.should_receive(:time_to_release?).with(@t1).and_return(true)
#     DisposableResource.pool.should_receive(:release).with(@t1)
# 
#     DisposableResource.pool.dispose_outdated
#   end
# end
