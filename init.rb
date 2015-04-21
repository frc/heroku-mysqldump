require 'heroku/helpers'
require 'heroku/command'
require 'heroku/command/run'
require 'tmpdir'
require 'getoptlong'

class Heroku::Command::Cleardb < Heroku::Command::Run
    @@local_database = {
        'user'      => 'root',
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
        puts "Usage in https://github.com/josepfrantic/heroku-cleardbdump/blob/master/README.md"
        exit
    end

    def pull
        local_database_setup(ARGV)
        database_url = api.get_config_vars(app).body["CLEARDB_DATABASE_URL"]
        if database_url.nil?
            puts "CLEARDB_DATABASE_URL not defined".red
            exit
        end
        parse_mysql_dsn_string(database_url, @@cleardb_database)

        do_transfer(@@cleardb_database, @@local_database)
    end

    def push
        local_database_setup(ARGV)
        database_url = api.get_config_vars(app).body["CLEARDB_DATABASE_URL"]
        if database_url.nil?
            puts "CLEARDB_DATABASE_URL not defined".red
            exit
        end
        parse_mysql_dsn_string(database_url, @@cleardb_database)

        do_transfer(@@local_database, @@cleardb_database)
    end

    def dump
        database_url = api.get_config_vars(app).body["CLEARDB_DATABASE_URL"]
        parse_mysql_dsn_string(database_url, @@cleardb_database)

        Dir.mktmpdir do |dir|
            Dir.chdir(dir) do
                take_mysqldump(@@cleardb_database, true)
            end
        end
    end

private
    def local_database_setup(arguments)
        if ( arguments.count <= 1 )
            puts 'Missing parameter: database name or full MySQL DSN'
            exit
        end

        if /^mysql:/.match(arguments[1])
            # Treat argument as MySQL DSN
            parse_mysql_dsn_string(arguments[1], @@local_database)
        else
            # Treat argument as database name
            @@local_database['database'] = arguments[1]
        end

        opts = GetoptLong.new(
            [ '--search',   '-s', GetoptLong::OPTIONAL_ARGUMENT ],
            [ '--replace',  '-r', GetoptLong::OPTIONAL_ARGUMENT ],
            [ '--app',      '-a', GetoptLong::OPTIONAL_ARGUMENT ]
        )

        opts.each do |opt, arg|
          case opt
            when '--search'
                @@search    = arg
            when '--replace'
                @@replace   = arg
            end
        end
    end

    def parse_mysql_dsn_string(database_url, database)
        if /^mysql:\/\/(.+):(.+)@(.+)\/(\w+)(\?reconnect=true)?$/.match(database_url)
            database['user']      = $1
            database['password']  = $2
            database['host']      = $3
            database['database']  = $4
        else
            puts "\nFailing to parse url".red
            exit
        end
    end

    def do_transfer(from_db, to_db)
        Dir.mktmpdir do |dir|
            puts "\nCreated temporary directory in: #{dir}"

            Dir.chdir(dir) do
                take_mysqldump(from_db, false)
                import_to_mysql(to_db)

                if ( @@search.nil? == false && @@replace.nil? == false )
                    run_search_and_replace(to_db)
                end

                puts "\nAll done".green
            end
        end
    end

    def take_mysqldump(database, print_to_stdout)
        mysqldump_command = "mysqldump -u#{database['user']} "

        unless ( database['password'].nil? )
            mysqldump_command += "-p#{database['password']} "
        end

        mysqldump_command += "-h#{database['host']} #{database['database']} 2>/dev/null > dump.sql"

        if ( print_to_stdout == false )
            puts "\nExecuting: #{mysqldump_command}"
        end

        unless ( system %{#{mysqldump_command}} )
            puts "Error executing command".red
            exit
        end

        if ( print_to_stdout == true )
            system %{cat dump.sql}
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

        if ( database['password'].nil? )
            search_and_replace_command += "-p '' "
        else
            search_and_replace_command += "-p#{database['password']} "
        end

        search_and_replace_command += "-h #{database['host']} -n #{database['database']} -s #{@@search} -r #{@@replace}"

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
end
