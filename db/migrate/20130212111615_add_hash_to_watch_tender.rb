class AddHashToWatchTender < ActiveRecord::Migration
  def up
    add_column :watch_tenders, :hash, :string
  end

  def down
    remove_column :watch_tenders, :hash
  end
end
