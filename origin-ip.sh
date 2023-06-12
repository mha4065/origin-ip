#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
magenta='\033[0;35m'
cyan='\033[0;36m'
NC='\033[0m'

usage() { echo "Usage: ./origin-ip.sh -d domain.tld [-i subdomain.txt] [-c cidr.txt] [-r cdn_ranges.txt] [-s] [-o output.txt]" 1>&2; exit 1; }

while getopts "d:i:c:r:o:s" flag
do
    case "${flag}" in
        d) domain=${OPTARG#*//};;
        i) subdomain="$OPTARG";;
        c) cidr="$OPTARG";;
        r) cdn_ranges="$OPTARG";;
        o) output="$OPTARG";;
        s) silent=true;;
        \? ) usage;;
        : ) usage;;
	*) usage;;
    esac
done

if [[ -z "${domain}" ]]; then
  usage
fi

if [[ -z "${silent}" ]]; then
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
fi

# Check results/domain is exist or not
#=======================================================================
if [ ! -d "results" ]; then
    mkdir "results"
fi
if [ ! -d "results/$domain" ]; then
    mkdir "results/$domain"
fi
#=======================================================================


# Check the requirements
#=======================================================================
if [[ -z "${silent}" ]]; then
	echo
	echo -e "${blue}[!]${NC} Check the requirements :"
fi

if ! command -v subfinder &> /dev/null
then
    echo -e "   ${red}[-]${NC} subfinder could not be found !"
    exit
fi

if ! command -v anew &> /dev/null
then
    echo -e "   ${red}[-]${NC} anew could not be found !"
    exit
fi

if ! command -v amass &> /dev/null
then
    echo -e "   ${red}[-]${NC} Amass could not be found !"
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

if [[ -z "${silent}" ]]; then
	echo -e "   ${green}[+]${NC} All requirements are installed :)"
fi
#=======================================================================


# Subdomain enumeration
#=======================================================================
if [[ -z "${silent}" ]]; then
	echo
	echo -e "${blue}[!]${NC} Subdomain enumeration :"
fi

# Subfinder ==========================
if [[ -z "${silent}" ]]; then
	echo -e "   ${green}[+]${NC} Subfinder"
fi
subfinder -d $domain -all -silent > results/$domain/subfinder.txt

# Amass ==============================
if [[ -z "${silent}" ]]; then
	echo -e "   ${green}[+]${NC} Amass (Passive)"
fi
amass enum --passive -d $domain -silent -o results/$domain/amass.txt

# Crt.sh =============================
if [[ -z "${silent}" ]]; then
	echo -e "   ${green}[+]${NC} crt.sh"
fi
query=$(cat <<-END
	SELECT
		ci.NAME_VALUE
	FROM
		certificate_and_identities ci
	WHERE
		plainto_tsquery('certwatch', '$domain') @@ identities(ci.CERTIFICATE)
	END
)
echo "$query" | psql -t -h crt.sh -p 5432 -U guest certwatch | sed 's/ //g' | grep -E ".*.\.$domain" | sed 's/*\.//g' | tr '[:upper:]' '[:lower:]' | sort -u | tee -a results/$domain/crtsh.txt &> /dev/null

# Github subdomains ==================
if [[ -z "${silent}" ]]; then
	echo -e "   ${green}[+]${NC} Github"
fi
q=$(echo $domain | sed -e 's/\./\\\./g')
src search -json '([a-z\-]+)?:?(\/\/)?([a-zA-Z0-9]+[.])+('${q}') count:5000 fork:yes archived:yes' | jq -r '.Results[] | .lineMatches[].preview, .file.path' | grep -oiE '([a-zA-Z0-9]+[.])+('${q}')' | awk '{ print tolower($0) }' | sort -u > results/$domain/github.txt

# Remove duplicates
cat results/$domain/subfinder.txt results/$domain/amass.txt results/$domain/crtsh.txt results/$domain/github.txt | sort -u > results/$domain/subdomains.txt
rm results/$domain/subfinder.txt results/$domain/amass.txt results/$domain/crtsh.txt results/$domain/github.txt 

if [[ -z "${silent}" ]]; then
	echo -e "${blue}[!]${NC} Subdomain enumeration completed :))"
fi
#=======================================================================


# Name resolution
#=======================================================================
if [ -z "$subdomain" ]; then
	if [[ -z "${silent}" ]]; then
		echo -e "${blue}[!]${NC} Name resolution on all subdomains"
	fi
	cat results/$domain/subdomains.txt | dnsx -silent -resp-only > results/$domain/resolved_subs.txt
else
	if [[ -z "${silent}" ]]; then
		echo -e "${blue}[!]${NC} Name resolution on all subdomains"
	fi
	cat $subdomain | anew -q results/$domain/subdomains.txt
	cat results/$domain/subdomains.txt | dnsx -silent -resp-only > results/$domain/resolved_subs.txt
fi
#=======================================================================


# Checking CIDR to filter CDN IPs
#=======================================================================
if [[ -z "${silent}" ]]; then
	echo -e "${blue}[!]${NC} Checking CIDR to filter CDN IPs"
fi
if [ -z "$cdn_ranges" ]; then
	cat results/$domain/resolved_subs.txt | mapcidr -silent -filter-ip cdns.txt >> results/$domain/ips.txt
else
	cat results/$domain/resolved_subs.txt | mapcidr -silent -filter-ip "$cdn_ranges" >> results/$domain/ips.txt
fi
rm results/$domain/resolved_subs.txt

if [ "$cidr" ]; then
	if [[ -z "${silent}" ]]; then
		echo -e "${green}[+]${NC} Check input CIDRs and remove CDNs CIDR's"
	fi
	if [ -z "$cdn_ranges" ]; then
		cat $cidr | mapcidr -silent -filter-ip cdns.txt | sort -u >> results/$domain/filtered_cidr.txt
	else
		cat $cidr | mapcidr -silent -filter-ip "$cdn_ranges" | sort -u >> results/$domain/filtered_cidr.txt
	fi
	cat results/$domain/filtered_cidr.txt | anew -q results/$domain/ips.txt
	rm results/$domain/filtered_cidr.txt
fi

#=======================================================================


# Sending HTTP request to the all CIDRs equipped with host header
#=======================================================================
if [[ -z "${silent}" ]]; then
	echo -e "${blue}[!]${NC} Sending HTTP request to the all CIDRs equipped with host header"
fi
if [[ -z "${output}" ]]; then
	cat results/$domain/ips.txt | mapcidr -silent | httpx -silent -H "host: $domain" -H "user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15" -title -nc
else
	cat results/$domain/ips.txt | mapcidr -silent | httpx -silent -H "host: $domain" -H "user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Safari/605.1.15" -title -nc >> results/$domain/$output
fi
rm results/$domain/ips.txt

if [ "${output}" ]; then
	echo -e "${green}[+]${NC} Everything is finished and the results are saved in ${cyan}results/$domain/$output${NC}"
fi
#=======================================================================
