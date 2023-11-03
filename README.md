% rd(1) | General Commands Manual
# NAME

	rd - display data remotely, serves as KV store

![UI](https://github.com/nkh/bash-rd/blob/main/media/rd.gif)

# SYNOPSIS

	rd CONNECTION [FORMATTER]

	rd --connect ID

# DESCRIPTION

Write data to a file descriptor and have it displayed in another terminal, on another computer, in a web page.

***rd*** provides the transport layer and an ephemeral key-value store.

The Data is simply echoed by the server but you can provide custom formatters.

# SECURITY

With *rd* on a port you may open a security hole, If you are not sure about what you're doing, don't use rd!

Options *-l, -f, -i* do not open ports. Close servers when you're done.

## Remote input and output

If you need to send data to the server or get output from the server, understand the consequences first.

### Data in

The best is not accept data from anyone but you or processes you control (including controlling what input they take in).

- Have a watertight firewall
- open the port to your server only and close it when done
- proxy the connection and filter the traffic, netcat, ncat, socat can help you

### Data out

There are two possibilities, serve a web page or relay the server's output. Both are documented below.

# CONNECTION

## Server

*rd* starts a server, it will display where you can connect.

### Server local

| Type        | Command  | Argument |
| ----------- | -------- | -------- |
| dir local   | -l       |          |
| fifo        | -f       |          |
| user ID     | -i       | ID       |

### Server networked

| Type        | Command  | Argument              |
| ----------- | -------- | --------------------- |
| port        | -p       | port                  |
| web server  | -w       | port, formatter[, id] |


## Client

*rd* connects a file descriptor to a server.

| Type          | Command  | Argument     |
| -----------   | -------- | --------     |
| connect       | -c       | ID           |
| net connect   | -n       | port         |
| net connect   | -N       | address port |
| relay         | -r       | ID           |
| network relay | -R       | port         |

# Examples

## Dir local

Simplest setup when you run both the server and client in the same directory, in different terminals.

No formatter given, data is echoed by *rd*

```
$> rd -l
rd: ID: XXXXXX

$> program >XXXXXX

$> program 3>XXXXXX # you chose which file descriptor you use to send remote data

```

With a formatter, you decide how the data is used

```
$> rd -l my_formatter
rd: ID: XXXXXX

$> bash_script 3>XXXXXX
```

## FIFO

```
$> rd -f
rd: ID: XXXXXX

$> cat > >(rd -c XXXXXX)
```

## User ID

You can give an alphanumeric ID (or generate it, ex: https://github.com/fnichol/names).

```
$> rd -i my_id 
rd: ID: my_id

$> cat | rd -c my_id
```

## Networked

### Security

With rd on a port you may open a security hole!

### Local port

```
$> rd -p my_port
rd: port: my_port

$> cat | rd -n my_port

$> cat > >(rd -N host my_port)
```

### Web page

```
$> rd -w port web_table XXX
rd: ID: XXX

# generate a page
$> rd -n XXX '=:x=1'

$> firefox http:/localhost:$port
$> curl localhost:$port 2>&- | cat 
```

# PROTOCOL

*rd* accepts some control commands.

| Prefix | Action        | Description                                                     |
| ------ | ------------- | --------------------------------------------------------------- |
| q:     | quit          | stop the server                                                 |
| s:     | semaphore     | increment the server semaphore, needs to be 0 to quit           |
| c:     | clear         | clear terminal                                                  |
| e:     | when          | when to run the formatter. 0: always, 1: never, nothing: now    |
| k:     | clean up data | use it if rd complains about existing data                      |
| f:     | set formatter | dynamically set the formatter                                   |
| r:     | relay output  | format r:location:[pid]                                         |
|        |               |                                                                 |
| =:     | key=value;... | send a list of key=values to server                             |
|        |               | the key must match [\_a-zA-Z0-9] immediately followed by '='    |
|        |               | the value can contain spaces, it's evaluated withing quotes     |
|        |               | multiple KV can be send simultaneously if they are separated    |
|        |               | by a ';'. No space is allowed between ';' and the next key      |

## Key-Value store

Store data on the server, they will be available to the formatters.

```bash
echo '=:key=value;other_key=value'
```

## Automatic call to formatter, the default

```bash
# file descriptor to match what set on the command line
fd=3

# runs formatter
echo "=:a=the value of a" >&$fd

# runs formatter
echo "=:b=123" >&$fd # note that a and b are available to the formatter

# runs formatter
echo "some random text" >&$fd

# shutdown server
echo "q:" >&$fd
```

## Manual formatter call

```bash
fd=3

# wait for command ':e' to run formatter 
echo "e0:" >&$fd

# will not run the formatter
echo "=:a=the value of a" >&$fd
echo "=:b=123" >&$fd

# run formatter 
echo "e:"

# from this point always run the formatter 
echo "e1:"
```

# USAGE

## Multiple clients to one server

See video at top of README.md.

By incrementing the quit semaphore, each client can quit and the server will quit when the last client quits.

## Connect to multiple servers

You can connect to  multiple server.

```bash
# terminal 1
$> rd -i server1

# terminal 2
$> rd -i server2

# terminal 3
$> script 3> >(rd -c server1) 4> >(rd -c server2)
```

The script, or equivalent command in Perl, C, Go, Pyton, ... application

```bash
fd=3  # the file descriptor you chose to use to send data
fd2=4 # send data to different servers

# will run the formatter
echo "the value of a" >&$fd

# will run the formatter
echo -e "the value of a;b:123;c:  has spaces before has:d:with \0 binary" >&$fd2

# will run the formatter
echo "some random string" >&$fd
```

## Send identical data to multiple servers

```
command | tee >(rd -c ID) > >(rd -n port)
```

## Send data inside a pipe

```
command | tee >(rd -c ID) | other_command
```

## Usage in bash

```bash
ls --color | rd -c id

<<<'c:' rd -n port

tree -C -d > >(rd -c id)

rd -n 1234 "something to send"
```

## Usage in perl

```perl
open my $fh, ">&=", 3 ; 
$fh->autoflush(1) ;

print $fh "c:\n" ; # clear
print $fh DumpTree $data, ...

```

# FORMATTERS 

A formatter is a program that formats the received data, it can be as complicated or simple as you want.

Without a formatter the data is echoed.

Formatters get key/value stored in their environment.

*rd* variables of interest:
- $rd_pid, the pid of the server
- $rd_counter, number of received lines
- $rd_line, the last received data

Things you can do:

- render specific variables in a table 
- parse variable for content and location to display `echo "key:/x,y/value"`
- list variables newest set first
- show data structures

## SECURITY

With rd on a port and a formatters you may open a security hole!

See *Relays* below for a read only solution

## Templating

A nice way to present data is with the use of templates.

I like *bash-tpl*, a templating engine that generates bash scripts.

[Bash-TPL](https://github.com/TekWizely/bash-tpl)

## Generating a web page

You can use any HTML generator you like in your formatter, the HTML must be put in *$rd_web_page*.

```bash
name1="$(printf "%8s" "$x")"
name2="$(printf "%8s" "$y")"

cat > $rd_web_page << EOP
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8

<html>
	<body>
		<pre>
+---+---------+
| k |  value  |
+---+---------+
| x |$name1 |
| y |$name2 |
+-------------+
		</pre>
	</body>
</html>
EOP
```

# DATA STRUCTURES

Say you have a JSON data structure with embedded new line, you want to see formatted by *jq*.

First you'll need a specialized formatter that takes a variable and pass it to *jq*. 

To send a variable with embedded new lines we need to encode it, the simplest is in base64.

On the client side:

```bash
# set the key 'json' to the encoded json
printf 'json=%s\n' "$(<<<"$json" base64 -w 0)"
```

On the server side:

```bash
<<<"$json" base64 --decode | jq
```

See the *examples* directory for the full example.

# LOG

Keep a log of all traffic in a file, note the final ':' after the file name.

```bash
echo 'r:log_file:' | rd -c id
```

# RELAYS

Get a server's output to another terminal, relay will close when server closes.

```bash
rd -r id
```

## Relay with a custom formatter

```
rd -r id log4j
```

## Relay rd running on a port

```bash
rd -R port log4j
```

## Relay rd running on another host

If you can ssh to the other host:

```bash
ssh me@host rd -r id 
```

### Securely relaying to a client on the internet

On the server:

```bash
# generate private key
openssl genrsa -out server.key 2048 

## generate server certificate
openssl req -new -key server.key -x509 -days 1 -out server.crt

## generate server pem
cat server.key server.crt > server.pem 
rm server.key
```

On the client:

```bash
openssl genrsa -out client.key 2048 
openssl req -new -key client.key -x509 -days 1 -out client.crt
cat client.key client.crt > client.pem 
rm client.key
```

**** Exchange ONLY .cert files ****, via mail etc ..., safe as they are encrypted

On server:

```bash
# start rd server
rd -i 1234
```

Forward the data send by server on port 1234 via encrypted and authenticated connection

Note that we:
- setup an unidirectional tunnel with -u
- fix the version of ssl to 1.3
- accept a single connection and then close

```bash
rd -r 1234 | socat -u - ssl-l:1234,reuseaddr,cert=server.pem,cafile=client.crt,verify=1,openssl-min-proto-version=TLS1.3,openssl-max-proto-version=TLS1.3
```

On client connect using ssl and output to terminal 

```bash
socat -u ssl:localhost:1234,cert=client.pem,cafile=server.crt,openssl-min-proto-version=TLS1.3,openssl-max-proto-version=TLS1.3 -
```

Closing the server closes:
- the relay, and its sub processes
- the server side tls proxy
- the client side proxy
- the client side end point (SDTOUT in the code above)

***Note:*** relaying has a noticeable impact on the server performance as it needs
send every line to all relays in a separate process. Let me know if performance is
a problem.

### LAST WORD OF CAUTION

If you are not used to open application to internet traffic, or even your intranet, talk to someone knowledgeable or your IT department first.

Offering data as read only via a web service is simple and safe, still anyone with the address sees the data.

The same amount of caution must be used when passing data to a formatter, filter the input, use chroot, running in pods, ...

# CUSTOM FORMATTERS

Say you want to log 'log4j' style with colors (log4j is just hyped syslog).

You'll need:
- a set of log4j functions
- a log4j formatter

## Levels and colors

```bash
declare -A log4j_levels=( ['DEBUG']=0 ['INFO']=1 ['NOTICE']=2 ['WARN']=3 ['ERROR']=4 ['CRIT']=5 ['ALERT']=6 ['EMERG']=7)
log4j_colors=(            '35'        '2;34'     '2;32'       '33'       '31'        '4;31' '5;31'  '101;93')

```

## log4j functions for bash scripts

```bash
# destination, a file descriptor, where messages are send, stderr by default
log4j_sink=2

# a function to set the destination
log4j_sink()  { log4j_sink="$1" ; }

# minimum message level to display, pass a string 'DEBUG', 'INFO', ... as argument
log4j_level() { log4j_level=${log4j_levels[$1]} ; echo "log4j_level=$log4j_level" >$log4j_sink ; }

# send message to destination
log4j_send()    { echo "$*" >&$log4j_sink ; }

# finally create log functions corresponding to the levels
for l in "${!log4j_levels[@]}" ; do eval "log_${l,,}() { log4j_send '$l:' \"\$@\" ; }" ; done
```

## Formatter

```bash
# is it a message 
[[ "$rd_line" =~ ^(.*):(.*) ]] && level_name="${BASH_REMATCH[1]}" && [[ "$log4j_levels[$level_name]" ]] &&
	{
	# what's its level ?
	level=${log4j_levels[$level_name]}
	
	# display message if level high enough
	(( level >= log4j_level )) && { echo -ne "\e[${log4j_colors[$level]}m$level_name:\e[m" ; echo ${BASH_REMATCH[2]} ; }
	}
```

The complete code is in *examples/log4j*.

To get access to the function you source the file, the same file can be used as a formatter.

```bash
rd -f examples/log4j
```

Alert is there but the screenshot can't capture blinking text.

![LOG4J](https://github.com/nkh/bash-rd/blob/main/media/log4j.png)

# DATABASE

Using a database instead for the KV store has some advantages
- persistence, if you need it 
- complex records
- queries

## Instrument a program, here a bash script, to debug it

We'll be using the excellent *sqlite3*. We first create a *formatter*.

```bash
[[ "$sql_db" ]] && [[ "$rd_line" =~ ^sql:(.*) ]] && 
	{
	query="${BASH_REMATCH[1]}" ;
	sqlite3 "$sql_db" <<<"$query"
	}
...
```

In our program:

```bash
# execute sql commands directly
sqlite3 my_db 'create table my_table(key text, value int);'

# setup variable in KV store (they are passed to the formatter)
echo "sql_db=my_db"
echo "sql_mode=.mode box"

# or via the formatter which acts as a sqlite3 proxy

echo "sql:insert into my_table values('date','$(date)');"
echo 'sql:insert into my_table values("x",0);'


echo 'sql:select * from my_table;'

```

The complete example is in *examples/sqlite3*.

## A convenience wrapper

For a quick debugging session, with few changes, you can use the code found in *examples/db_variables* that let's you write this:

```bash
rddb_setup my_db 0

# run some code
a=1
rddb_set 'a' $a

# run some code
b="some b value"
rddb_set 'b' "$b"

# code that overrides a
$a=42
rddb_set 'a' "$a" 

# display a table with the variables
rddb_show "title"
```

It should be noted that each call to rddb_set start multiple processes:
- the sqlite formatter
- sqlite3 which
	- opens the db
	- opens your rc file
	- executes the SQL

In other words don't put this a loop.

If you really must run in a loop:
- use only one db process in your application and use the sqlite3 formatter only when you need it

# TABLE FORMATTED KEY/VALUE

You may not need persistent Key-value but a nice way to present some variables and maybe some comment.

The *ptt* formatter uses *Text::Table::Tiny* which can output tables in multiple formats.

You set Key-Values in *rd* and when you need a table you just send a command to *ptt*.

```bash
# start a server
rd -i 1234 ptt
```

The *ptt* command look like this:

```
ptt:variable[ comment];variable; variable[ comment] ....
```

```bash
# set a header
rd -c 1234 "=:rd_ptt_header=variable content comment"

# set some KV, you can set colored string
rd -c 1234 "=:TEST=${RED}test${RESET}"

# send command to ptt with list of variables to display
<<<"ptt:TEST in red;HOME;not_set" rd -c 1234 
```
![PTT](https://github.com/nkh/bash-rd/blob/main/media/rd_ptt.png)

# REAL LIFE EXAMPLES

OK, it's nice to tools but if they collect dust in your numeric toolbox they are of no help.

I'll add cases where I used rd in this section.

## tdiff

*tdiff* is an interactive program, I had a problem while adding a function, exactly the type of problems rd can help with.

![TDIFF](https://github.com/nkh/bash-rd/blob/main/media/rd_tdiff.png)

First understand what was going wrong.

Yes it's easy to take a piece of bash code and run it in the shell (Bash you rock); but you need the data ... you already have.
If the data was large I'd redirect it in file and use it but this case was simple enough.
The possibility to use the interactive program to pick and chose which data is also a plus.

What does the code do?

```bash

# glyphs is a cache of, well, glyphs
# we create a cache because this function is called often and starting a subshell
# to run sed would be time expensive in a loop

# the first character, a glyph, is extracted from a string which can contain colors

[[ "${glyphs[$2]}" ]] || glyph[$2]="$(<<<"${lines[$2]}" sed -e 's/\x1B\[[0-9;]\{1,\}[A-Za-z]//g' -e 's/^\(.\).*/\1/' )"
```

Some tooling later:

```bash
# show if the cache has the glyph for our line
echo cache: "${glyphs[$2]}" >&3

# show the line
echo line: ${lines[$2]} >&3

# show the line in more details
echo line: $(<<<"${lines[$2]}" show_control_characters) >&3

[[ "${glyphs[$2]}" ]] || glyph[$2]="$(<<<"${lines[$2]}" sed -e 's/\x1B\[[0-9;]\{1,\}[A-Za-z]//g' -e 's/^\(.\).*/\1/' )"

glyph="${glyphs[$2]}"

# show the glyph
echo glyph: $glyph >&3
```

Two noteworthy remarks:
- echo is redirected to fd 3, which is itself redirected to *rd* on the command line
	- leave sdtderr for errors
	- 80% of the developers don't really know what stdout and stderr are for, don't be one of them
- inserting show_control_characters, or any extra tool, gives a lot of options

What did I learn will writing the code above?
- know your data, I forgot about colors in the string
- know your data redux, I forgot that glyphs are not just one ASCII character
- I started debugging without rd but it's very simple and fast to setup
 
# DEPENDENCIES

netcat

socat

# INSTALL

See *INSTALL.md*.

# SEE ALSO

[Bash-TPL](https://github.com/TekWizely/bash-tpl)

[bashlog](https://github.com/Zordrak/bashlog)

There's a niece bash db project here https://blog.dhampir.no/content/bashdb-a-single-dynamic-database-table-for-bash-scripts; the only drawback is its speed.

# AUTHOR

	Khemir Nadim ibn Hamouda
	https://github.com/nkh
	CPAN ID: NKH
    
# LICENCE

	© Nadim Khemir 2023, Artistic licence 2.0
