# frozen_string_literal: true

# Polls until a WhatsApp outbound message has a Meta wamid (source_id) or failed,
# replacing the previous fixed sleep(2) used by campaign jobs.
class Whatsapp::CampaignDeliveryWait
  DEFAULT_TIMEOUT_SECONDS = 45
  DEFAULT_POLL_SECONDS = 0.5

  Result = Struct.new(:status, keyword_init: true) do
    def failed?
      status == :failed
    end

    def timeout?
      status == :timeout
    end

    def sent?
      status == :sent
    end
  end

  def initialize(message, timeout_seconds: nil, poll_seconds: nil, sleeper: Kernel)
    @message = message
    @timeout_seconds = (timeout_seconds || ENV.fetch('CAMPAIGN_SEND_CONFIRM_TIMEOUT_SECONDS', DEFAULT_TIMEOUT_SECONDS)).to_f
    @poll_seconds = (poll_seconds || ENV.fetch('CAMPAIGN_SEND_CONFIRM_POLL_SECONDS', DEFAULT_POLL_SECONDS)).to_f
    @sleeper = sleeper
  end

  def call
    deadline = monotonic_now + @timeout_seconds

    loop do
      @message.reload
      return Result.new(status: :failed) if @message.failed?
      return Result.new(status: :sent) if @message.source_id.present?
      break if monotonic_now >= deadline

      @sleeper.sleep(@poll_seconds)
    end

    @message.reload
    return Result.new(status: :failed) if @message.failed?
    return Result.new(status: :sent) if @message.source_id.present?

    Result.new(status: :timeout)
  end

  private

  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
