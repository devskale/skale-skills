system: mac

eval terminal web browsers

browsers
- w3m
- chawan, cha --help
- https://github.com/devskale/chawan

optional:
- chromium headless, with cookies

write results into 
broserfortui_eval.md


# Browser Notes
## Cha
johannwaldherr@jMacAir-3 skale-skills % cha --help
Chawan browser v0.3.3 (release, no sandbox, select)
Usage: cha [options] [URL(s) or file(s)...]
Options:
    --                          Interpret all following arguments as URLs
    -c, --css <stylesheet>      Pass stylesheet (e.g. -c 'a{color: blue}')
    -d, --dump                  Print page to stdout
    -h, --help                  Print this usage message
    -o, --opt <config>          Pass config options (e.g. -o 'page.q="quit()"')
    -r, --run <script/file>     Run passed script or file
    -v, --version               Print version information
    -C, --config <file>         Override config path
    -I, --input-charset <enc>   Specify document charset
    -M, --monochrome            Set color-mode to 'monochrome'
    -O, --display-charset <enc> Specify display charset
    -T, --type <type>           Specify content mime type
    -V, --visual                Visual startup mode
johannwaldherr@jMacAir-3 skale-skills %

## w3m
johannwaldherr@jMacAir-3 skale-skills % w3m --help
w3m version w3m/0.5.6, options lang=en,m17n,color,ansi-color,mouse,menu,cookie,ssl,ssl-verify,external-uri-loader,w3mmailer,nntp,gopher,ipv6,alarm,mark,history,dict
usage: w3m [options] [URL or filename]
options:
    -t tab           set tab width
    -r               ignore backspace effect
    -l line          # of preserved line (default 10000)
    -I charset       document charset
    -O charset       display/output charset
    -B               load bookmark
    -bookmark file   specify bookmark file
    -R               restore from session file
    -session file    specify session file
    -T type          specify content-type
    -m               internet message mode
    -v               visual startup mode
    -M               monochrome display
    -H Deprecated!   Do not use! Use -o high-intensity=true instead
    -N               open URL of command line on each new tab
    -F               automatically render frames
    -cols width      specify column width (used with -dump)
    -ppc count       specify the number of pixels per character (4.0...32.0)
    -dump            dump formatted page into stdout
    -dump_head       dump response of HEAD request into stdout
    -dump_source     dump page source into stdout
    -dump_both       dump HEAD and source into stdout
    -dump_extra      dump HEAD, source, and extra information into stdout
    -post file       use POST method with file content
    -header string   insert string as a header
    +<num>           goto <num> line
    -num             show line number
    -no-proxy        don't use proxy
    -4               IPv4 only (-o dns_order=4)
    -6               IPv6 only (-o dns_order=6)
    -insecure        use insecure SSL config options
    -no-mouse        don't use mouse
    -cookie          use cookie (-no-cookie: don't use cookie)
    -cookie-jar file use file instead of default cookie file
    -graph           use DEC special graphics for border of table and menu
    -no-graph        use ASCII character for border of table and menu
    -s               squeeze multiple blank lines
    -W               toggle search wrap mode
    -X               don't use termcap init/deinit
    -title[=TERM]    set buffer name to terminal title string
    -o opt=value     assign value to config option
    -show-option     print all config options
    -config file     specify config file
    -debug           use debug mode (only for debugging)
    -reqlog          write request logfile
    -help            print this usage message
    -version         print w3m version
