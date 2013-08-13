require 'sinatra'
require 'net-ldap'

def check_login
  if session[:username] == ""
    redirect "/login"
  end
end

def ldap_connect(netid,pass)
  ldap = Net::LDAP.new :host => "directory.nd.edu",
    :port => 636,
    :base => "o=University of Notre Dame,st=Indiana,c=US",
    :encryption => :simple_tls,
    :auth => { 
      :method => :anonymous
    }
    userdn = ""
    filter = Net::LDAP::Filter.eq('uid', netid)
    entries = ldap.search(:filter => filter)
    if entries.size > 0
      for entry in entries
          userdn = entry.dn
      end
    end

  if userdn == ""
    return false
  else
    ldap.authenticate(userdn,pass)
    ldap.bind
  end

  if ldap.get_operation_result.code == 0
    session[:username] = netid
    true
  else
    session[:username] = ""
    false
  end
end

def lookup(entity,entity_type)

  if entity_type == "email" then filter_type = "ndMail" end
  if entity_type == "netid" then filter_type = "uid" end

  filter = Net::LDAP::Filter.eq(filter_type, entity)

  ldap.search(:filter => filter) do |entry|
    puts "#{entry.uid},#{entry.ndPrimaryAffiliation}\n"    
  end
end

get '/' do
  check_login
  erb :index
end

post '/' do
  entity_type = params[:entity_type]
  entities = params[:entities]
  attributes = params[:attributes]

  #  pseudocode here
  #  @entities = stuff
  #  @attributes = stuff
  #
  # Do lookups
  # Get attributes
  # Redirect to results page

end

get '/login' do
  if session[:username] != ""
    redirect '/'
  end
  erb :login
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