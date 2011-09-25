require 'sinatra'
require './templates'

get '/' do
    template :index, "Welcome!"
end
