class UpdateSkillmasterApplications < ActiveRecord::Migration[7.0]
  def change
    # Adding the many-to-many relationship for categories with a shorter index name
    create_join_table :categories, :skillmaster_applications, table_name: :categories_skillmaster_apps do |t|
      t.index %i[category_id skillmaster_application_id], name: 'index_cat_sma_on_cat_id_and_sma_id', unique: true
    end

    # Adding the many-to-many relationship for platforms with a shorter index name
    create_join_table :platforms, :skillmaster_applications, table_name: :platforms_skillmaster_apps do |t|
      t.index %i[platform_id skillmaster_application_id], name: 'index_plat_sma_on_plat_id_and_sma_id', unique: true
    end

    # Adding gamer_tag and reasons fields
    add_column :skillmaster_applications, :gamer_tag, :string  # Links to user's gamer_tag
    add_column :skillmaster_applications, :reasons, :text      # Text field for reasons

    # Adding array of images
    add_column :skillmaster_applications, :images, :string, array: true, default: [] # Array of image URLs
  end
end
