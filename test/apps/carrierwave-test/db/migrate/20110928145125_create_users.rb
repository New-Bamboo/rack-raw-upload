class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :thing
      t.timestamps
    end
  end
end
