require 'heroku/helpers'
require 'heroku/command'
require 'heroku/command/run'
require 'tmpdir'
require 'getoptlong'

class Heroku::Command::Mysql < Heroku::Command::Run
    @@local_database = {
        'user'      => 'root',
        'password'  => nil,
        'host'      => 'localhost',
        'database'  => nil,
        'port'      => nil,
    }

    @@heroku_database = {
        'user'      => nil,
        'password'  => nil,
        'host'      => nil,
        'database'  => nil,
        'port'      => nil,
    }

    @@search  = nil
    @@replace = nil
    @@db      = nil

    def index
        puts "Usage in https://github.com/josepfrantic/heroku-cleardbdump/blob/master/README.md"
        exit
    end

    def pull
        puts "Remote database (Heroku) to local database"
        local_database_setup(ARGV)
        database_url = get_remote_database()
        if database_url.nil?
            puts "Error: Heroku database URL not defined"
            exit
        end
        parse_mysql_dsn_string(database_url, @@heroku_database)

        do_transfer(@@heroku_database, @@local_database)
    end

    def push
        puts "Local database to remote database (Heroku)"
        puts "Warning! Make sure to take a backup of the remote database first. Press 'y' to continue: "
        prompt = STDIN.gets.chomp
        return unless prompt == 'y'

        local_database_setup(ARGV)
        database_url = get_remote_database()
        if database_url.nil?
            puts "Error: Heroku database URL not defined"
            exit
        end
        parse_mysql_dsn_string(database_url, @@heroku_database)

        do_transfer(@@local_database, @@heroku_database)
    end

    def dump
        database_url = get_remote_database()
        if database_url.nil?
            puts "Error: Heroku database URL not defined"
            exit
        end
        parse_mysql_dsn_string(database_url, @@heroku_database)

        Dir.mktmpdir do |dir|
            Dir.chdir(dir) do
                take_mysqldump(@@heroku_database, true)
            end
        end
    end

private
    # Get remote database url. Currently supported ClearDB and JawsDB
    def get_remote_database
        cleardb = api.get_config_vars(app).body["CLEARDB_DATABASE_URL"]
        jawsdb = api.get_config_vars(app).body["JAWSDB_URL"]

        if @@db == 'cleardb'
            puts "Using ClearDB"
            return cleardb
        elsif @@db == 'jawsdb'
            puts "Using JawsDB"
            return jawsdb
        elsif jawsdb && cleardb
            puts "Warning! Both ClearDB and JawsDB seem to be defined. Please indicate which one to use with the --db parameter"
            return nil
        elsif cleardb
            puts "Using ClearDB"
            return cleardb
        elsif jawsdb
            puts "Using JawsDB"
            return jawsdb
        end

        return nil
    end

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
            [ '--app',      '-a', GetoptLong::OPTIONAL_ARGUMENT ],
            [ '--db',       '-d', GetoptLong::OPTIONAL_ARGUMENT ]
        )

        opts.each do |opt, arg|
          case opt
            when '--search'
                @@search    = arg
            when '--replace'
                @@replace   = arg
            when '--db'
                @@db        = arg
            end
        end
    end

    def parse_mysql_dsn_string(database_url, database)
        if /^mysql:\/\/(.+):(.+)@(.+?):?(\d{1,})?\/([a-zA-Z0-9_-]+)(\?reconnect=true)?$/.match(database_url)
            database['user']      = $1
            database['password']  = $2
            database['host']      = $3
            database['port']      = $4
            database['database']  = $5
        else
            puts "Error. Could not parse url: #{database_url}"
            exit
        end
    end

    def do_transfer(from_db, to_db)
        Dir.mktmpdir do |dir|
            puts "Created temporary directory in: #{dir}"

            Dir.chdir(dir) do
                take_mysqldump(from_db, false)
                import_to_mysql(to_db)

                if ( @@search.nil? == false && @@replace.nil? == false )
                    run_search_and_replace(to_db)
                end

                puts "\nAll done!"
            end
        end
    end

    def take_mysqldump(database, print_to_stdout)
        mysqldump_command = "mysqldump -u#{database['user']} "

        unless ( database['password'].nil? )
            mysqldump_command += "-p#{database['password']} "
        end

        unless ( database['port'].nil? )
            mysqldump_command += "-P#{database['port']} "
        end

        mysqldump_command += "-h#{database['host']} #{database['database']} 2>/dev/null > dump.sql"

        if ( print_to_stdout == false )
            puts "Executing: #{mysqldump_command}"
        end

        unless ( system %{#{mysqldump_command}} )
            puts "Error executing command"
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

        puts "Executing: #{mysqlrestore_command}"
        unless ( system %{#{mysqlrestore_command}} )
            puts "Error executing command"
            exit
        end
    end

    def run_search_and_replace(database)
        # Download Search and replace script
        puts "Downloading Search-Replace-DB files"
        system %{curl -fsS https://raw.githubusercontent.com/interconnectit/Search-Replace-DB/master/srdb.class.php -o srdb.class.php}
        system %{curl -fsS https://raw.githubusercontent.com/interconnectit/Search-Replace-DB/master/srdb.cli.php -o srdb.cli.php}

        search_and_replace_command = "php srdb.cli.php -u #{database['user']} "

        if ( database['password'].nil? )
            search_and_replace_command += "-p '' "
        else
            search_and_replace_command += "-p#{database['password']} "
        end

        search_and_replace_command += "-h #{database['host']} -n #{database['database']} -s #{@@search} -r #{@@replace}"

        puts "Executing: #{search_and_replace_command}"
        unless ( system %{#{search_and_replace_command}} )
            puts "Error executing command"
            exit
        end
    end
end
