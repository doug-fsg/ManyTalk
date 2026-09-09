# Signed representation URLs can outlive the blob. Rails then tries to persist a
# variant_record against a missing blob_id and raises InvalidForeignKey (500).
# Treat that as a missing file.
Rails.application.config.to_prepare do
  next unless defined?(ActiveStorage::Representations::RedirectController)

  ActiveStorage::Representations::RedirectController.class_eval do
    rescue_from ActiveRecord::InvalidForeignKey, ActiveStorage::FileNotFoundError do
      head :not_found
    end
  end
end
