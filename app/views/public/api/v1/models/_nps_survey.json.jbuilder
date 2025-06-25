json.id resource.id
json.nps_survey_response resource.nps_survey_response
json.display_type resource.inbox.nps_config.try(:[], 'display_type') || 'emoji'
json.content resource.inbox.nps_config.try(:[], 'message')
json.inbox_avatar_url resource.inbox.avatar_url
json.inbox_name resource.inbox.name
json.locale resource.account.locale
json.conversation_id resource.conversation_id
json.created_at resource.created_at
