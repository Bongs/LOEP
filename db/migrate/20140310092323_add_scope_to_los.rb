class AddScopeToLos < ActiveRecord::Migration
  def change
  	add_column :los, :scope, :string, :default => "Private"
  end
end
