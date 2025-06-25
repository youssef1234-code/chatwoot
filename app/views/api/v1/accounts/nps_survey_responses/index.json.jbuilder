json.array! @nps_survey_responses do |nps_survey_response|
  json.partial! 'api/v1/models/nps_survey_response', formats: [:json], resource: nps_survey_response
end
