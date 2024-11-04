require 'administrate/base_dashboard'

class AccountDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number.with_options(searchable: true),
    name: Field::String.with_options(searchable: true),
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
    users: CountField,
    conversations: CountField,
    locale: Field::Select.with_options(collection: LANGUAGES_CONFIG.map { |_x, y| y[:iso_639_1_code] }),
    status: Field::Select.with_options(collection: [%w[Active active], %w[Suspended suspended]]),
    account_users: Field::HasMany
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    name
    locale
    users
    conversations
    status
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    name
    created_at
    updated_at
    locale
    status
    conversations
    account_users
  ].freeze

  FORM_ATTRIBUTES = %i[
    name
    locale
    status
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(account)
    "##{account.id} #{account.name}"
  end

  def permitted_attributes(action)
    super
  end
end
