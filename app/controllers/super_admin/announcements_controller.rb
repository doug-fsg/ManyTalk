class SuperAdmin::AnnouncementsController < SuperAdmin::ApplicationController
  JSON_PATH = Rails.root.join('public', 'announcements', 'data.json')
  MEDIA_PATH = Rails.root.join('public', 'announcements', 'media')

  def index
    @announcements = read_json['announcements']
  end

  def new; end

  def create
    data = read_json
    
    # Upload media
    media_url = upload_media(params[:media]) if params[:media]

    # Add announcement
    data['announcements'] << {
      id: params[:id],
      title: {
        pt_BR: params[:title_pt],
        en: params[:title_en]
      },
      description: {
        pt_BR: params[:desc_pt],
        en: params[:desc_en]
      },
      media_url: media_url,
      target_roles: params[:roles] || [],
      published_at: Time.current.iso8601,
      active: params[:active] == '1'
    }

    write_json(data)

    redirect_to super_admin_announcements_path, notice: 'Anúncio criado com sucesso!'
  end

  def destroy
    data = read_json
    data['announcements'].reject! { |a| a['id'] == params[:id] }
    write_json(data)

    redirect_to super_admin_announcements_path, notice: 'Anúncio removido!'
  end

  private

  def read_json
    return { 'announcements' => [] } unless File.exist?(JSON_PATH)
    JSON.parse(File.read(JSON_PATH))
  end

  def write_json(data)
    FileUtils.mkdir_p(JSON_PATH.dirname)
    File.write(JSON_PATH, JSON.pretty_generate(data))
  end

  def upload_media(file)
    return nil unless file

    FileUtils.mkdir_p(MEDIA_PATH)
    filename = "#{SecureRandom.hex(8)}_#{file.original_filename}"
    filepath = MEDIA_PATH.join(filename)
    
    File.open(filepath, 'wb') { |f| f.write(file.read) }
    
    "/announcements/media/#{filename}"
  end
end
