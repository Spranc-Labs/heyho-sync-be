class AddIndexesForInsightsQueries < ActiveRecord::Migration[7.0]
  def change
    # Composite index for date-range queries on page visits
    add_index :page_visits, %i[user_id visited_at], name: 'index_page_visits_on_user_and_visited_at'

    # Composite index for domain-based queries
    add_index :page_visits, %i[user_id domain], name: 'index_page_visits_on_user_and_domain'

    # Composite index for domain + date queries (top sites over time)
    add_index :page_visits, %i[user_id domain visited_at], name: 'index_page_visits_on_user_domain_and_visited_at'
  end
end
