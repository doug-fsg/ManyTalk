json.payload do
  json.array! @submissions do |submission|
    json.id submission.id
    json.created_at submission.created_at.to_i
    json.payload submission.payload
    json.utm submission.utm
    json.contact do
      if submission.contact
        json.id submission.contact.id
        json.name submission.contact.name
        json.email submission.contact.email
        json.phone_number submission.contact.phone_number
      else
        json.nil!
      end
    end
  end
end

json.meta do
  json.current_page @submissions.current_page
  json.total_pages @submissions.total_pages
  json.total_count @submissions.total_count
end
