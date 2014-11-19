require 'sinatra'
require 'net-ldap'
require 'active_record'
require 'active_support'
require 'sqlite3'

enable :sessions
$stdout.sync = true

# was erroring out in local run - testing
set :protection, :except => :session_hijacking

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => "who.db")
Time.zone = "Eastern Time (US & Canada)"
$TIMEZONE = 'America/New_York'
$tz = TZInfo::Timezone.get($TIMEZONE)

# begin
#   # define database schema
#   ActiveRecord::Schema.define do
#     create_table :searches do |t|
#       t.string :ip_address
#       t.string :netid
#       t.string :entities
#       t.timestamps
#     end
#   end
# rescue ActiveRecord::StatementInvalid
# end

error do
  '' + request.env['sinatra.error'].message
end


# class Searches < ActiveRecord::Base
# end

def lookup(entity,entity_type)

  if entity_type == "email" then filter_type = "ndMail" end
  if entity_type == "netid" then filter_type = "uid" end

  filter = Net::LDAP::Filter.eq(filter_type, entity)

  results = @@ldap.search(:filter => filter)

  if results && results.size == 0
    @@missing << entity
    @@entities << entity unless @@remove_missing
  else
    if results[0].respond_to?(:ndCSOspecial)
      @@organizationals << entity
      results.push(true)
    else
      results.push(false)
    end
    results.insert(0,entity)
    @@entities << results
  end

end

@@ldap = Net::LDAP.new :host => "directory.nd.edu",
  :port => 636,
  :base => "o=University of Notre Dame,st=Indiana,c=US",
  :encryption => :simple_tls,
  :auth => { 
    :method => :anonymous
  }

def ldap_connect(netid,pass)
    session[:username] = ""
    userdn = ""
    filter = Net::LDAP::Filter.eq('uid', netid)
    entries = @@ldap.search(:filter => filter)
    if entries && entries.size > 0
      for entry in entries
          userdn = entry.dn
      end
    end

  if userdn == ""
    return false
  else
    @@ldap.authenticate(userdn,pass)
    @@ldap.bind
  end

  if @@ldap.get_operation_result.code == 0
    session[:username] = netid
    $logged_in = true
    true
  else
    $logged_in = false
    false
  end
end

def check_login
  if session[:username] == "" || session[:username].nil?
    redirect "/login"
  end
end

get '/' do
  check_login
  erb :index
end

post '/' do
  @@missing = []
  @@duplicates = []
  @@entities = []
  @@remove_missing = false
  @@entity_type = []
  @@original_entities = []
  @@attributes = []
  @@organizationals = []

  check_login

  @@entity_type = params[:entity_type]
  @@original_entities = params[:entities].split("\r\n")
  @@attributes = params[:attributes]
  
  if params[:remove_missing] == "true"
    @@remove_missing = true
  else
    @@remove_missing = false
  end

    # # log this search in database
    # @search = Search.create(:ip_address => request.ip, :netid => session[:username], :entities => @@original_entities.size) 
    # @search.save!

  puts "Executing lookup on #{@@original_entities.size} entities by #{@@entity_type}"
  idx = 0
  for entity in @@original_entities
    idx = idx + 1
    puts "  #{idx}: #{entity}"
    lookup(entity,@@entity_type)
  end
  puts "Found: #{@@entities.size} of #{@@original_entities.size} entities"
  puts "Missing: #{@@missing.size}"
  puts "Duplicates: #{@@duplicates.size}" 
  puts "Organizational: #{@@organizationals.size}" 

  redirect '/results'
end

get '/results' do
  check_login
  erb :results
end

get '/csv' do
  check_login
  headers "Content-Disposition" => "attachment;filename=ndwho#{Time.now.strftime("%m-%d-%Y-%I-%M%p")}.csv", "Content-Type" => "application/octet-stream"
  erb :csv, :layout => false
end

get '/xls' do
  check_login 
  headers "Content-Disposition" => "attachment;filename=ndwho#{Time.now.strftime("%m-%d-%Y-%I-%M%p")}.xls", "Content-Type" => "application/vnd.ms-excel"
  erb :xls, :layout => false
end


get '/login' do
  if $logged_in
    redirect '/'
  end
  erb :login
end

get '/logout' do
  session[:username] = ""
  $logged_in = false
  redirect '/login'
end

post '/login' do
  username = params[:username]
  password = params[:password]  
  if username == "" or password == "" then
    redirect '/login?result=required'
  end

  if ldap_connect(username,password)
    redirect '/'
  else
    redirect '/login?result=failed'
  end
end
