class ApplicationJob < ActiveJob::Base
  # https://api.rubyonrails.org/v5.2.1/classes/ActiveJob/Exceptions/ClassMethods.html
  discard_on ActiveJob::DeserializationError do |job, error|
    Rails.logger.warn(
      "Discarded #{job.class} (#{error.message}) args=#{
        job.instance_variable_get(:@serialized_arguments)
      }"
    )
  end
end
