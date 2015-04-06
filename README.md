# ClearDBdump

## Installation
```
heroku plugins:install https://github.com/josepfrantic/heroku-cleardbdump
```

## Usage

All commands accept Heroku's --app <heroku_application_name> convention

### ClearDB to local MySQL

#### Basic usage

```
heroku cleardb:pull <local_database_name | MySQL DSN string>
```

#### With Search and replace script

```
heroku cleardb:pull <local_database_name | MySQL DSN string> --search mysite.herokuapp.com --replace localhost:6666
```

### Local MySQL to ClearDB

#### Basic usage

```
heroku cleardb:push <local_database_name | MySQL DSN string>
```

#### With Search and replace script

```
heroku cleardb:push <local_database_name | MySQL DSN string> --search localhost:6666 --replace mysite.herokuapp.com
```

### Taking a database backup from Heroku

```
heroku cleardb:dump > project_production_$(date +"%F_%T").sql
```
