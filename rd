#!/bin/bash

trap 'rm "$RD_PIPE" 2>&- ; trap SIGINT ; kill -2 $$' SIGHUP SIGINT SIGQUIT SIGPIPE SIGTERM
set -a # become a KV store

rd_fs="/tmp/$USER/rd" ; mkdir -p $rd_fs ; rd_config="$HOME/.config/rd"
RD_ID= ; RD_PIPE= ; rd_pid=$$ ; rd_echo=1 ; rd_semaphore=1 ; rd_counter=0 ; rd_relays=() ; rd_relay_pids=() ; rd_web_page="$rd_fs/web_page_$$" ;

loop()
{
RD_PIPE="$1"
[[ "$2" ]] && formatter "$2" || rd_format=rd_echo ;

while IFS= read -r rd_line ; do
	[[ "$rd_line" == q:            ]] && { (( rd_semaphore--, rd_semaphore ))                                      || break ; }
	[[ "$rd_line" == s:            ]] && { ((rd_semaphore++)) ;                                                    continue ; }
	[[ "$rd_line" == e1:           ]] && { rd_echo=0 ;                                                             continue ; }
	[[ "$rd_line" == e0:           ]] && { rd_echo=1 ;                                                             continue ; }
	[[ "$rd_line" =~ ^r:(.*)\:(.*) ]] && { rd_relays+=(${BASH_REMATCH[1]}) ; rd_relay_pids+=(${BASH_REMATCH[2]}) ; continue ; }
	[[ "$rd_line" == c:            ]] && { echo -n $'\e[H\e[J' ;                                                   continue ; }
	[[ "$rd_line" =~ ^f:           ]] && { formatter "${rd_line:2}" ; rd_line= ;                                              }
	[[ "$rd_line" == e:            ]] && { rd_do=0 ;                                                                          }
	[[ "$rd_line" =~ ^=:           ]] && { parse "${rd_line:2}" ; rd_line= ;                                                  } 
	
	(( rd_counter++ )) ; 
	(( rd_do || rd_echo )) && 
		{
		(( ${#rd_relays[@]} )) &&
			$rd_format | tee "${rd_relays[@]}" ||
			$rd_format 
		}
	rd_do=0
done <$1

[[ "${rd_relay_pids[@]}" ]] && for p in "${rd_relay_pids[@]}" ; do kill -SIGHUP -$p ; done
}

rd_echo()   { echo "$rd_line" ; }
formatter() { [[ -f "$1" ]] && rd_format="$1" || { [[ -f "$rd_config/$1" ]] && rd_format="$rd_config/$1"; } || { rd_format=rd_echo ; echo "rd: using default formatter" ; } ; }
parse()     { IFS=$';' read -ra rd_p <<<"$1" ; for rd_r in "${rd_p[@]}" ; do [[ "$rd_r" =~ ^[_a-zA-Z0-9]+= ]] && eval "${rd_r%%=*}='${rd_r#*=}'" ; done <<<"$1" ; }
ploop ()    { [[ -e "$2" ]] && { echo "rd: '$1' already exists" >&2 ; exit 1 ; } ; mkfifo $2 ; exec 3<>$2 ; echo "rd: $1" ; loop "$2" "$3" ; rm $2 ; }
page()      { while read -r rd_line ; do echo "$rd_line" >>$rd_fs/$$ ; done ; }
server()    { socat TCP-LISTEN:$1,crlf,reuseaddr,fork SYSTEM:"$2" & : ; rd_server_pid=$! ; }

[[ "$1" == -c ]] && { [[ -e "$rd_fs/$2" ]] && { { (($# > 2)) && echo "${@:3}" || cat ; } >"$rd_fs/$2" ; exit ; } || { echo "rd: no server @ '$2'" >&2 ; exit 1 ; } ; }
[[ "$1" == -n ]] && { { (($# > 2)) && echo "${@:3}" || cat ; } | nc -N localhost "$2" ;                                                                 exit ; }
[[ "$1" == -N ]] && { { (($# > 3)) && echo "${@:4}" || cat ; } | nc -N "$2" "$3" ;                                                                      exit ; }
[[ "$1" == -f ]] && { RD_ID=$(mktemp -u XXXXXX) ;                                        ploop "id: $RD_ID"    $rd_fs/$RD_ID $2 ;                       exit ; }
[[ "$1" == -i ]] && {                                                                    ploop "id: $2"        $rd_fs/$2     $3 ;                       exit ; }
[[ "$1" == -p ]] && { RD_ID=$(mktemp -u XXXXXX)       ; server $2 "cat >$rd_fs/$RD_ID" ; ploop "port: $2"      $rd_fs/$RD_ID $3 ; kill $rd_server_pid ; exit ; }
[[ "$1" == -w ]] && { RD_ID=${4:-$(mktemp -u XXXXXX)} ; server $2 "cat $rd_web_page"   ; ploop "id: $RD_ID"    $rd_fs/$RD_ID $3 ; kill $rd_server_pid ; exit ; }
[[ "$1" == -k ]] && { rm "$rd_fs/$2" 2>&- ;                                                                                                             exit ; }

[[ "$1" == -r || "$1" == -R ]] && 
		{
		[[ "$1" == -r ]] && rd_relay_type=-c || rd_relay_type=-n
		rd_relay="$rd_fs/relay_$2_$$" ; mkfifo "$rd_relay" ; exec 3<>$rd_relay
		
		rd -i "relay_$2_$$_" $3 &                      # start formatting server
		echo "r:$rd_relay:$$" | rd $rd_relay_type "$2" # register relay
		<"$rd_relay" rd -c "relay_$2_$$_"              # relay to formatting server
		exit
		}

[[ "$1" == -h || "$1" == --help ]] && { man rd ; exit ; }
echo -e "rd - display data remotely, serves as KV store\n\trd -i|-f|-p|-w\t# start a server\n\trd -r|-R\t\t# relay\n\trd -c|-n|-N\t\t# connect to client" ; exit 1
