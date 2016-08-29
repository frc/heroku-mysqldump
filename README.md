# heroku-mysqldump

Simple plugin to synchronize a Heroku remote MySQL database to a local MySQL database, and vice versa. Optional search and replace capabilities are included and provided by [Search-Replace-DB](https://github.com/interconnectit/Search-Replace-DB). Both ClearDB and JawsDB Heroku add-ons are supported.

## Installation
```
heroku plugins:install https://github.com/josepfrantic/heroku-mysqldump
```

## Usage

All commands accept Heroku's ```--app <heroku_application_name>``` convention.

By default the plugin assumes either ClearDB or JawsDB add-on is in use, but not both. In case of having both add-ons indicate which one you want to use with the --db parameter (Values accepted: cleardb / jawsdb).

**Note:** The plugin will overwrite existing database contents, and cannot be undone. You are encouraged to take a database backup before running mysql:push to production environments.

### Remote database (Heroku) to local MySQL database

#### Basic usage

```
heroku mysql:pull <local_database_name or MySQL DSN string>
```

#### Examples

```
heroku mysql:pull test --app my-heroku-app
heroku mysql:pull mysql://foo:bar@localhost/test --app my-heroku-app
```

#### With Search and replace

```
heroku mysql:pull <local_database_name | MySQL DSN string> --search mysite.herokuapp.com --replace localhost:5000
```

### Local MySQL to remote MySQL database (Heroku)

#### Basic usage

```
heroku mysql:push <local_database_name | MySQL DSN string>
```

#### With Search and replace

```
heroku mysql:push <local_database_name | MySQL DSN string> --search localhost:5000 --replace mysite.herokuapp.com
```

### Taking a database backup from Heroku

```
heroku mysql:dump > project_production_$(date +"%F_%H_%M_%S").sql
```

**Note:** Make sure to check the backup since errors are silenced from the output.
