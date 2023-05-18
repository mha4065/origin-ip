#!/bin/bash


GITHUB_TOKEN="Your github token"

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
magenta='\033[0;35m'
cyan='\033[0;36m'
NC='\033[0m'

printf "

            _       _             _       
  ___  _ __(_) __ _(_)_ __       (_)_ __  
 / _ \| '__| |/ _\` | | '_ \ _____| | '_ \ 
| (_) | |  | | (_| | | | | |_____| | |_) |
 \___/|_|  |_|\__, |_|_| |_|     |_| .__/ 
              |___/                |_|    

              		${cyan}Developed by MHA${NC}	     			                  
                               	${yellow}mha4065.com${NC}

"

usage() { echo "Usage: ./origin-ip.sh -d domain.tld [-s subdomain.txt] [-c cidr.txt]" 1>&2; exit 1; }

while getopts "d:s:c:" flag
do
    case "${flag}" in
        d) domain=${OPTARG#*//};;
        s) subdomain="$OPTARG";;
        i) cidr="$OPTARG";;
        \? ) usage;;
        : ) usage;;
		*) usage;;
    esac
done

if [[ -z "${domain}" ]]; then
  usage
fi


# Check results/domain is exist or not
#=======================================================================
if [ ! -d "results" ]; then
    mkdir "results"
    if [ ! -d "results/$domain" ]; then
    	mkdir "results/$domain"
    fi
fi
#=======================================================================


# Check the requirements
#=======================================================================
echo
echo -e "${blue}[!]${NC} Check the requirements :"

if ! command -v subfinder &> /dev/null
then
    echo -e "   ${red}[-]${NC} subfinder could not be found !"
    exit
fi

if ! command -v assetfinder &> /dev/null
then
    echo -e "   ${red}[-]${NC} assetfinder could not be found !"
    exit
fi

if ! command -v github-subdomains &> /dev/null
then
    echo -e "   ${red}[-]${NC} github-subdomains could not be found !"
    exit
fi

if ! command -v mapcidr &> /dev/null
then
    echo -e "   ${red}[-]${NC} mapcidr could not be found :("
    exit
fi

if ! command -v dnsx &> /dev/null
then
    echo -e "   ${red}[-]${NC} dnsx could not be found :("
    exit
fi

if ! command -v httpx &> /dev/null
then
    echo -e "   ${red}[-]${NC} httpx could not be found :("
    exit
fi

echo -e "   ${green}[+]${NC} All requirements are installed :)"
#=======================================================================


# Subdomain enumeration
#=======================================================================
function sub_enumeration() {
    echo
    echo -e "${blue}[!]${NC} Subdomain enumeration :"

    # Subfinder ==========================
    echo -e "   ${green}[+]${NC} Subfinder"
    subfinder -d $domain -all -silent > results/$domain/subfinder.txt

    # Assetfinder ========================
    echo -e "   ${green}[+]${NC} Assetfinder"
    assetfinder --subs-only $domain > results/$domain/assetfinder.txt

    # Crt.sh =============================
    echo -e "   ${green}[+]${NC} crt.sh"
    curl -s "https://crt.sh/?q=$domain&output=json" | tr '\0' '\n' | jq -r ".[].common_name,.[].name_value" | sort -u > results/$domain/crtsh.txt

    # AbuseDB ============================
    echo -e "   ${green}[+]${NC} AbuseDB"
    curl -s "https://www.abuseipdb.com/whois/$domain" -H "User-Agent: Chrome" | grep -E '<li>\w.*</li>' | sed -E 's/<\/?li>//g' | sed -e "s/$/.$domain/" > results/$domain/abusedb.txt

    # Github subdomains ==================
    echo -e "   ${green}[+]${NC} Github"
    github-subdomains -d $domain -e -o results/$domain/github.txt -t $token > /dev/null 2>&1

    # Remove duplicates
    cat results/$domain/subfinder.txt results/$domain/assetfinder.txt results/$domain/crtsh.txt results/$domain/github.txt results/$domain/abusedb.txt | sort -u > results/$domain/subdomains.txt
    rm results/$domain/subfinder.txt results/$domain/assetfinder.txt results/$domain/crtsh.txt results/$domain/github.txt results/$domain/abusedb.txt 

    echo -e "${blue}[!]${NC} Subdomain enumeration completed :))"
}

#=======================================================================


# Name resolution
#=======================================================================
if [ -z "$subdomain" ]; then
	sub_enumeration
	echo -e "${blue}[!]${NC} Name resolution on all subdomains"
	cat results/$domain/subdomains.txt | dnsx -silent -resp-only > results/$domain/resolved_subs.txt
else
	echo -e "${blue}[!]${NC} Name resolution on all subdomains"
	cat "$subdomain" | dnsx -silent -resp-only > results/$domain/resolved_subs.txt
fi
#=======================================================================


# Checking CIDR to filter CDN IPs
#=======================================================================
echo -e "${blue}[!]${NC} Checking CIDR to filter CDN IPs"
if [ -z "$cidr" ]; then
	cat results/$domain/resolved_subs.txt | mapcidr -silent -filter-ip cdns.txt >> results/$domain/ips.txt
else
	cat results/$domain/resolved_subs.txt | mapcidr -silent -filter-ip cdns.txt >> results/$domain/temp.txt
	cat "$cidr" results/$domain/temp.txt | sort -u > results/$domain/ips.txt
	rm results/$domain/temp.txt
fi
rm results/$domain/resolved_subs.txt
#=======================================================================


# Sending HTTP request to the all CIDRs equipped with host header
#=======================================================================
echo -e "${blue}[!]${NC} Sending HTTP request to the all CIDRs equipped with host header"
cat results/$domain/prefixes.txt | mapcidr -silent | httpx -silent -H "host: $domain" -H "user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15" -title >> results/$domain/final_results.txt
rm results/$domain/prefixes.txt
echo -e "${green}[+]${NC} Everything is finished and the results are saved in ${cyan}results/$domain/final_results.txt${NC}. Have a good hack :))"
#=======================================================================
