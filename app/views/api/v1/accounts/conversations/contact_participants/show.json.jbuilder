json.array! @contacts do |contact|
  json.partial! 'api/v1/models/contact', formats: [:json], resource: contact
end
