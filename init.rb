require 'heroku/helpers'
require 'heroku/command'
require 'heroku/command/run'

class Heroku::Command::Cleardbdump < Heroku::Command::Run
    def index
        puts "Hello world"
    end
end
