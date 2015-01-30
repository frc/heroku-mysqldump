require 'heroku/helpers'
require 'heroku/command'
require 'heroku/command/run'
require 'getoptlong'
require 'tmpdir'

class Heroku::Command::Cleardbdump < Heroku::Command::Run
    @@local_database = {
        'user'      => nil,
        'password'  => nil,
        'host'      => 'localhost',
        'database'  => nil,
    }

    @@cleardb_database = {
        'user'      => nil,
        'password'  => nil,
        'host'      => nil,
        'database'  => nil,
    }

    @@search  = nil
    @@replace = nil

    def index
        puts "TODO usage"
    end

    def pull
        parse_local_database_parameters()

        database_url = api.get_config_vars(app).body["CLEARDB_DATABASE_URL"]
        parse_cleardb_connection_parameters(database_url)

        do_transfer(@@cleardb_database, @@local_database)
    end

    def push
        parse_local_database_parameters()

        database_url = api.get_config_vars(app).body["CLEARDB_DATABASE_URL"]
        parse_cleardb_connection_parameters(database_url)

        do_transfer(@@local_database, @@cleardb_database)
    end

private
    def parse_local_database_parameters
        opts = GetoptLong.new(
            [ '--user',     '-u', GetoptLong::REQUIRED_ARGUMENT ],
            [ '--password', '-p', GetoptLong::REQUIRED_ARGUMENT ],
            [ '--database', '-d', GetoptLong::REQUIRED_ARGUMENT ],
            [ '--host',     '-h', GetoptLong::REQUIRED_ARGUMENT ],
            [ '--search',   '-s', GetoptLong::REQUIRED_ARGUMENT ],
            [ '--replace',  '-r', GetoptLong::REQUIRED_ARGUMENT ]
        )

        opts.each do |opt, arg|
          case opt
            when '--user'
                @@local_database['user']      = arg
            when '--password'
                @@local_database['password']  = arg
            when '--database'
                @@local_database['database']  = arg
            when '--host'
                @@local_database['host']      = arg
            when '--search'
                @@search                      = arg
            when '--replace'
                @@replace                     = arg
            end
        end

        if @@local_database['user'].nil?
            puts "Missing parameter user".red
            exit
        end

        if @@local_database['database'].nil?
            puts "Missing parameter user".red
            exit
        end
    end

    def parse_cleardb_connection_parameters(database_url)
        if /^mysql:\/\/(.+):(.+)@(.+)\/(.+)\?reconnect=true$/.match(database_url)
            @@cleardb_database['user']      = $1
            @@cleardb_database['password']  = $2
            @@cleardb_database['host']      = $3
            @@cleardb_database['database']  = $4
        else
            puts "\nFailing to parse url".red
            exit
        end
    end

    def do_transfer(from_db, to_db)
        Dir.mktmpdir do |dir|
            puts "\nCreated temporary directory in: #{dir}"

            Dir.chdir(dir) do

                take_mysqldump(from_db)

                import_to_mysql(to_db)

                if ( @@search.nil? == false && @@replace.nil? == false )
                    run_search_and_replace(to_db)
                end

                puts "\nAll done".green
            end
        end
    end

    def take_mysqldump(database)
        mysqldump_command = "mysqldump -u#{database['user']} "

        unless ( database['password'].nil? )
            mysqldump_command += "-p#{database['password']} "
        end

        mysqldump_command += "-h#{database['host']} #{database['database']} > dump.sql"

        puts "\nExecuting: #{mysqldump_command}"
        unless ( system %{#{mysqldump_command}} )
            puts "Error executing command".red
            exit
        end
    end

    def import_to_mysql(database)
        mysqlrestore_command = "mysql -u #{database['user']} "

        unless ( database['password'].nil? )
            mysqlrestore_command += "-p#{database['password']} "
        end

        mysqlrestore_command += "-h #{database['host']} #{database['database']} < dump.sql"

        puts "\nExecuting: #{mysqlrestore_command}"
        unless ( system %{#{mysqlrestore_command}} )
            puts "Error executing command".red
            exit
        end
    end

    def run_search_and_replace(database)
        # Download Search and replace script
        puts "\nDownloading Search-Replace-DB files"
        system %{curl -fsS https://raw.githubusercontent.com/interconnectit/Search-Replace-DB/master/srdb.class.php -o srdb.class.php}
        system %{curl -fsS https://raw.githubusercontent.com/interconnectit/Search-Replace-DB/master/srdb.cli.php -o srdb.cli.php}

        search_and_replace_command = "php srdb.cli.php -u #{database['user']} "

        unless ( database['password'].nil? )
            search_and_replace_command += "-p#{database['password']} "
        end

        search_and_replace_command += "-h #{database['host']} -n #{database['database']} -s #{@@search} -r #{@@replace}}"

        puts "\nExecuting: #{search_and_replace_command}"
        unless ( system %{#{search_and_replace_command}} )
            puts "Error executing command".red
            exit
        end
    end
end

# Proudly stolen from http://stackoverflow.com/questions/1489183/colorized-ruby-output/11482430#11482430
class String
    # colorization
    def colorize(color_code)
        "\e[#{color_code}m#{self}\e[0m"
    end

    def red
        colorize(31)
    end

    def green
        colorize(32)
    end

    def yellow
        colorize(33)
    end

    def pink
        colorize(35)
    end
end
