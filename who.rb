require 'sinatra'
require 'net/ldap'

def ldap_connect
  ldap = Net::LDAP.new :host => "directory.nd.edu",
    :port => 389,
    :base => "o=University of Notre Dame,st=Indiana,c=US",
    :auth => {
      :method => :anonymous
     }  
end

def lookup(entity,entity_type)

  if entity_type = "email" then filter_type = "ndMail"
  if entity_type = "netid" then filter_type = "uid"

  filter = Net::LDAP::Filter.eq(filter_type, entity)

  ldap.search(:filter => filter) do |entry|
    # puts "#{entry.uid},#{entry.ndPrimaryAffiliation}\n"
    
    
  end
end


get '/' do
  erb :index
end

post '/' do
  #  pseudocode here
  #  @entities = stuff
  #  @attributes = stuff
  #
  # Do lookups
  # Get attributes
  # Redirect to results page
  
  
end