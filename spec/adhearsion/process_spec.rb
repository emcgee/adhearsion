require 'spec_helper'

module Adhearsion
  describe Adhearsion::Process do
    before :all do
      Adhearsion.active_calls.clear!
    end

    before :each do
      Adhearsion::Process.reset
    end

    it 'should trigger :stop_requested events on #shutdown' do
      flexmock(Events).should_receive(:trigger_immediately).once.with(:stop_requested)
      Adhearsion::Process.booted
      Adhearsion::Process.shutdown
    end

    it '#stop_when_zero_calls should wait until the list of active calls reaches 0' do
      pending
      calls = ThreadSafeArray.new
      3.times do
        fake_call = Object.new
        flexmock(fake_call).should_receive(:hangup).once
        calls << fake_call
      end
      flexmock(Adhearsion).should_receive(:active_calls).and_return calls
      flexmock(Adhearsion::Process.instance).should_receive(:final_shutdown).once
      calls = []
      3.times do
        calls << Thread.new do
          sleep 1
          calls.pop
        end
      end
      Adhearsion::Process.stop_when_zero_calls
      calls.each { |thread| thread.join }
    end

    it 'should terminate the process immediately on #force_stop' do
      flexmock(::Process).should_receive(:exit).with(1).once.and_return true
      Adhearsion::Process.force_stop
    end

    describe "#final_shutdown" do
      it "should hang up active calls" do
        3.times do
          fake_call = flexmock Object.new, :id => rand
          flexmock(fake_call).should_receive(:hangup).once
          Adhearsion.active_calls << fake_call
        end

        Adhearsion::Process.final_shutdown

        Adhearsion.active_calls.clear!
      end

      it "should trigger shutdown handlers synchronously" do
        shutdown_value = []

        Events.shutdown { shutdown_value << :foo }
        Events.shutdown { shutdown_value << :bar }
        Events.shutdown { shutdown_value << :baz }

        Adhearsion::Process.final_shutdown

        shutdown_value.should == [:foo, :bar, :baz]
      end

      it "should stop the console" do
        flexmock(Console).should_receive(:stop).once
        Adhearsion::Process.final_shutdown
      end
    end
  end
end