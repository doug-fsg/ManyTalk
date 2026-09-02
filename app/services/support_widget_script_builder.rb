class SupportWidgetScriptBuilder
  def self.build(website_token: nil)
    token = website_token.presence || GlobalConfig.get_value('CHATWOOT_INBOX_TOKEN')
    return if token.blank?

    base_url = ENV.fetch('FRONTEND_URL', '').presence
    return if base_url.blank?

    <<~HTML
      <script>
        window.chatwootSettings = { hideMessageBubble: true };
        (function(d,t) {
          var BASE_URL="#{base_url}";
          var g=d.createElement(t),s=d.getElementsByTagName(t)[0];
          g.src=BASE_URL+"/packs/js/sdk.js";
          g.defer = true;
          g.async = true;
          s.parentNode.insertBefore(g,s);
          g.onload=function(){
            window.chatwootSDK.run({
              websiteToken: '#{token}',
              baseUrl: BASE_URL
            })
          }
        })(document,"script");
      </script>
    HTML
  end
end
