# origin-ip
origin-ip is a tool to find the origin IP address of a target site.

## Requirements
  - Subfinder
  - Assetfinder
  - httpX
  - dnsX
  - MapCIDR
  - Github-Subdomains

## Installation
  1. Add your providers token to this file: `$HOME/.config/subfinder/provider-config.yaml`
  2. Add your github token to top of `origin-ip.sh` file, in `GITHUB_TOKEN`
  3. Run `chmod +x origin-ip.sh`
  4. `./origin-ip.sh -d domain.tld [-s subdomain.txt] [-c cidr.txt]`

Note: If you have a list of subdomains, you can give your subdomains file to the tool with `-s`. Also, if you have manually collected a list of target CIDRs, you can give them to the program by `-c`.

Note: If you do not give a subdomain file to the tool, the tool will subdomain enumeration automatically using the best tools.
