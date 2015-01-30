# ClearDBdump

## Installation
```
heroku plugins:install https://github.com/josepfrantic/heroku-cleardbdump
```

## Usage

### ClearDB to local MySQL

#### Basic usage

```
heroku cleardbdump:pull -u root -d cleardbdump
```

#### With Search and replace script

```
heroku cleardbdump:pull -u root -d cleardbdump --search mysite.herokuapp.com --replace localhost:6666
```

### Local MySQL to ClearDB

#### Basic usage

```
heroku cleardbdump:push -u root -d cleardbdump
```

#### With Search and replace script

```
heroku cleardbdump:push -u root -d cleardbdump --search localhost:6666 --replace mysite.herokuapp.com
```
