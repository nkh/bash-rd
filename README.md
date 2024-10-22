% rd(1) | General Commands Manual
# NAME

	rd - display data remotely, also acts as a KV store

![UI](https://github.com/nkh/bash-rd/blob/main/media/rd.gif)

```
.------------.-----------.
| Terminal 1 | Server    |
|            |           |
.------------.-----------.
| Terminal 2 | Relay +   |
|            | formatter |
'------------'-----------'
```

The server echoes all data.

The relay only displays what looks like a log entry.

Multiple commands are run in Terminal 1 to send data to the serer.

*cat* is used in terminal 2, giving use a "cheap" terminal.

- terminal 1: sends text to server, server echoes it, relay does nothing (twice)
- terminal 2: sends text to server, server echoes it, relay does nothing
- terminal 2: sends a log entry, server echoes it, relay echoes it
- terminal 1: change server formatter dynamically to a table which can show the value of variables x and y
- terminal 1: set value of x in KV store, table is updated 
- terminal 2: idem
- terminal 2: set value of y
- terminal 1: send 'quit' command to server, relay also shuts down

# SYNOPSIS

	rd CONNECTION_TYPE [FORMATTER]

	rd --connect ID

# DESCRIPTION

*rd* displays data in another terminal, on another computer, in a web page.

*rd* is the client, it sends data to a server.

*rd* is also the server, it echoes the data send by a client but you can provide custom formatters.

# SECURITY

With *rd* running on a port you may open a security hole, If you are not sure about what you're doing, don't use rd!

Options *-f, -i* do not open ports.

## Remote input and output

If you need to send data to  server or get output from a server, understand the consequences first.

### Data in

Best is to not accept data from anyone but you or processes you control (including controlling the input).

- have a watertight firewall
- open the port to your server only and close it when done
- proxy the connection and filter the traffic, netcat, ncat, socat can help you

### Data out

There are two possibilities, serve a web page or relay the server's output. Both are documented below.

# CONNECTION_TYPE

## Server

Start *rd* as a server, it will display where you can connect.

### Server local

| Type        | Option   | Argument |
| ----------- | -------- | -------- |
| random fifo | -f       |          |
| user ID     | -i       | ID       |

### Server networked

| Type        | Option   | Argument              |
| ----------- | -------- | --------------------- |
| port        | -p       | port                  |
| web server  | -w       | port, formatter[, id] |

## Client

| Type          | Option   | Argument     |
| -----------   | -------- | --------     |
| connect       | -c       | ID           |
| net connect   | -n       | port         |
| net connect   | -N       | address port |
| relay         | -r       | ID           |
| network relay | -R       | port         |

# Examples

### No formatter 

Data is echoed by *rd*

```
terminal 1 $> rd -f
rd: ID: XXXXXX

terminal 2 $> program | rd -c XXXXXX

terminal 3 $> interactive_program >(rd -c XXXXXX)

terminal 4 $> interactive_program 3>(rd -c XXXXXX) # chose which file descriptor you use to send data to rd

```

### With a formatter

You decide how the data is used and displayed

```
terminal 1 $> rd -f my_formatter # my_formatter will be called by the server
rd: ID: XXXXXX

terminal 2 $> bash_script | rd -c XXXXXX
```

## Random FIFO

```
terminal 1 $> rd -f
rd: ID: XXXXXX # XXXXXX is where the server can be reached

terminal 2 $> cat > >(rd -c XXXXXX)
```

## User ID

You can give an alphanumeric ID (or generate it, ex: https://github.com/fnichol/names).

```
terminal 1 $> rd -i my_id 
rd: ID: my_id

terminal 2 $> cat | rd -c my_id
```

## Networked

### Security

With rd on a port you may open a security hole!

### Local port

```
terminal 1 $> rd -p my_port
rd: port: my_port

terminal 2 $> cat | rd -n my_port

terminal 3 $> cat > >(rd -N host my_port)
```

### Web page

```
terminal 1 $> rd -w my_port web_table XXX
rd: ID: XXX

# set variable x and generate a page via formatter 'web_table'
terminal 2 $> rd -c XXX '=:x=1'

# get page
$> firefox http:/localhost:my_port
$> curl localhost:my_port 2>&- | cat 
```

# CONTROL COMMANDS

*rd* accepts some control commands.

| Prefix | Action        | Description                                                     |
| ------ | ------------- | --------------------------------------------------------------- |
| q:     | quit          | stop the server                                                 |
| s:     | semaphore     | increment the server semaphore, needs to be 0 to quit           |
| c:     | clear         | clear server's terminal                                         |
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

*rd* stores your data, on the server, the data is available to the formatters.

```bash
echo '=:key=value;other_key=value' | rd -c ID
```

# USAGE

## Multiple clients to one server

See video at top of README.md.

By using the semaphore command, each client can quit and the server will quit when the last client quits.

## Connect to multiple servers

You can start multiple server, each getting specific data or using a specific formatter.

```bash
terminal 1 $> rd -i server1

terminal 2 $> rd -i server2 my_formatter

terminal 3 $> my_script 3> >(rd -c server1) 4> >(rd -c server2)
```

*my_script*, or equivalent command in Perl, C, Go, ... 

```bash
server1_fd=3 # the file descriptor you chose to use to send data to on the above command line
server2_fd=4 # send data to different servers

# will echo the data
echo "data send to server_1" >&$server1_fd

# will run the formatter
echo -e "data send to server_2 with \0 binary" >&$server2_fd

```

## Send identical data to multiple servers

```
command | tee >(rd -c ID) > >(rd -n port)
```

## Send data inside a pipe

```
command | tee >(rd -c ID) | other_command
```

## Usage in Bash

```bash
ls --color | rd -c id

<<<'c:' rd -n port

tree -C -d > >(rd -c id)

rd -n 1234 "some data"
```

## Usage in Perl

```perl
open my $fh, ">&=", 3 ; 
$fh->autoflush(1) ;

print $fh "c:\n" ; # clear
print $fh DumpTree $data, ...

```

# FORMATTERS 

A formatter is an external program that formats the data received by the server.

Without a formatter the data is echoed.

Formatters also get the stored key/value in their environment.

*rd* variables of interest:
- $rd_pid, the pid of the server
- $rd_counter, number of received lines
- $rd_line, the last received data

Things you can do:

- render specific variables in a table 
- parse variable for content and location to display `echo "key:/x,y/value"`
- list variables newest set first
- show data structures
...

## SECURITY

With rd on a port and a formatters you may open a security hole!

See *Relays* below for a read only solution

## Templating

A nice way to present data is with the use of templates.

I like *bash-tpl*, a templating engine that generates bash scripts.

[Bash-TPL](https://github.com/TekWizely/bash-tpl)

## Generating a web page

You can use any HTML generator you like in your formatter, the HTML must be put in *$rd_web_page*.

### example HTML generator in Bash

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

Get a server's output to another terminal, the relay will close when server closes.

```bash
rd -r id
```

## Relay with a custom formatter

```
rd -r id log4j
```

## Relay rd running on a port

```bash
rd -R port
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

# UTILITIES

## rdc

A bash script that's equivalent to "rd -c"

## trd

* opens *rd* as a server in a tmux pane.

You can pass the same arguments to *trd* as you can pass to *rd*, without argument *trd* will generated an ID and copy it to the clipboard.

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
# is it a log entry
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

![LOG4J](https://github.com/nkh/bash-rd/blob/main/media/log4j.png)
Alert is there but the screenshot can't capture blinking text.

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

A table is a to present variables.

The *ptt* formatter uses *Text::Table::Tiny* which can output tables in multiple formats.

You set Key-Values in *rd* and when you need a table you just send a command to *ptt*.

```bash
# start a server
rd -i 1234 ptt # use ptt as a formatter
```

A *ptt* command look like this:

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

## tdiff

*tdiff* is an interactive program I wrote; I had a problem while adding a function, exactly the type of problems rd can help with.

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
 
echo cache: "${glyphs[$2]}" >&3
echo line: ${lines[$2]} >&3
echo line: $(<<<"${lines[$2]}" show_control_characters) >&3

[[ "${glyphs[$2]}" ]] || glyph[$2]="$(<<<"${lines[$2]}" sed -e 's/\x1B\[[0-9;]\{1,\}[A-Za-z]//g' -e 's/^\(.\).*/\1/' )"

glyph="${glyphs[$2]}"

# show the glyph
echo glyph: $glyph >&3
```

Two noteworthy remarks:
- echo is redirected to fd 3, which is itself redirected to *rd* on the command line
	- leave sdtderr for errors
- adding extra commands in the pipeline to rd let me display ANSI codes in the data

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
