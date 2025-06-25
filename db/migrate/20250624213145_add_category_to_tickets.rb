class AddCategoryToTickets < ActiveRecord::Migration[7.1]
  def change
    add_column :tickets, :category, :string
    add_index :tickets, :category
    
    # Add default ticket categories to all existing accounts
    reversible do |dir|
      dir.up do
        default_categories = [
          'General Support',
          'Technical Issue',
          'Billing',
          'Feature Request',
          'Bug Report',
          'Account Management',
          'Sales Inquiry'
        ]
        
        Account.find_each do |account|
          settings = account.settings || {}
          settings['ticket_categories'] = default_categories unless settings.key?('ticket_categories')
          account.update!(settings: settings)
        end
      end
    end
  end
end
