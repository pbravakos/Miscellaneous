#/bin/bash
# by oToGamez
# www.pro-toolz.net
# http://top-scripts.blogspot.com/2011/01/blog-post.html
# http://top-scripts.blogspot.com/2011/01/power-of-echo-command-bash-console.html

      E='echo -e';e='echo -en';trap "R;exit" 2  # shortened echo command variable. 'Trap' is needed to prevent the script getting out of control. When someone presses ctrl+c or some other interrupt combination, 'trap' will also delete controlling file '/tmp/.waiting' and force subscript to stop.
    ESC=$( $e "\e")				# define ESC character i.e. "\" or "^[". Another way to define the escape character in ASCII octal is: ESC=$( $e "\033") 
   TPUT(){ $e "\e[${1};${2}H";}			# put the cursor anywhere on the terminal (x and y position) (replacement for 'tput cup')
  CLEAR(){ $e "\ec";}				# clear screen (replacement for the 'clear' command or 'tput clear')
  CIVIS(){ $e "\e[?25l";}			# hide cursor (replacement for 'tput civis')
   DRAW(){ $e "\e%@\e(0";}			# switch to 'garbage' mode to be able to draw lines. %@ is RedHat's black magic and will load default console font with special characters that will needed to draw lines. Only small case characters will draw something. The second echo command is for "font switching".			
  WRITE(){ $e "\e(B";}				# return to normal (reset). Will switch from so called 'garbaged' console back to normal.
   MARK(){ $e "\e[7m";}				# reverse background color around typed text. Replacement for 'tput smso'. ANSI: "Turn reverse video on"
 UNMARK(){ $e "\e[27m";}			# returns selected text back to normal i.e. change background color back to default (27m). Replacement for 'tput rmso' 
      R(){ CLEAR ;stty sane;$e "\ec\e[37;44m\e[J";};     # Clears screen (c). Gives a light gray (code 37) text color and a blue (code 44) background coloration with ANSI sequences and finally apply all of this to the whole screen not only to the current row ([J); 'stty sane' fixes a lot of oddities and may return the terminal session to sanity.
      # Select the following codes: 40m for black, 41m for red, 42m for dark green, 43m for light green, 44m for blue, 45m for pink, 46m for green and 47m for gray.
   HEAD(){ DRAW
           for each in $(seq 1 13);do
           $E "   x                                          x"
           done
           WRITE;MARK;TPUT 1 5
           $E "BASH SELECTION MENU                       ";UNMARK;}
           i=0; CLEAR; CIVIS;NULL=/dev/null
   FOOT(){ MARK;TPUT 13 5
           printf "ENTER - SELECT,NEXT                       ";UNMARK;}
  ARROW(){ read -s -n3 key 2>/dev/null >&2			# read quietly three characters of served input
           if [[ $key = $ESC[A ]];then echo up;fi		# if A is the result, print up
           if [[ $key = $ESC[B ]];then echo dn;fi;}		# if B is the result, print dn
     M0(){ TPUT  4 20; $e "Login info";}
     M1(){ TPUT  5 20; $e "Network";}
     M2(){ TPUT  6 20; $e "Disk";}
     M3(){ TPUT  7 20; $e "Routing";}
     M4(){ TPUT  8 20; $e "Time";}
     M5(){ TPUT  9 20; $e "ABOUT  ";}
     M6(){ TPUT 10 20; $e "EXIT   ";}
      LM=6
   MENU(){ for each in $(seq 0 $LM);do M${each};done;}
    POS(){ if [[ $cur == up ]];then ((i--));fi
           if [[ $cur == dn ]];then ((i++));fi
           if [[ $i -lt 0   ]];then i=$LM;fi
           if [[ $i -gt $LM ]];then i=0;fi;}
REFRESH(){ after=$((i+1)); before=$((i-1))
           if [[ $before -lt 0  ]];then before=$LM;fi
           if [[ $after -gt $LM ]];then after=0;fi
           if [[ $j -lt $i      ]];then UNMARK;M$before;else UNMARK;M$after;fi
           if [[ $after -eq 0 ]] || [ $before -eq $LM ];then
           UNMARK; M$before; M$after;fi;j=$i;UNMARK;M$before;M$after;}
   INIT(){ R;HEAD;FOOT;MENU;}
     SC(){ REFRESH;MARK;$S;$b;cur=`ARROW`;}
     ES(){ MARK;$e "ENTER = main menu ";$b;read;INIT;};INIT
  while [[ "$O" != " " ]]; do case $i in
        0) S=M0;SC;if [[ $cur == "" ]];then R;$e "\n$(w        )\n";ES;fi;;
        1) S=M1;SC;if [[ $cur == "" ]];then R;$e "\n$(ifconfig )\n";ES;fi;;
        2) S=M2;SC;if [[ $cur == "" ]];then R;$e "\n$(df -h    )\n";ES;fi;;
        3) S=M3;SC;if [[ $cur == "" ]];then R;$e "\n$(route -n )\n";ES;fi;;
        4) S=M4;SC;if [[ $cur == "" ]];then R;$e "\n$(date     )\n";ES;fi;;
        5) S=M5;SC;if [[ $cur == "" ]];then R;$e "\n$($e Created by oTo http://top-scripts.blogspot.com/2011/01/blog-post.html )\n";ES;fi;;
        6) S=M6;SC;if [[ $cur == "" ]];then R;exit 0;fi;;
 esac;POS;done
