
require 'active_record'

# ActiveRecord::Base.establish_connection(
#   adapter: 'mysql2',
#   host: 'rds-auction-test.cpmjco64gbxp.ap-northeast-1.rds.amazonaws.com',
#   username: 'dbmaster',
#   password: 'dciMzsmR98JomEM4tpR1',
#   database: 'auction'
# )


ActiveRecord::Base.establish_connection(
  adapter: 'mysql2',
  host: '127.0.0.1',
  username: 'mars_dbuser',
  password: '123456!',
  database: 'deal_dash'
)



class CreateDealDashErrorTable < ActiveRecord::Migration[5.2]
     def change
         create_table :deal_dash_errors do |table|
             table.integer :auction_id
             table.string :message

             table.timestamps
         end
         add_index(:deal_dash_errors, :auction_id)
     end
end

class CreateDealDashRecordTable < ActiveRecord::Migration[5.2]
    def change
        create_table :deal_dash_records do |table|
            table.integer :auction_id
            table.decimal :price, precision: 10, scale: 2
            table.string :time
            table.string :user
            table.string :action
            
            table.timestamps
        end
        add_index(:deal_dash_records, :auction_id)
        add_index(:deal_dash_records, :price)
    end
end

class DealDashAddTitle < ActiveRecord::Migration[5.2]
  def change
    add_column :deal_dash_records, :title, :string
  end
end

class DealDashAddUserId < ActiveRecord::Migration[5.2]
    def change
      add_column :deal_dash_records, :user_id, :string
      add_index(:deal_dash_records, :user_id)
    end
  end

class CreateDealDashAuctionTable < ActiveRecord::Migration[5.2]
    def change
        create_table :deal_dash_auctions do |table|
            table.integer :auction_id
            table.string :title
            table.string :buy_it_now_price
            
            table.timestamps
        end
        add_index(:deal_dash_auctions, :auction_id)
    end
end


class CreateDealDashUserTable < ActiveRecord::Migration[5.2]
    def change
        create_table :deal_dash_users do |table|
            table.string :user_id
            table.string :user_name
            table.string :avatar_url
            table.string :bio
            table.string :register_date
            table.string :first_bid
            table.string :winning_limit_status
            table.string :state
            
            table.timestamps
        end
        add_index(:deal_dash_users, :user_id)
    end
end

class DealDashUserAddId < ActiveRecord::Migration[5.2]
    def change
      add_column :deal_dash_users, :revised_register_date, :datetime
    end
  end


CreateDealDashRecordTable.migrate(:up)

CreateDealDashErrorTable.migrate(:up)

CreateDealDashUserTable.migrate(:up)

DealDashUserAddId.migrate(:up)

