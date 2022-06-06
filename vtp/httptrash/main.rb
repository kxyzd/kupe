require_relative 'httptrash'
require 'rack'
require 'rack/lobster'

WebTrash::HTTPServer.new.run! Rack::Lobster.new
