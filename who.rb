require 'sinatra'
require 'net-ldap'

enable :sessions

def lookup(entity,entity_type)

  if entity_type == "email" then filter_type = "ndMail" end
  if entity_type == "netid" then filter_type = "uid" end

  filter = Net::LDAP::Filter.eq(filter_type, entity)

  results = @@ldap.search(:filter => filter)
  if results && results.size == 0
    @@missing << entity
    @@entities << entity unless @@remove_missing
  else
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

  check_login

  @@entity_type = params[:entity_type]
  @@original_entities = params[:entities].split("\r\n")
  @@attributes = params[:attributes]
  
  if params[:remove_missing] == "true"
    @@remove_missing = true
  else
    @@remove_missing = false
  end

  for entity in @@original_entities
    lookup(entity,@@entity_type)
  end

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
