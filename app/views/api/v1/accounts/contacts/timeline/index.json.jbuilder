json.meta do
  json.count @result[:count]
  json.current_page @result[:current_page]
  json.total_pages @result[:total_pages]
end

json.payload @result[:events]
