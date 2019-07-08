#!/bin/ash

webroot_path="/var/www/certbot"
#data_path="./data/certbot"
rsa_key_size=4096
letsencrypt_path="/etc/letsencrypt"
letsencrypt_lib_path="/var/lib/letsencrypt"
letsencrypt_log_path="/var/log/letsencrypt"
email="imbrechts.kevin+certbot@protonmail.com" # Adding a valid address is strongly recommended
staging=0

# Add email or not
function get_email_arg
{
  case $email in
    "") email_arg="--register-unsafely-without-email" ;;
    *) email_arg="--email $email" ;;
  esac
}

# Enable staging mode or not
function get_staging_arg
{
  if [ $staging != "0" ]; then staging_arg="--staging"; fi
}

# The official Docker image of certbot doesn't work with aarch64
# See https://github.com/certbot/certbot/issues/6878
function get_image_name()
{
  architecture=$( uname -m )
  if [ $architecture == "aarch64" ]
  then
    image="certbot"
    return
  fi
  image="certbot/certbot"
}

if [ -z "$1" ]; then echo "Error: domain is missing"; exit; fi

domain_arg="-d $1"

email_arg=""
get_email_arg

# Enable staging mode or not
staging_arg=""
get_staging_arg

image=""
get_image_name

certbot_exist=$( docker images -q certbot )
if [ "$certbot_exist" == "" ] 
then
  docker build -t certbot https://github.com/certbot/certbot.git
fi

if [ ! -d "$webroot_path" ]; then mkdir $webroot_path; fi

docker run -t --rm \
           -v $letsencrypt_path:/etc/letsencrypt \
           -v $letsencrypt_lib_path:/var/lib/letsencrypt \
           -v $letsencrypt_log_path:/var/log/letsencrypt \
           -v $webroot_path:$webroot_path \
           $image \
           certonly --webroot \
           -w $webroot_path \
           --email $email \
           --agree-tos \
           --rsa-key-size $rsa_key_size \
           --force-renewal \
           $staging_arg \
           $domain_arg
