require 'sinatra'
require 'net-ldap'
require 'sinatra/cas/client'

enable :sessions
enable :logging
$stdout.sync = true

register Sinatra::CAS::Client

  set :cas_base_url, 'https://login.nd.edu/cas'
  set :service_url, 'http://localhost:5000'
  set :console_debugging, true

  set :port, 443

  # was erroring out in local run - testing
  # set :protection, :except => :session_hijacking

error do
  '' + request.env['sinatra.error'].message
end


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

# def ldap_connect(netid,pass)
#     session[:username] = ""
#     userdn = ""
#     filter = Net::LDAP::Filter.eq('uid', netid)
#     entries = @@ldap.search(:filter => filter)
#     if entries && entries.size > 0
#       for entry in entries
#           userdn = entry.dn
#       end
#     end
# 
#   if userdn == ""
#     return false
#   else
#     @@ldap.authenticate(userdn,pass)
#     @@ldap.bind
#   end
# 
#   if @@ldap.get_operation_result.code == 0
#     session[:username] = netid
#     $logged_in = true
#     logger.info "Connected to LDAP - authenticated as #{netid}"
#     true
#   else
#     $logged_in = false
#     logger.info "Connected to LDAP - unauthenticated"
#     false
#   end
# end

def check_login
  if authenticated?
    # Do you want to come back to my place?
    true
  else
    # "My hovercraft is full of eels."
    authenticate
  end
end

get '/' do
  check_login
  erb :index
end

post '/' do
  check_login
  
  @@missing = []
  @@duplicates = []
  @@entities = []
  @@remove_missing = false
  @@entity_type = []
  @@original_entities = []
  @@attributes = []
  @@organizationals = []

  @@original_entities = params[:entities].split("\r\n")
  @@attributes = params[:attributes]

  if @@original_entities.first.include? "@"
    @@entity_type = "email"
  else
    @@entity_type = "netid"
  end
  
  if params[:remove_missing] == "true"
    @@remove_missing = true
  else
    @@remove_missing = false
  end

    # log this search
    query_log_entry = "#{Time.now},#{request.ip},#{session[settings.username_session_key]},#{@@original_entities.size},#{@@entity_type}"

    # append query_log_entry to a file to be rotated
    File.open('log/ndwho.log', 'a') do |f2|  
      f2.puts "#{query_log_entry}\n"
    end

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

get '/logout' do
  session[settings.username_session_key] = nil
  redirect settings.cas_base_url
end
