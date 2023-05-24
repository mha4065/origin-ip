# Origin-IP

<p align="center">
  <a href="#requirements">Requirements</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#scanning-options">Tool options</a> •
  <a href="#license">license</a>
</p>


Origin-IP is a Bash script to find the origin IP address of a target.

## Requirements
  - Subfinder
  - Assetfinder
  - httpX
  - dnsX
  - MapCIDR
  - Amass

## Installation
  1. `git clone https://github.com/mha4065/origin-ip.git`
  2. `chmod +x origin-ip.sh`

## Usage

### Basic Usage
`./origin-ip -d domain.tld`

### Scanning Options
- `-i` : Specify a list of subdomains
- `-c` : Specify a list of CIDR
- `-r` : Specify a list of CDN ranges
- `-s` : Run the script silently and do not display any output
- `-o` : Write output to a file instead of the terminal

## License
This project is licensed under the MIT license. See the LICENSE file for details.
