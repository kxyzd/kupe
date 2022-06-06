require_relative 'httptrash'
require 'sinatra'

set :server, 'trash'

get '/' do
  pp params
  'Hahahah'
end
