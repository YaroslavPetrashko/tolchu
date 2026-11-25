# Examples tagged :concurrency run threads against real, separate database connections.
# Transactional tests pin one connection for every thread, so row locks would never make
# anyone wait; these examples commit for real and truncate afterwards instead.
RSpec.shared_context "real concurrency" do
  self.use_transactional_tests = false

  after { DatabaseCleaner.clean_with(:truncation) }

  # Runs the block on `count` threads that all start at the same instant.
  # Returns each thread's result and re-raises anything a thread raised.
  def in_parallel(count)
    ready = Concurrent::CountDownLatch.new(count)
    go = Concurrent::CountDownLatch.new(1)
    threads = Array.new(count) do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready.count_down
          go.wait
          yield index
        end
      end
    end
    ready.wait
    go.count_down
    threads.map(&:value)
  end
end

RSpec.configure { |config| config.include_context "real concurrency", :concurrency }
