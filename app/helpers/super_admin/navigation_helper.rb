module SuperAdmin::NavigationHelper
  def settings_open?
    params[:controller].in? %w[super_admin/settings super_admin/app_configs]
  end

  def settings_pages
    features = SuperAdmin::FeaturesHelper.available_features.select do |_feature, attrs|
      attrs['config_key'].present? && attrs['enabled']
    end

    general_feature = [['general', { 'config_key' => 'general', 'name' => 'General' }]]
    extra_pages = [
      ['internal', { 'config_key' => 'internal', 'name' => 'Internal (advanced)' }]
    ]

    general_feature + features.to_a + extra_pages
  end
end
