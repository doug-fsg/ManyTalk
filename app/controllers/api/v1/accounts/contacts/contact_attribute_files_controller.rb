class Api::V1::Accounts::Contacts::ContactAttributeFilesController < Api::V1::Accounts::Contacts::BaseController
  before_action :validate_attribute_key

  def create
    service = ContactAttributeFileUploadService.new(
      account: Current.account,
      contact: @contact,
      attribute_key: params[:attribute_key]
    )

    if params[:files].present?
      # Multiple files upload
      result = service.upload_multiple(params[:files])
      render json: { files: result }, status: :created
    elsif params[:file].present?
      # Single file upload
      result = service.upload(params[:file])
      render json: result, status: :created
    else
      render json: { error: 'No file provided' }, status: :unprocessable_entity
    end
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    render json: { error: "Failed to upload file: #{e.message}" }, status: :internal_server_error
  end

  def destroy
    service = ContactAttributeFileUploadService.new(
      account: Current.account,
      contact: @contact,
      attribute_key: params[:attribute_key]
    )

    if service.delete(params[:blob_key])
      head :ok
    else
      render json: { error: 'File not found' }, status: :not_found
    end
  rescue StandardError => e
    render json: { error: 'Failed to delete file' }, status: :internal_server_error
  end

  private

  def validate_attribute_key
    return if params[:attribute_key].present?

    render json: { error: 'Attribute key is required' }, status: :unprocessable_entity
  end
end

