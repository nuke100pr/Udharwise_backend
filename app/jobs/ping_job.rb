class PingJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "PING_JOB_RAN_OK"
  end
end